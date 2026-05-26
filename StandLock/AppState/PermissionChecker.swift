import SwiftUI
import EventKit
import ApplicationServices
import Detection

enum PermissionStatus {
    case granted, notGranted, denied, needsRestart
}

enum PermissionType {
    case accessibility
    case inputMonitoring
    case calendar

    var settingsURLs: [URL] {
        switch self {
        case .accessibility:
            [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy",
            ].compactMap { URL(string: $0) }
        case .inputMonitoring:
            [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
                "x-apple.systempreferences:com.apple.preference.security?Privacy",
            ].compactMap { URL(string: $0) }
        case .calendar:
            [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
                "x-apple.systempreferences:com.apple.preference.security?Privacy",
            ].compactMap { URL(string: $0) }
        }
    }
}

@MainActor
final class PermissionChecker: ObservableObject {
    @Published var inputMonitoringGranted: Bool
    @Published var accessibilityGranted: Bool
    @Published var calendarStatus: EKAuthorizationStatus
    @Published var inputMonitoringProbeSucceeded = false
    @Published var calendarNeedsRestart = false

    private let eventStore = EKEventStore()

    init() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let probe = probeInputMonitoringAccess()
        if probe {
            inputMonitoringGranted = true
            inputMonitoringProbeSucceeded = true
            lastProbeTime = Date()
        }
    }

    var accessibilityStatus: PermissionStatus {
        accessibilityGranted ? .granted : .notGranted
    }

    var inputMonitoringStatus: PermissionStatus {
        guard inputMonitoringGranted else { return .notGranted }
        guard inputMonitoringProbeSucceeded else { return .needsRestart }
        return .granted
    }

    var calendarPermissionStatus: PermissionStatus {
        if CalendarDetector.isAuthorized(calendarStatus) { return .granted }
        switch calendarStatus {
        case .denied, .restricted: return .denied
        default: return calendarNeedsRestart ? .needsRestart : .notGranted
        }
    }

    private var lastProbeTime: Date = .distantPast
    private let probeInterval: TimeInterval = 10

    private func probeInputMonitoringAccess() -> Bool {
        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else { return false }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        return true
    }

    struct PermissionTransitions {
        var accessibilityBecameGranted = false
        var inputMonitoringBecameGranted = false
        var calendarBecameGranted = false
    }

    private func refreshStatusAndDetectTransitions() -> PermissionTransitions {
        let prevAX = accessibilityGranted
        let prevIM = inputMonitoringGranted
        let prevCal = calendarStatus

        refreshStatus()

        var transitions = PermissionTransitions()
        transitions.accessibilityBecameGranted = !prevAX && accessibilityGranted
        transitions.inputMonitoringBecameGranted = !prevIM && inputMonitoringGranted
        transitions.calendarBecameGranted =
            !CalendarDetector.isAuthorized(prevCal) &&
            CalendarDetector.isAuthorized(calendarStatus)
        return transitions
    }

    private func updateInputMonitoringProbe() {
        guard Date().timeIntervalSince(lastProbeTime) >= probeInterval else { return }
        lastProbeTime = Date()
        let result = probeInputMonitoringAccess()
        inputMonitoringProbeSucceeded = result
        if result && !inputMonitoringGranted {
            inputMonitoringGranted = true
        }
    }

    func refreshStatus() {
        let preflight = CGPreflightListenEventAccess()
        inputMonitoringGranted = preflight || inputMonitoringProbeSucceeded
        accessibilityGranted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func pollContinuously() async {
        refreshStatus()
        updateInputMonitoringProbe()

        let activationTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification
            ) {
                guard let self else { return }
                let transitions = self.refreshStatusAndDetectTransitions()
                self.updateInputMonitoringProbe()
                self.handleTransitions(transitions)
            }
        }

        defer { activationTask.cancel() }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            let transitions = refreshStatusAndDetectTransitions()
            updateInputMonitoringProbe()
            handleTransitions(transitions)
        }
    }

    private func handleTransitions(_ transitions: PermissionTransitions) {
        if transitions.accessibilityBecameGranted {
            if !AXIsProcessTrusted() {
                showRestartAlertIfNeeded(for: "Accessibility")
            }
        }

        if transitions.inputMonitoringBecameGranted {
            if !probeInputMonitoringAccess() {
                showRestartAlertIfNeeded(for: "Input Monitoring")
            } else {
                inputMonitoringProbeSucceeded = true
            }
        }

        if transitions.calendarBecameGranted {
            calendarNeedsRestart = true
        }
    }

    @MainActor private static var shownRestartAlerts: Set<String> = []

    private(set) static var isRelaunching = false

    func relaunchApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try task.run()
            Self.isRelaunching = true
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Restart Failed"
            alert.informativeText = "Could not relaunch StandLock. Please reopen the app manually."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func showRestartAlertIfNeeded(for permissionName: String) {
        guard !Self.shownRestartAlerts.contains(permissionName) else { return }
        Self.shownRestartAlerts.insert(permissionName)

        let alert = NSAlert()
        alert.messageText = "\(permissionName) Permission Granted"
        alert.informativeText = "StandLock needs to restart to apply this permission."
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    // MARK: - Feature Gates

    var idleDetectionAvailable: Bool { inputMonitoringGranted }
    var strictModeAvailable: Bool { accessibilityGranted && inputMonitoringGranted }
    var calendarIntegrationAvailable: Bool { CalendarDetector.isAuthorized(calendarStatus) }

    func gatedToggle(
        for preference: Binding<Bool>,
        requires permission: PermissionType,
        onDenied: @escaping () -> Void
    ) -> Binding<Bool> {
        let available: Bool
        switch permission {
        case .inputMonitoring: available = idleDetectionAvailable
        case .accessibility: available = strictModeAvailable
        case .calendar: available = calendarIntegrationAvailable
        }
        return Binding(
            get: { available && preference.wrappedValue },
            set: { newValue in
                if newValue && !available {
                    onDenied()
                } else {
                    preference.wrappedValue = newValue
                }
            }
        )
    }

    private func openSystemSettings(for permission: PermissionType) {
        for url in permission.settingsURLs {
            if NSWorkspace.shared.open(url) { return }
        }
    }

    func requestAccessibility() {
        if AXIsProcessTrusted() {
            refreshStatus()
            return
        }
        openSystemSettings(for: .accessibility)
        pollAfterSettingsOpened()
    }

    func requestInputMonitoring() {
        if probeInputMonitoringAccess() {
            inputMonitoringGranted = true
            inputMonitoringProbeSucceeded = true
            lastProbeTime = Date()
            return
        }

        if CGPreflightListenEventAccess() {
            refreshStatus()
            return
        }
        openSystemSettings(for: .inputMonitoring)
        pollAfterSettingsOpened()
    }

    private func requestCalendarAccess() async -> Bool {
        if #available(macOS 14, *) {
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        } else {
            return (try? await eventStore.requestAccess(to: .event)) ?? false
        }
    }

    func requestCalendar() {
        Task {
            let granted = await requestCalendarAccess()
            refreshStatus()
            let hasAccess = CalendarDetector.isAuthorized(calendarStatus)
            if !granted && !hasAccess {
                openSystemSettings(for: .calendar)
                pollAfterSettingsOpened()
            }
        }
    }

    private var settingsPollingTask: Task<Void, Never>?

    private func pollAfterSettingsOpened() {
        settingsPollingTask?.cancel()
        settingsPollingTask = Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                refreshStatus()
            }
        }
    }
}

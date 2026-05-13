import SwiftUI
import EventKit
import ApplicationServices

enum PermissionStatus {
    case granted, notGranted, denied
}

enum PermissionType {
    case accessibility
    case inputMonitoring
    case calendar

    var settingsURL: URL? {
        switch self {
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .inputMonitoring:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        case .calendar:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        }
    }
}

@Observable
@MainActor
final class PermissionChecker {
    var inputMonitoringGranted = false
    var accessibilityGranted = false
    var calendarStatus: EKAuthorizationStatus = .notDetermined

    var calendarPermissionStatus: PermissionStatus {
        switch calendarStatus {
        case .fullAccess: .granted
        case .denied, .restricted: .denied
        default: .notGranted
        }
    }

    func refreshStatus() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func pollContinuously() async {
        refreshStatus()

        let activationTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification
            ) {
                self?.refreshStatus()
            }
        }

        defer { activationTask.cancel() }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            refreshStatus()
        }
    }

    private func openSystemSettings(for permission: PermissionType) {
        if let url = permission.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            openSystemSettings(for: .accessibility)
        }
    }

    func requestInputMonitoring() {
        let granted = CGRequestListenEventAccess()
        if !granted {
            openSystemSettings(for: .inputMonitoring)
        }
    }

    func requestCalendar() {
        Task {
            let store = EKEventStore()
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if !granted {
                openSystemSettings(for: .calendar)
            }
            calendarStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
}

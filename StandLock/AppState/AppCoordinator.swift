import SwiftUI
import Combine
import Coordination
import StandLockCore
import Scheduling
import Detection

@MainActor
private final class OnboardingWindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        MainActor.assumeIsolated {
            onClose()
        }
        return false
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    enum SettingsTab: Int, Hashable {
        case general, schedules, detection, permissions, statistics, about
    }

    @Published var selectedSettingsTab: SettingsTab = .general
    @Published var nextBreakTime: Date?
    @Published private(set) var breakScheduledAt: Date?
    @Published var isBreakActive: Bool = false
    @Published var currentBreakRemaining: TimeInterval = 0
    @Published var currentLevel: DisciplineLevel = .gentle
    @Published var todayStats: BreakStatistics = BreakStatistics()
    @Published var deferralReason: DeferralReason?
    @Published var isPaused: Bool = false
    @Published var pausedUntil: Date?
    @Published var schedules: [Schedule] = []
    @Published var preferences: AppPreferences = AppPreferences()
    @Published var hasCompletedOnboarding: Bool = false
    @Published private(set) var breakProgress: Double = 0
    @Published private(set) var menuBarTimerText: String?
    @Published var breakHistory: BreakHistory = BreakHistory()

    let permissionChecker = PermissionChecker()

    private var coordinator: BreakCoordinator?
    private let overlayController = OverlayWindowController()
    private var eventListenerTask: Task<Void, Never>?
    private var progressTimer: Task<Void, Never>?
    private var loadedExercises: [Exercise] = []
    private var onboardingWindow: NSWindow?
    private var onboardingWindowDelegate: OnboardingWindowCloseDelegate?
    private var permissionSyncCancellable: AnyCancellable?

    init() {
        loadExercises()
        loadData()
        syncPreferencesWithPermissions()
        startProgressTimer()
        observeSystemSleep()
        permissionSyncCancellable = permissionChecker.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncPreferencesWithPermissions()
            }
        Task { await permissionChecker.pollContinuously() }
        if !schedules.isEmpty {
            startCoordinator()
        }
        if !hasCompletedOnboarding {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                self.showOnboardingIfNeeded()
            }
        }
    }

    private func loadExercises() {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else { return }
        loadedExercises = decoded
    }

    // MARK: - Persistence

    private func loadData() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if let data = UserDefaults.standard.data(forKey: "schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            schedules = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        }

        if let prefData = UserDefaults.standard.data(forKey: "preferences"),
           let json = try? JSONSerialization.jsonObject(with: prefData) as? [String: Any],
           let raw = json["escalationLevel"] as? Int, raw > 0 {
            for i in schedules.indices { schedules[i].progressiveEnforcement = true }
            saveSchedules()
            savePreferences()
        }

        if let data = UserDefaults.standard.data(forKey: "statistics"),
           let decoded = try? JSONDecoder().decode(BreakStatistics.self, from: data) {
            todayStats = decoded
            todayStats.resetWeeklyIfNeeded(currentDate: Date())
        }

        if let data = UserDefaults.standard.data(forKey: "breakHistory"),
           let decoded = try? JSONDecoder().decode(BreakHistory.self, from: data) {
            breakHistory = decoded
        }
        let cutoff = DailyBreakRecord.dateKey(
            from: Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        )
        breakHistory.pruneOlderThan(cutoff)

        if breakHistory.records.isEmpty && todayStats.breaksCompleted > 0 {
            let key = DailyBreakRecord.dateKey(from: Date())
            let enabledSchedules = schedules.filter(\.isEnabled)
            let avgDuration = enabledSchedules.isEmpty
                ? 300.0
                : enabledSchedules.map(\.breakDuration).reduce(0, +) / Double(enabledSchedules.count)
            let totalDuration = Double(todayStats.breaksCompleted) * avgDuration
            let record = DailyBreakRecord(
                dateKey: key,
                breaksCompleted: todayStats.breaksCompleted,
                breaksSkipped: todayStats.breaksSkipped,
                breaksEscaped: todayStats.breaksEscaped,
                totalBreakDuration: totalDuration,
                hadActiveSchedule: !enabledSchedules.isEmpty
            )
            breakHistory.upsert(record)
            saveHistory()
        }
    }

    func saveSchedules() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        UserDefaults.standard.set(data, forKey: "schedules")
    }

    func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: "preferences")
        coordinator?.updatePreferences(preferences)
        updateMenuBarTimer()
    }

    private func syncPreferencesWithPermissions() {
        var prefsChanged = false
        if preferences.idleDetectionEnabled && !permissionChecker.idleDetectionAvailable {
            preferences.idleDetectionEnabled = false
            prefsChanged = true
        }
        if preferences.calendarDetectionEnabled && !permissionChecker.calendarIntegrationAvailable {
            preferences.calendarDetectionEnabled = false
            prefsChanged = true
        }
        if prefsChanged {
            savePreferences()
        }

        var schedulesChanged = false
        if !permissionChecker.strictModeAvailable {
            for i in schedules.indices where schedules[i].disciplineLevel == .strict {
                schedules[i].disciplineLevel = .gentle
                schedulesChanged = true
            }
        }
        if schedulesChanged {
            saveSchedules()
            restartCoordinator()
        }
    }

    func saveStatistics() {
        guard let data = try? JSONEncoder().encode(todayStats) else { return }
        UserDefaults.standard.set(data, forKey: "statistics")
    }

    func saveHistory() {
        guard let data = try? JSONEncoder().encode(breakHistory) else { return }
        UserDefaults.standard.set(data, forKey: "breakHistory")
    }

    private func updateDailyHistory(_ stats: BreakStatistics) {
        let key = DailyBreakRecord.dateKey(from: Date())
        let hasActiveSchedule = !schedules.filter(\.isEnabled).isEmpty
        var record = breakHistory.record(for: key)
            ?? DailyBreakRecord(dateKey: key, hadActiveSchedule: hasActiveSchedule)
        record.breaksCompleted = stats.breaksCompleted
        record.breaksSkipped = stats.breaksSkipped
        record.breaksEscaped = stats.breaksEscaped
        record.hadActiveSchedule = hasActiveSchedule

        let enabledSchedules = schedules.filter(\.isEnabled)
        let avgDuration = enabledSchedules.isEmpty
            ? 300.0
            : enabledSchedules.map(\.breakDuration).reduce(0, +) / Double(enabledSchedules.count)
        record.totalBreakDuration = Double(stats.breaksCompleted) * avgDuration

        breakHistory.upsert(record)
        saveHistory()
    }

    // MARK: - Coordinator Lifecycle

    private func startCoordinator() {
        stopCoordinator()
        let scheduler = ScheduleEvaluator()
        let detector = CompositeDetector(
            calendar: CalendarDetector(lookAheadMinutes: preferences.calendarLookAheadMinutes)
        )
        let breakCoordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: overlayController
        )
        self.coordinator = breakCoordinator
        breakCoordinator.exercises = loadedExercises

        overlayController.onSkip = { [weak breakCoordinator] in
            breakCoordinator?.skipActiveBreak()
        }
        overlayController.onComplete = { [weak breakCoordinator] in
            breakCoordinator?.completeActiveBreak()
        }
        overlayController.onEscape = { [weak breakCoordinator] in
            breakCoordinator?.escapeActiveBreak()
        }

        breakCoordinator.start(with: schedules.filter(\.isEnabled), preferences: preferences)

        eventListenerTask = Task {
            for await event in breakCoordinator.events {
                handleEvent(event)
            }
        }
    }

    private func stopCoordinator() {
        eventListenerTask?.cancel()
        eventListenerTask = nil
        coordinator?.stop()
        coordinator = nil
        overlayController.onSkip = nil
        overlayController.onComplete = nil
        overlayController.onEscape = nil
    }

    private func restartCoordinator() {
        stopCoordinator()
        isPaused = false
        pausedUntil = nil
        if !schedules.filter(\.isEnabled).isEmpty {
            startCoordinator()
        } else {
            nextBreakTime = nil
            breakScheduledAt = nil
            breakProgress = 0
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: CoordinatorEvent) {
        switch event {
        case .nextBreakScheduled(let date):
            deferralReason = nil
            nextBreakTime = date
            breakScheduledAt = Date()
            recalculateProgress()
            updateMenuBarTimer()
            if menuBarTimerText != nil {
                progressTimer?.cancel()
                startProgressTimer()
            }

        case .breakStarted(let e):
            deferralReason = nil
            isBreakActive = true
            currentBreakRemaining = e.duration
            currentLevel = e.level
            breakProgress = 1.0

        case .breakCompleted, .breakSkipped, .breakEscaped:
            isBreakActive = false
            currentBreakRemaining = 0
            breakProgress = 0
            menuBarTimerText = nil

        case .breakDeferred(let reason, _):
            deferralReason = reason

        case .schedulePaused(let until):
            isPaused = true
            pausedUntil = until
            menuBarTimerText = nil

        case .scheduleResumed:
            isPaused = false
            pausedUntil = nil
            updateMenuBarTimer()

        case .statisticsUpdated(let stats):
            todayStats = stats
            saveStatistics()
            updateDailyHistory(stats)
        }
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
        saveSchedules()
        restartCoordinator()
    }

    func updateSchedule(_ schedule: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
            restartCoordinator()
        }
    }

    func deleteSchedule(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
        restartCoordinator()
    }

    // MARK: - Quick Actions

    func skipNextBreak() {
        coordinator?.skipNextBreak()
    }

    func pauseSchedule(for duration: TimeInterval) {
        coordinator?.pause(for: duration)
    }

    func resumeSchedule() {
        isPaused = false
        pausedUntil = nil
        breakProgress = 0
        breakScheduledAt = nil
        nextBreakTime = nil
        if let coordinator {
            coordinator.resume()
        } else if !schedules.filter(\.isEnabled).isEmpty {
            startCoordinator()
        }
    }

    func changeDisciplineLevel(_ level: DisciplineLevel) {
        coordinator?.changeDisciplineLevel(level)
    }

    // MARK: - System Sleep

    private func observeSystemSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.coordinator?.handleSystemSleep()
            }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.coordinator?.handleSystemWake()
            }
        }

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.coordinator?.handleScreenLock()
            }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.coordinator?.handleScreenUnlock()
            }
        }
    }

    // MARK: - Break Progress

    private func startProgressTimer() {
        progressTimer = Task {
            while !Task.isCancelled {
                recalculateProgress()
                updateMenuBarTimer()

                let interval: Duration = if let remaining = nextBreakTime?.timeIntervalSinceNow,
                                            menuBarTimerText != nil, remaining < 60 {
                    .seconds(1)
                } else {
                    .seconds(10)
                }
                try? await Task.sleep(for: interval, tolerance: interval == .seconds(10) ? .seconds(2) : .milliseconds(100))
                guard !Task.isCancelled else { break }
            }
        }
    }

    private func updateMenuBarTimer() {
        let remaining = nextBreakTime?.timeIntervalSinceNow ?? 0
        menuBarTimerText = formatMenuBarTimer(
            secondsRemaining: remaining,
            showFullTimer: preferences.showFullWorkTimer,
            countdownMinutes: preferences.menuBarCountdownMinutes,
            isBreakActive: isBreakActive,
            isPaused: isPaused,
            hasScheduledBreak: nextBreakTime != nil
        )
    }

    private func recalculateProgress() {
        if isPaused { return }
        breakProgress = calculateBreakProgress(
            scheduledAt: breakScheduledAt,
            nextBreak: nextBreakTime,
            isBreakActive: isBreakActive
        )
    }

    // MARK: - Onboarding

    func showOnboardingIfNeeded() {
        guard !hasCompletedOnboarding, onboardingWindow == nil else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingView()
                .environmentObject(self)
                .environmentObject(permissionChecker)
        )
        window.center()

        let delegate = OnboardingWindowCloseDelegate { [weak self] in
            self?.dismissOnboardingWindow()
        }
        window.delegate = delegate
        onboardingWindowDelegate = delegate
        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismissOnboardingWindow()
    }

    private func dismissOnboardingWindow() {
        guard let window = onboardingWindow else { return }
        window.contentView = nil
        window.orderOut(nil)
        onboardingWindow = nil
        onboardingWindowDelegate = nil

        let hasOtherVisible = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
        if !hasOtherVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func createDefaultSchedule(progressiveEnforcement: Bool = false) {
        let defaultSchedule = Schedule(
            name: "Work Hours",
            days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 45 * 60,
            breakDuration: 5 * 60,
            disciplineLevel: .gentle,
            progressiveEnforcement: progressiveEnforcement
        )
        addSchedule(defaultSchedule)
    }
}

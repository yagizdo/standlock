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
    private var calendarDetector: CalendarDetector?
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
            if todayStats.resetDailyIfNeeded(currentDate: Date()) {
                saveStatistics()
            }
        }

        if let data = UserDefaults.standard.data(forKey: "breakHistory"),
           let decoded = try? JSONDecoder().decode(BreakHistory.self, from: data) {
            breakHistory = decoded
        }
        let cutoff = DailyBreakRecord.dateKey(
            from: Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        )
        if breakHistory.pruneOlderThan(cutoff) {
            saveHistory()
        }

        // Back-fills today's record for users upgrading from before break history existed. Must
        // stay below the daily reset above, otherwise stale multi-day totals land on today.
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
        // The look-ahead window lives in the detector, not in the preferences the coordinator
        // holds, so it has to be pushed separately or the stepper only lands on the next restart.
        calendarDetector?.lookAheadMinutes = preferences.calendarLookAheadMinutes
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

        // Strict is gated at the point the schedules reach the coordinator, never written back
        // to the stored ones. A permission read is instantaneous and can be briefly false --
        // a login-item cold start before TCC is warm, an event tap that fails for reasons other
        // than permission, a checkbox toggled off and back on. Persisting the downgrade turned
        // any of those into silent, unrecoverable config loss.
        let strictAvailable = permissionChecker.strictModeAvailable
        guard lastStrictModeAvailable != strictAvailable else { return }
        lastStrictModeAvailable = strictAvailable
        if coordinator != nil,
           schedules.contains(where: { $0.isEnabled && $0.disciplineLevel == .strict }) {
            restartCoordinator()
        }
    }

    private var lastStrictModeAvailable: Bool?

    /// Enabled schedules with Strict reduced to Firm while the permissions it needs are missing.
    /// Firm, not Gentle: Strict is chosen for maximum friction, and Gentle's first tier is a
    /// plain skip button, so a permission blip would hand the user a break they can dismiss
    /// instantly. Firm keeps real friction (delay plus phrase) and needs no permission at all --
    /// only Strict installs the event tap, in `OverlayWindowController.showOverlay`.
    private func enforceableSchedules() -> [Schedule] {
        let strictAvailable = permissionChecker.strictModeAvailable
        return schedules.filter(\.isEnabled).map { schedule in
            guard !strictAvailable, schedule.disciplineLevel == .strict else { return schedule }
            var downgraded = schedule
            downgraded.disciplineLevel = .firm
            return downgraded
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
        // Zeroed counters never describe a day worth recording: they mean either a fresh day
        // just rolled over or a deferral-only update, and a stored record with zero completed
        // breaks ends the streak in BreakHistory.currentStreak while a missing one reads as a
        // day still in progress. Writing them would also let a backwards day change (date-line
        // travel, an NTP correction) blank out a day that already has real numbers.
        guard stats.totalBreaks > 0 else { return }
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

    private func startCoordinator(restoring state: EnforcementState = EnforcementState()) {
        stopCoordinator()
        let scheduler = ScheduleEvaluator()
        let calendarDetector = CalendarDetector(lookAheadMinutes: preferences.calendarLookAheadMinutes)
        self.calendarDetector = calendarDetector
        let detector = CompositeDetector(calendar: calendarDetector)
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

        breakCoordinator.start(with: enforceableSchedules(),
                               preferences: preferences,
                               statistics: todayStats,
                               restoring: state)

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
        calendarDetector = nil
        overlayController.onSkip = nil
        overlayController.onComplete = nil
        overlayController.onEscape = nil
        clearActiveBreakState()
        deferralReason = nil
    }

    /// Nobody else can clear the published break state once the coordinator is gone: `stop()`
    /// pulls the overlay down without yielding an event, and the listener that would have
    /// carried one is cancelled just above. Leaving it set made the menu bar report a break in
    /// progress with no overlay on screen -- and kept the quick actions disabled -- until the
    /// next break fired. Reachable by editing a schedule while a break is up.
    private func clearActiveBreakState() {
        isBreakActive = false
        currentBreakRemaining = 0
        breakProgress = 0
        menuBarTimerText = nil
    }

    private func restartCoordinator() {
        // Captured before the teardown: every counter below lives on the coordinator instance,
        // so a rebuild would otherwise re-arm the daily cap from zero and restart the interval
        // cycle -- editing a schedule at noon quietly undid the morning's enforcement.
        let carried = coordinator?.captureEnforcementState() ?? EnforcementState()
        // A pause is a user decision with a deadline, not coordinator bookkeeping. The rebuilt
        // coordinator starts unpaused and arms a break straight away, so the time still owed has
        // to be re-applied -- otherwise editing a schedule ends a pause the user asked for, and
        // the next break lands during the hour they meant to keep clear. Re-applying it yields
        // `schedulePaused`, which restores the published flags below through `handleEvent`.
        let pauseRemaining = pausedUntil?.timeIntervalSinceNow
        stopCoordinator()
        isPaused = false
        pausedUntil = nil
        if !schedules.filter(\.isEnabled).isEmpty {
            startCoordinator(restoring: carried)
            if let pauseRemaining, pauseRemaining > 0 {
                coordinator?.pause(for: pauseRemaining)
            }
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
            clearActiveBreakState()

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
                rolloverDailyStatsIfNeeded()
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

    /// Clears the per-day counters once the calendar day changes. The coordinator owns the
    /// live statistics, so it rolls over first and reports back through `statisticsUpdated`;
    /// the local copy is only rolled directly when no coordinator is running.
    private func rolloverDailyStatsIfNeeded() {
        if let coordinator {
            coordinator.refreshDailyRollover()
        } else if todayStats.resetDailyIfNeeded(currentDate: Date()) {
            saveStatistics()
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

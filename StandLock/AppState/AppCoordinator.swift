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
    /// The running Pomodoro session, nil when none runs.
    @Published private(set) var pomodoroStatus: PomodoroStatus?

    let languageStore = LanguageStore()
    let themeStore = ThemeStore()
    let settingsNavigation = SettingsNavigation()
    let permissionChecker: PermissionChecker
    private let breakSoundPlayer = BreakSoundPlayer()

    private var coordinator: BreakCoordinator?
    /// Survives the coordinator-less interval between a teardown and the next build.
    /// Disabling the last schedule leaves no coordinator to capture from, so without
    /// this the counters were lost the moment the enabled set emptied.
    private var carriedEnforcementState = EnforcementState()
    /// The day the carry was taken on. `rolloverIfNeeded` clears the counters on the
    /// coordinator, but there is no coordinator to run it while every schedule is off, so a
    /// carry that outlives the day is dropped here -- otherwise re-enabling a schedule the
    /// next morning restores yesterday's exhausted cap.
    private var carriedEnforcementDay = Date()
    /// One store shared by the Settings list and the coordinator, so it survives the coordinator
    /// rebuilds that follow a schedule edit.
    private let calendarDetector = CalendarDetector()
    @Published private(set) var availableCalendars: [CalendarInfo] = []
    private let overlayController: OverlayWindowController
    private var eventListenerTask: Task<Void, Never>?
    private var progressTimer: Task<Void, Never>?
    private var loadedExercises: [Exercise] = []
    private var onboardingWindow: NSWindow?
    private var onboardingWindowDelegate: OnboardingWindowCloseDelegate?
    /// Restored when onboarding ends. Not found by scanning `NSApp.windows`: the status bar
    /// window is always there and visible, so a scan never let the Dock icon go.
    private var policyBeforeOnboarding: NSApplication.ActivationPolicy = .accessory
    private var permissionSyncCancellable: AnyCancellable?
    private var calendarStatusCancellable: AnyCancellable?
    /// Tracks the calendar grant so the store is reset exactly on the false -> true transition.
    private var lastCalendarAuthorized = false

    init() {
        permissionChecker = PermissionChecker(languageStore: languageStore)
        overlayController = OverlayWindowController(languageStore: languageStore, themeStore: themeStore)
        // Before the first window appears, so a stored Light or Dark choice is already
        // in force rather than repainting a frame after launch.
        themeStore.applyAppearance()
        loadExercises()
        loadData()
        applyCalendarPreferences()
        refreshAvailableCalendars()
        syncPreferencesWithPermissions()
        startProgressTimer()
        observeSystemSleep()
        // Quitting must not hand back a fresh interval, cap and tier on relaunch.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveEnforcementState()
                self?.savePomodoroSession()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .standLockReopen, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.bringOnboardingForward() else { return }
                self.settingsNavigation.open(nil)
            }
        }
        permissionSyncCancellable = permissionChecker.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncPreferencesWithPermissions()
            }
        lastCalendarAuthorized = permissionChecker.calendarIntegrationAvailable
        calendarStatusCancellable = permissionChecker.$calendarStatus
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.handleCalendarAuthorizationChange()
            }
        Task { await permissionChecker.pollContinuously() }
        // Always built: a Pomodoro session runs with no schedule enabled.
        startCoordinator(restoring: carriedStateForToday())
        restoreSavedPomodoroSession()
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

        if let data = UserDefaults.standard.data(forKey: "enforcementState"),
           let decoded = try? JSONDecoder().decode(EnforcementState.self, from: data),
           let day = UserDefaults.standard.object(forKey: "enforcementStateDay") as? Date {
            carriedEnforcementState = decoded
            carriedEnforcementDay = day
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
        syncScheduledWeekdays()
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
        syncScheduledWeekdays()
    }

    /// The streak reads this to tell a missed day from one no schedule runs on.
    private func syncScheduledWeekdays() {
        breakHistory.scheduledWeekdays = schedules.filter(\.isEnabled)
            .reduce(into: Set<Weekday>()) { $0.formUnion($1.days.activeDays) }
    }

    func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: "preferences")
        coordinator?.updatePreferences(preferences)
        // The look-ahead window and the calendar selection live in the detector, not in the
        // preferences the coordinator holds, so they have to be pushed separately or they only
        // land on the next coordinator rebuild.
        applyCalendarPreferences()
        updateMenuBarTimer()
    }

    /// The Settings list reads this; refreshed on launch and whenever permissions change.
    func refreshAvailableCalendars() {
        availableCalendars = calendarDetector.availableCalendars()
    }

    /// The detector owns the look-ahead and the calendar selection, so both have to be pushed
    /// into it whenever the preferences change or a coordinator is built.
    private func applyCalendarPreferences() {
        calendarDetector.lookAheadMinutes = preferences.calendarLookAheadMinutes
        calendarDetector.calendarSelectionMode = preferences.calendarSelectionMode
        calendarDetector.selectedCalendarIdentifiers = Set(preferences.selectedCalendarIdentifiers)
    }

    private func handleCalendarAuthorizationChange() {
        let authorized = permissionChecker.calendarIntegrationAvailable
        if authorized && !lastCalendarAuthorized {
            calendarDetector.resetStore()
        }
        lastCalendarAuthorized = authorized
        refreshAvailableCalendars()
    }

    private func syncPreferencesWithPermissions() {
        var prefsChanged = false
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
        // A Strict session is gated too, even after its Strict schedule was switched off.
        if coordinator != nil,
           schedules.contains(where: scheduleUsesStrict)
            || (coordinator?.pomodoroSession != nil && pomodoroRequestedLevel == .strict) {
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
        schedules.filter(\.isEnabled).map { schedule in
            var gated = schedule
            gated.disciplineLevel = enforceable(schedule.disciplineLevel)
            return gated
        }
    }

    /// Strict needs its permissions now; without them it runs as Firm.
    private func enforceable(_ level: DisciplineLevel) -> DisciplineLevel {
        level == .strict && !permissionChecker.strictModeAvailable ? .firm : level
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
        let enabledSchedules = schedules.filter(\.isEnabled)
        let avgDuration = enabledSchedules.isEmpty
            ? 300.0
            : enabledSchedules.map(\.breakDuration).reduce(0, +) / Double(enabledSchedules.count)
        // Zeroed counters write nothing: a stored record with zero completed breaks ends the
        // streak in BreakHistory.currentStreak while a missing one reads as a day in progress.
        guard breakHistory.recordDay(stats, on: DailyBreakRecord.dateKey(from: Date()),
                                     hasActiveSchedule: !enabledSchedules.isEmpty,
                                     averageBreakDuration: avgDuration) else { return }
        saveHistory()
    }

    // MARK: - Coordinator Lifecycle

    private func startCoordinator(restoring state: EnforcementState = EnforcementState()) {
        stopCoordinator()
        let scheduler = ScheduleEvaluator()
        applyCalendarPreferences()
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
        overlayController.onPostpone = { [weak breakCoordinator] in
            breakCoordinator?.postponeActiveBreak()
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
        overlayController.onSkip = nil
        overlayController.onComplete = nil
        overlayController.onEscape = nil
        overlayController.onPostpone = nil
        clearActiveBreakState()
        deferralReason = nil
        // The rebuilt coordinator reports a carried session again.
        pomodoroStatus = nil
    }

    /// Nobody else can clear the published break state once the coordinator is gone: `stop()`
    /// pulls the overlay down without yielding an event, and the listener that would have
    /// carried one is cancelled just above. Leaving it set made the menu bar report a break in
    /// progress with no overlay on screen -- and kept the quick actions disabled -- until the
    /// next break fired. Reachable by editing a schedule while a break is up.
    ///
    /// `nextBreakTime` and `breakScheduledAt` are deliberately left alone: `breakProgressAnchor`
    /// compares the surviving `nextBreakTime` against the re-armed slot to decide whether the
    /// interval is the same one. Clearing them here restarts the progress ring on every rebuild.
    private func clearActiveBreakState() {
        isBreakActive = false
        currentBreakRemaining = 0
        breakProgress = 0
        menuBarTimerText = nil
    }

    private func carriedStateForToday() -> EnforcementState {
        guard Calendar.current.isDateInToday(carriedEnforcementDay) else { return EnforcementState() }
        // The coordinator carries a disabled schedule's slot without knowing whether the
        // schedule still exists; a deleted one's slot stops here.
        var state = carriedEnforcementState
        let ids = Set(schedules.map(\.id))
        state.pendingBreakDates = state.pendingBreakDates.filter { ids.contains($0.key) }
        return state
    }

    /// Captures from the live coordinator. It runs with every schedule off too, and hands on the
    /// state of schedules it was not given.
    private func saveEnforcementState() {
        if let coordinator {
            carriedEnforcementState = coordinator.captureEnforcementState()
            carriedEnforcementDay = Date()
        }
        guard let data = try? JSONEncoder().encode(carriedEnforcementState) else { return }
        UserDefaults.standard.set(data, forKey: "enforcementState")
        UserDefaults.standard.set(carriedEnforcementDay, forKey: "enforcementStateDay")
    }

    // MARK: - Pomodoro

    private static let pomodoroSessionKey = "pomodoroSession"

    /// The level the session asked for (S87), before the Strict gate. Kept here, not read back
    /// from `pomodoroStatus`: that is filled a turn late and holds the gated level, so a permission
    /// blip would stick for the rest of the session.
    private var pomodoroRequestedLevel: DisciplineLevel?

    private var strictestEnabledLevel: DisciplineLevel {
        DisciplineLevel.strictest(of: schedules.filter(\.isEnabled).map(\.disciplineLevel))
    }

    func startPomodoro() {
        let level = strictestEnabledLevel
        pomodoroRequestedLevel = level
        coordinator?.startPomodoro(preferences.pomodoro, level: enforceable(level))
    }

    func stopPomodoro() {
        coordinator?.stopPomodoro()
    }

    func skipPomodoroPhase() {
        coordinator?.skipPomodoroPhase()
    }

    private func savePomodoroSession() {
        guard let session = coordinator?.pomodoroSession,
              let data = try? JSONEncoder().encode(session)
        else {
            UserDefaults.standard.removeObject(forKey: Self.pomodoroSessionKey)
            return
        }
        UserDefaults.standard.set(data, forKey: Self.pomodoroSessionKey)
    }

    /// Same day only, as `EnforcementState`; an older session is dropped and counted as
    /// abandoned on the day it started. The level is picked again: permissions may have
    /// changed while the app was closed.
    private func restoreSavedPomodoroSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.pomodoroSessionKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.pomodoroSessionKey)
        guard let session = try? JSONDecoder().decode(PomodoroSession.self, from: data) else { return }
        guard session.isRestorable(now: Date()) else {
            breakHistory = breakHistory.recordingAbandoned(session)
            saveHistory()
            return
        }
        let level = strictestEnabledLevel
        pomodoroRequestedLevel = level
        coordinator?.restorePomodoro(session, level: enforceable(level))
    }

    private func restartCoordinator() {
        // Captured before the teardown: every counter below lives on the coordinator instance,
        // so a rebuild would otherwise re-arm the daily cap from zero and restart the interval
        // cycle -- editing a schedule at noon quietly undid the morning's enforcement.
        saveEnforcementState()
        // A pause is a user decision with a deadline, not coordinator bookkeeping. The rebuilt
        // coordinator starts unpaused and arms a break straight away, so the time still owed has
        // to be re-applied -- otherwise editing a schedule ends a pause the user asked for, and
        // the next break lands during the hour they meant to keep clear. Re-applying it yields
        // `schedulePaused`, which restores the published flags below through `handleEvent`.
        let pauseRemaining = pausedUntil?.timeIntervalSinceNow
        // A session keeps its own level across a rebuild (S87 picks it at start), gated again here.
        let session = coordinator?.pomodoroSession
        stopCoordinator()
        isPaused = false
        pausedUntil = nil
        startCoordinator(restoring: carriedStateForToday())
        if let session {
            // Starting a session ended any pause, so there is none to re-apply.
            coordinator?.restorePomodoro(session, level: enforceable(pomodoroRequestedLevel ?? strictestEnabledLevel))
        } else if let pauseRemaining, pauseRemaining > 0 {
            coordinator?.pause(for: pauseRemaining)
        }
        clearNextBreakIfIdle()
    }

    /// With no enabled schedule and no session nothing is armed; the stale countdown would
    /// otherwise stay on the menu bar and keep `NextBreakState` counting down.
    private func clearNextBreakIfIdle() {
        guard pomodoroStatus == nil, coordinator?.pomodoroSession == nil,
              schedules.filter(\.isEnabled).isEmpty else { return }
        nextBreakTime = nil
        breakScheduledAt = nil
        breakProgress = 0
        updateMenuBarTimer()
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: CoordinatorEvent) {
        switch event {
        case .nextBreakScheduled(let date):
            deferralReason = nil
            // Not always `Date()`: a rebuilt coordinator re-arms the slot it inherited, and
            // re-anchoring on that collapses the interval the ring measures to whatever is left
            // of it -- editing a schedule twenty seconds before a break emptied the menu bar
            // icon and refilled it over those twenty seconds.
            breakScheduledAt = breakProgressAnchor(
                existingAnchor: breakScheduledAt,
                existingNextBreak: nextBreakTime,
                newNextBreak: date
            )
            nextBreakTime = date
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
            if isBreakActive { clearActiveBreakState() }
            deferralReason = reason

        case .schedulePaused(let until):
            isPaused = true
            pausedUntil = until
            menuBarTimerText = nil

        case .scheduleResumed:
            isPaused = false
            pausedUntil = nil
            updateMenuBarTimer()

        case .breakCue(let cue):
            breakSoundPlayer.play(cue)

        case .pomodoroChanged(let status):
            pomodoroStatus = status
            savePomodoroSession()
            if status == nil {
                // The countdown pointed at the session; the schedules send their own next break
                // right after this, if they arm one (a reached daily cap arms none).
                nextBreakTime = nil
                breakScheduledAt = nil
                breakProgress = 0
                updateMenuBarTimer()
            }

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

    /// Replaces preferences and schedules from a settings file. Preferences go first so the
    /// rebuilt coordinator starts with them; the restart carries today's counters.
    func applyImport(preferences: AppPreferences, schedules: [Schedule]) {
        self.preferences = preferences
        savePreferences()
        syncPreferencesWithPermissions()
        self.schedules = schedules
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
            startCoordinator(restoring: carriedStateForToday())
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
            hasScheduledBreak: nextBreakTime != nil,
            minuteSuffix: languageStore.string("m")
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
            contentRect: NSRect(x: 0, y: 0, width: OnboardingView.size.width, height: OnboardingView.size.height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(
            rootView: LocalizedRoot(store: languageStore) {
                OnboardingView(scene: self.preferences.menuScene)
                    .environmentObject(self)
                    .environmentObject(self.permissionChecker)
            }
        )
        // The root has a fixed frame; without this SwiftUI resizes the window to each step.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.center()

        // Closing means finished with nothing set up, so the window does not come back.
        let delegate = OnboardingWindowCloseDelegate { [weak self] in
            self?.completeOnboarding()
        }
        window.delegate = delegate
        onboardingWindowDelegate = delegate
        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        policyBeforeOnboarding = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Stores what onboarding chose. The login item goes first: if it throws, nothing else is
    /// stored and the window stays, so a retry does not add a second schedule.
    func finishOnboarding(with choices: OnboardingChoices) throws {
        if choices.launchAtLogin {
            try LaunchAtLogin.set(true)
        }
        // `preferences` has no observer that saves it while Settings is closed.
        preferences.menuScene = choices.scene
        savePreferences()
        if let schedule = choices.schedule(named: languageStore.string("Work Hours")) {
            addSchedule(schedule)
        }
        completeOnboarding()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismissOnboardingWindow()
    }

    /// Returns false when no onboarding window is up.
    func bringOnboardingForward() -> Bool {
        guard let window = onboardingWindow else { return false }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func dismissOnboardingWindow() {
        guard let window = onboardingWindow else { return }
        window.contentView = nil
        window.orderOut(nil)
        onboardingWindow = nil
        onboardingWindowDelegate = nil
        NSApp.setActivationPolicy(policyBeforeOnboarding)
    }
}

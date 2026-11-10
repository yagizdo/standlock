import Testing
import Foundation
@testable import Coordination
@testable import StandLockCore

/// Collects what the coordinator reports, for checks after the fact.
@MainActor
final class EventLog {
    private(set) var events: [CoordinatorEvent] = []
    private var task: Task<Void, Never>?

    init(_ coordinator: BreakCoordinator) {
        task = Task { [weak self] in
            for await event in coordinator.events { self?.events.append(event) }
        }
    }

    deinit { task?.cancel() }

    var stats: BreakStatistics? {
        events.reversed().lazy.compactMap { if case .statisticsUpdated(let s) = $0 { s } else { nil } }.first
    }

    var completed: Int { stats?.breaksCompleted ?? 0 }
    var skipped: Int { stats?.breaksSkipped ?? 0 }

    var statuses: [PomodoroStatus?] {
        events.compactMap { if case .pomodoroChanged(let s) = $0 { .some(s) } else { nil } }
    }

    var nextBreaks: [Date] {
        events.compactMap { if case .nextBreakScheduled(let d) = $0 { d } else { nil } }
    }
}

@MainActor
private func makeCoordinator(
    schedules: [Schedule] = [],
    preferences: AppPreferences = AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false),
    scheduler: MockScheduler = MockScheduler()
) -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
    let detector = MockDetector()
    let locker = MockLocker()
    let coordinator = BreakCoordinator(
        scheduler: scheduler, detector: detector, locker: locker, deferralPollingInterval: 0.05
    )
    let log = EventLog(coordinator)
    coordinator.start(with: schedules, preferences: preferences)
    return (coordinator, detector, locker, log)
}

private let chip = PomodoroChip(round: 2, rounds: 4, isLong: false)

@Suite("BreakCoordinator external breaks")
@MainActor
struct ExternalBreakTests {

    @Test
    func externalBreakShowsOverlayWithChip() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 120, level: .firm, chip: chip))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastPomodoroChip == chip)
        #expect(locker.lastLevel == .firm)
        #expect(locker.lastDuration == TimeInterval(120))
        #expect(locker.lastEscalationTier == 0)
        #expect(locker.lastNextIntervalLabel == nil)
    }

    @Test
    func externalBreakDurationIsBounded() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 366 * 86_400, level: .strict, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == BreakSafety.maximumBreakDuration)
    }

    @Test
    func externalBreakDoneCountsOnce() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        coordinator.completeActiveBreak()
        coordinator.completeActiveBreak()
        #expect(await waitUntil { log.completed == 1 })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.completed == 1)
        #expect(!locker.isShowing)
    }

    @Test
    func externalBreakSkipCountsSkip() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        coordinator.skipActiveBreak()
        #expect(await waitUntil { log.skipped == 1 })
        #expect(log.completed == 0)
    }

    @Test
    func externalBreakPostponeReturnsWithoutRecount() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: chip))
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        #expect(!locker.isShowing)
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(locker.lastCanPostpone == false)
        #expect(locker.lastPomodoroChip == chip)
        coordinator.completeActiveBreak()
        #expect(await waitUntil { log.completed == 1 })
        #expect(log.skipped == 0)
        #expect(log.stats?.breaksDeferred == 1)
    }

    @Test
    func externalBreakIdleCreditCountsOnceAndShowsNoOverlay() async {
        let (coordinator, detector, locker, log) = makeCoordinator(preferences: AppPreferences(idleDetectionEnabled: true))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { log.completed == 1 })
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.completed == 1)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func externalBreakDefersDuringDetection() async {
        let (coordinator, detector, locker, _) = makeCoordinator(
            preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false)
        )
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!locker.showOverlayCalled)
        detector.contextToReturn = .clear
        #expect(await waitUntil { locker.isShowing })
    }
}

private let oneMinute = PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 120, rounds: 4)

@Suite("BreakCoordinator Pomodoro session")
@MainActor
struct PomodoroSessionCoordinationTests {

    /// A start dated just under one focus ago, so the first focus ends at once.
    private func startEndingFocus(_ coordinator: BreakCoordinator, level: DisciplineLevel = .gentle,
                                  configuration: PomodoroConfiguration = oneMinute) {
        coordinator.startPomodoro(configuration, level: level, now: Date().addingTimeInterval(0.05 - configuration.focus))
    }

    @Test
    func sessionCancelsScheduleTimer() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.1)
        let (coordinator, _, locker, _) = makeCoordinator(schedules: [makeSchedule()], scheduler: scheduler)
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func focusEmitsNextBreakScheduledAtFocusEnd() async {
        let (coordinator, _, _, log) = makeCoordinator()
        defer { coordinator.stop() }
        let now = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: now)
        #expect(await waitUntil { log.nextBreaks.last == now.addingTimeInterval(60) })
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    @Test
    func focusEndOpensExternalBreakWithChipTwoOfFour() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        startEndingFocus(coordinator, level: .firm)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 1, rounds: 4, isLong: false))
        coordinator.completeActiveBreak()
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 2, rounds: 4, isLong: false))
        #expect(locker.lastLevel == .firm)
        #expect(locker.lastDuration == TimeInterval(60))
    }

    @Test
    func doneAfterShortBreakStartsNextFocus() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        startEndingFocus(coordinator)
        #expect(await waitUntil { locker.isShowing })
        let before = Date()
        coordinator.completeActiveBreak()
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 2))
        let end = coordinator.pomodoroSession?.phaseEnd ?? .distantPast
        #expect(end >= before.addingTimeInterval(60) && end <= Date().addingTimeInterval(60))
        #expect(await waitUntil { log.nextBreaks.last == end })
        #expect(log.completed == 1)
    }

    @Test
    func fourthFocusOpensLongBreakWithLongChip() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        for round in 1...3 {
            coordinator.skipPomodoroPhase()
            #expect(await waitUntil { locker.showCount == round })
            coordinator.completeActiveBreak()
        }
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 4 })
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 4, rounds: 4, isLong: true))
        #expect(locker.lastDuration == TimeInterval(120))
        #expect(coordinator.pomodoroSession?.phase == .longBreak)
    }

    @Test
    func longBreakDoneFinishesSessionAndRearmsSchedule() async {
        let scheduler = MockScheduler()
        let far = Date().addingTimeInterval(3600)
        scheduler.nextBreakTimeToReturn = far
        let (coordinator, _, locker, log) = makeCoordinator(schedules: [makeSchedule()], scheduler: scheduler)
        defer { coordinator.stop() }
        coordinator.startPomodoro(PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 60, rounds: 1),
                                  level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        let afterStart = log.nextBreaks.count
        coordinator.completeActiveBreak()
        #expect(coordinator.pomodoroSession == nil)
        #expect(await waitUntil { log.statuses.last == .some(nil) })
        #expect(await waitUntil { log.nextBreaks.count > afterStart && log.nextBreaks.last == far })
    }

    @Test
    func stopIsNotSkipAndRearmsSchedule() async {
        let scheduler = MockScheduler()
        let far = Date().addingTimeInterval(3600)
        scheduler.nextBreakTimeToReturn = far
        let (coordinator, _, _, log) = makeCoordinator(schedules: [makeSchedule()], scheduler: scheduler)
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        #expect(await waitUntil { log.nextBreaks.last != far })
        coordinator.stopPomodoro()
        #expect(coordinator.pomodoroSession == nil)
        #expect(await waitUntil { log.nextBreaks.last == far && log.statuses.last == .some(nil) })
        #expect(log.skipped == 0)
    }

    @Test
    func finishedSessionTalliesFourRoundsAndOneFinished() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        startEndingFocus(coordinator)
        for round in 1...4 {
            if round > 1 { coordinator.skipPomodoroPhase() }
            #expect(await waitUntil { locker.showCount == round })
            coordinator.completeActiveBreak()
        }
        #expect(coordinator.pomodoroSession == nil)
        #expect(await waitUntil { log.stats?.pomodoroTallies?.sessionsFinished == 1 })
        let tallies = log.stats?.pomodoroTallies
        #expect(tallies?.rounds == 4)
        #expect(tallies?.sessionsFinished == 1)
        #expect(tallies?.sessionsAbandoned == 0)
        #expect(log.completed == 4)
    }

    @Test
    func stopTalliesAbandonedNotSkipped() async {
        let (coordinator, _, _, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.stopPomodoro()
        #expect(await waitUntil { log.stats?.pomodoroTallies?.sessionsAbandoned == 1 })
        #expect(log.stats?.pomodoroTallies?.rounds == 0)
        #expect(log.stats?.pomodoroTallies?.sessionsFinished == 0)
        #expect(log.skipped == 0)
        #expect(log.stats?.totalBreaks == 0)
    }

    /// A focus counts the time it ran: all of it at its end, only the part before Skip phase.
    @Test
    func focusTalliesTheTimeItRan() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        startEndingFocus(coordinator)
        #expect(await waitUntil { locker.isShowing && log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(abs((log.stats?.pomodoroTallies?.focusSeconds ?? 0) - 60) < 1)
        coordinator.completeActiveBreak()
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 2 && log.stats?.pomodoroTallies?.rounds == 2 })
        #expect(abs((log.stats?.pomodoroTallies?.focusSeconds ?? 0) - 60) < 1)
    }

    @Test
    func skipPhaseDuringFocusOpensBreakNow() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
    }

    @Test
    func emitsPomodoroChangedOnEveryPhase() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .firm, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        coordinator.completeActiveBreak()
        coordinator.stopPomodoro()
        #expect(await waitUntil { log.statuses.last == .some(nil) })
        let phases = log.statuses.map { $0?.phase }
        #expect(phases.first == .focus(round: 1))
        #expect(phases.contains(.shortBreak(afterRound: 1)))
        #expect(phases.contains(.focus(round: 2)))
        #expect(log.statuses.compactMap { $0 }.allSatisfy { $0.level == .firm && $0.rounds == 4 })
    }

    @Test
    func startWhilePausedClearsPause() async {
        let (coordinator, _, locker, log) = makeCoordinator(schedules: [makeSchedule()])
        defer { coordinator.stop() }
        coordinator.pause(for: 3600)
        startEndingFocus(coordinator)
        #expect(await waitUntil { locker.isShowing })
        #expect(log.events.contains { if case .scheduleResumed = $0 { true } else { false } })
    }

    @Test
    func escapeDuringSessionBreakAdvancesToNextFocus() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        startEndingFocus(coordinator)
        #expect(await waitUntil { locker.isShowing })
        coordinator.escapeActiveBreak()
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 2))
        #expect(await waitUntil { log.stats?.breaksEscaped == 1 })
        #expect(log.completed == 0)
    }

    @Test
    func deferredBreakPhaseEndStartsAtOverlay() async {
        let (coordinator, detector, locker, _) = makeCoordinator(
            preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false)
        )
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        startEndingFocus(coordinator)
        try? await Task.sleep(for: .milliseconds(400))
        detector.contextToReturn = .clear
        #expect(await waitUntil { locker.isShowing })
        let shown = locker.lastShownAt ?? .distantPast
        let end = coordinator.pomodoroSession?.phaseEnd ?? .distantPast
        #expect(abs(end.timeIntervalSince(shown.addingTimeInterval(60))) < 0.05)
    }

    @Test
    func skipPhaseDuringDeferredBreakCountsSkipAndStartsFocus() async {
        let (coordinator, detector, locker, log) = makeCoordinator(
            preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false)
        )
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        startEndingFocus(coordinator)
        #expect(await waitUntil { coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1) })
        try? await Task.sleep(for: .milliseconds(100))
        coordinator.skipPomodoroPhase()
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 2))
        #expect(await waitUntil { log.skipped == 1 })
        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func sessionEndWithoutSchedulesEmitsNoNextBreak() async {
        let (coordinator, _, _, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        #expect(await waitUntil { log.nextBreaks.count == 1 })
        coordinator.stopPomodoro()
        #expect(await waitUntil { log.statuses.last == .some(nil) })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.nextBreaks.count == 1)
    }

    @Test
    func menuSkipAndPauseDoNothingDuringSession() async {
        let (coordinator, _, _, log) = makeCoordinator(schedules: [makeSchedule()])
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipNextBreak()
        coordinator.pause(for: 60)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.skipped == 0)
        #expect(!log.events.contains { if case .schedulePaused = $0 { true } else { false } })
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    @Test
    func outOfBoundsConfigurationFallsBackToStandard() {
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stop() }
        let now = Date()
        coordinator.startPomodoro(PomodoroConfiguration(focus: 0, shortBreak: 0, longBreak: 1e300, rounds: 0),
                                  level: .strict, now: now)
        #expect(coordinator.pomodoroSession?.configuration == .standard)
        #expect(coordinator.pomodoroSession?.phaseEnd == now.addingTimeInterval(25 * 60))
    }
}

@Suite("BreakCoordinator Pomodoro sleep, lock and restore")
@MainActor
struct PomodoroLifetimeTests {

    private func onBreak(_ configuration: PomodoroConfiguration = oneMinute,
                         preferences: AppPreferences = AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false),
                         streak: Int = 3) async -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
        let detector = MockDetector()
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: detector, locker: locker,
                                           deferralPollingInterval: 0.05)
        let log = EventLog(coordinator)
        var stats = BreakStatistics()
        stats.currentStreak = streak
        coordinator.start(with: [], preferences: preferences, statistics: stats)
        coordinator.startPomodoro(configuration, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        _ = await waitUntil { locker.isShowing }
        return (coordinator, detector, locker, log)
    }

    @Test
    func lockDuringSessionBreakIsNotSkip() async {
        let (coordinator, _, locker, log) = await onBreak()
        defer { coordinator.stop() }
        coordinator.handleScreenLock()
        #expect(!locker.isShowing)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.skipped == 0)
        #expect(!log.events.contains { if case .breakSkipped = $0 { true } else { false } })
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
    }

    @Test
    func returnAfterCoveringBreakCreditsItOnce() async {
        let (coordinator, _, locker, log) = await onBreak()
        defer { coordinator.stop() }
        coordinator.handleScreenLock()
        let back = Date().addingTimeInterval(120)
        coordinator.handleScreenUnlock(now: back)
        coordinator.handleSystemWake(now: back)
        #expect(await waitUntil { log.completed == 1 })
        #expect(log.stats?.currentStreak == 4)
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 2))
        #expect(coordinator.pomodoroSession?.phaseEnd == back.addingTimeInterval(60))
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(log.completed == 1)
        #expect(locker.showCount == 1)
    }

    @Test
    func returnMidBreakReopensWithRemaining() async {
        let (coordinator, _, locker, log) = await onBreak()
        defer { coordinator.stop() }
        coordinator.handleScreenLock()
        let back = Date().addingTimeInterval(20)
        coordinator.handleScreenUnlock(now: back)
        coordinator.handleSystemWake(now: back)
        #expect(await waitUntil { locker.showCount == 2 })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(locker.showCount == 2)
        #expect(abs((locker.lastDuration ?? 0) - 40) < 0.5)
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 1, rounds: 4, isLong: false))
        #expect(log.completed == 0)
    }

    @Test
    func returnAfterLongBreakFinishes() async {
        let (coordinator, _, _, log) = await onBreak(PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 60, rounds: 1))
        defer { coordinator.stop() }
        #expect(coordinator.pomodoroSession?.phase == .longBreak)
        coordinator.handleSystemSleep()
        coordinator.handleSystemWake(now: Date().addingTimeInterval(3600))
        // The nil status follows the completion event; the log appends them on separate turns.
        #expect(await waitUntil { log.completed == 1 && log.statuses.last == .some(nil) })
        #expect(coordinator.pomodoroSession == nil)
    }

    @Test
    func focusEndedWhileAwayCreditsTheBreakOrOpensWhatIsLeft() async {
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: MockDetector(), locker: locker)
        defer { coordinator.stop() }
        let log = EventLog(coordinator)
        coordinator.start(with: [], preferences: AppPreferences(idleDetectionEnabled: false))
        let start = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: start)
        coordinator.handleScreenLock(now: start.addingTimeInterval(30))
        // Away 50 s, all counted as rest: 10 s of the 60 s break are left.
        coordinator.handleScreenUnlock(now: start.addingTimeInterval(80))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == TimeInterval(10))
        #expect(log.completed == 0)
        // The focus ended while away: one round, its full minute.
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(abs((log.stats?.pomodoroTallies?.focusSeconds ?? 0) - 60) < 1)
    }

    /// Away long enough to cover the focus and its break: the round still counts once.
    @Test
    func focusAndBreakCoveredWhileAwayTallyOneRound() async {
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: MockDetector(), locker: locker)
        defer { coordinator.stop() }
        let log = EventLog(coordinator)
        coordinator.start(with: [], preferences: AppPreferences(idleDetectionEnabled: false))
        let start = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: start)
        coordinator.handleScreenLock(now: start.addingTimeInterval(30))
        coordinator.handleScreenUnlock(now: start.addingTimeInterval(200))
        #expect(await waitUntil { log.completed == 1 && log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(abs((log.stats?.pomodoroTallies?.focusSeconds ?? 0) - 60) < 1)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func deferralThenLockUsesOverlayPhaseEnd() async {
        let detector = MockDetector()
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: detector, locker: locker,
                                           deferralPollingInterval: 0.05)
        defer { coordinator.stop() }
        let log = EventLog(coordinator)
        coordinator.start(with: [], preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false))
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        try? await Task.sleep(for: .milliseconds(500))
        detector.contextToReturn = .clear
        #expect(await waitUntil { locker.isShowing })
        let shown = locker.lastShownAt ?? Date()
        coordinator.handleScreenLock(now: shown.addingTimeInterval(59.7))
        // Past a phase end counted from the focus end, short of one counted from the overlay.
        coordinator.handleScreenUnlock(now: shown.addingTimeInterval(59.8))
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(log.completed == 0)
    }

    @Test
    func restoreSameDayCatchesUp() async {
        let now = Date()
        let config = oneMinute
        func restored(_ phase: PomodoroPhase, end: Date) async -> (BreakCoordinator, MockLocker, EventLog) {
            let locker = MockLocker()
            let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: MockDetector(), locker: locker)
            let log = EventLog(coordinator)
            coordinator.start(with: [], preferences: AppPreferences(idleDetectionEnabled: false))
            var session = PomodoroSession.start(at: now.addingTimeInterval(-600), configuration: config)
            session.phase = phase
            session.phaseEnd = end
            coordinator.restorePomodoro(session, level: .firm, now: now)
            return (coordinator, locker, log)
        }

        // Focus still running: the timer is armed for its end.
        let (running, runningLocker, runningLog) = await restored(.focus(round: 2), end: now.addingTimeInterval(30))
        #expect(await waitUntil { runningLog.nextBreaks.last == now.addingTimeInterval(30) })
        #expect(!runningLocker.showOverlayCalled)
        running.stop()

        // Focus ended while the app was closed: the break opens in full.
        let (focusDone, focusLocker, _) = await restored(.focus(round: 2), end: now.addingTimeInterval(-10))
        #expect(await waitUntil { focusLocker.isShowing })
        #expect(focusLocker.lastDuration == TimeInterval(60))
        #expect(focusLocker.lastLevel == .firm)
        #expect(focusDone.pomodoroSession?.phase == .shortBreak(afterRound: 2))
        focusDone.stop()

        // Break ran out while the app was closed: that time was not rest, the break opens in full.
        let (breakDone, breakLocker, breakLog) = await restored(.shortBreak(afterRound: 2), end: now.addingTimeInterval(-10))
        #expect(await waitUntil { breakLocker.isShowing })
        #expect(breakLocker.lastDuration == TimeInterval(60))
        #expect(breakLog.completed == 0)
        #expect(breakDone.pomodoroSession?.phase == .shortBreak(afterRound: 2))
        breakDone.stop()

        // Break still running when the app went away: it opens in full too. The saved session
        // cannot tell an on-screen break from a deferred one, whose phase end is stale.
        let (midBreak, midLocker, _) = await restored(.shortBreak(afterRound: 2), end: now.addingTimeInterval(25))
        #expect(await waitUntil { midLocker.isShowing })
        #expect(midLocker.lastDuration == TimeInterval(60))
        midBreak.stop()
    }

    @Test
    func restoreDropsSessionOutsideBounds() {
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: MockDetector(), locker: MockLocker())
        defer { coordinator.stop() }
        coordinator.start(with: [], preferences: AppPreferences())
        var session = PomodoroSession.start(at: Date(), configuration: oneMinute)
        session.configuration.focus = 0
        coordinator.restorePomodoro(session, level: .gentle, now: Date())
        #expect(coordinator.pomodoroSession == nil)
    }
}

@Suite("BreakCoordinator Pomodoro waiting breaks")
@MainActor
struct PomodoroWaitingBreakTests {

    private func deferredSession() -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
        let detector = MockDetector()
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: detector, locker: locker,
                                           deferralPollingInterval: 0.05)
        let log = EventLog(coordinator)
        coordinator.start(with: [], preferences: AppPreferences(cameraDetection: .deferBreak, postponeReturnDelay: 0.1,
                                                                idleDetectionEnabled: false))
        return (coordinator, detector, locker, log)
    }

    @Test
    func shortLockAfterADeferredBreakRanPastItsEndCreditsNothing() async {
        let (coordinator, detector, locker, log) = deferredSession()
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { coordinator.pomodoroSession?.phase.isBreak == true })
        let late = Date().addingTimeInterval(100)
        coordinator.handleScreenLock(now: late)
        detector.contextToReturn = .clear
        // Owed in full from the lock; the one second away counts as rest.
        coordinator.handleScreenUnlock(now: late.addingTimeInterval(1))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == TimeInterval(59))
        #expect(log.completed == 0)
    }

    @Test
    func shortLockDuringADeferralOpensTheFullBreak() async {
        let (coordinator, detector, locker, _) = deferredSession()
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { coordinator.pomodoroSession?.phase.isBreak == true })
        let soon = Date().addingTimeInterval(20)
        coordinator.handleScreenLock(now: soon)
        detector.contextToReturn = .clear
        coordinator.handleScreenUnlock(now: soon.addingTimeInterval(1))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == TimeInterval(59))
    }

    @Test
    func shortLockDuringAPostponeCreditsNothingAndKeepsTheWait() async {
        let (coordinator, detector, locker, log) = deferredSession()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.postponeActiveBreak()
        let late = Date().addingTimeInterval(100)
        coordinator.handleScreenLock(now: late)
        coordinator.handleScreenUnlock(now: late.addingTimeInterval(1))
        try? await Task.sleep(for: .milliseconds(300))
        #expect(log.completed == 0)
        #expect(locker.showCount == 1)
        detector.contextToReturn = .clear
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(locker.lastCanPostpone == false)
        #expect(locker.lastDuration == TimeInterval(60))
    }

    @Test
    func lockAfterAPostponedBreakReturnsDoesNotOfferPostponeAgain() async {
        let (coordinator, _, locker, _) = deferredSession()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        #expect(await waitUntil { locker.showCount == 2 })
        coordinator.handleScreenLock()
        coordinator.handleScreenUnlock(now: Date().addingTimeInterval(5))
        #expect(await waitUntil { locker.showCount == 3 })
        #expect(locker.lastCanPostpone == false)
        coordinator.completeActiveBreak()
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 4 })
        #expect(locker.lastCanPostpone == true)
    }

    @Test
    func skipPhaseDuringAPostponeLeavesNoBreakBehind() async {
        let (coordinator, detector, locker, log) = deferredSession()
        defer { coordinator.stop() }
        coordinator.startPomodoro(PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 60, rounds: 2),
                                  level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.postponeActiveBreak()
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { log.skipped == 1 })
        detector.contextToReturn = .clear
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 2 })
        coordinator.completeActiveBreak()
        #expect(coordinator.pomodoroSession == nil)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showCount == 2)
    }
}

@Suite("BreakCoordinator Pomodoro branch review")
@MainActor
struct PomodoroBranchReviewTests {

    private var dropped: (EventLog) -> [PomodoroSession] {
        { log in log.events.compactMap { if case .pomodoroDropped(let s) = $0 { s } else { nil } } }
    }

    /// A lid closed in the evening must not bring the session back as the next morning's focus.
    @Test
    func awayPastMidnightDropsTheSession() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        let start = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: start)
        coordinator.handleSystemSleep(now: start.addingTimeInterval(10))
        let morning = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        coordinator.handleSystemWake(now: morning)
        // The nil status follows the drop event; the log appends them on separate turns.
        #expect(await waitUntil { dropped(log).count == 1 && log.statuses.last == .some(nil) })
        #expect(coordinator.pomodoroSession == nil)
        #expect(log.completed == 0)
        #expect(log.stats?.pomodoroTallies?.rounds ?? 0 == 0)
        // Recorded by the app on the day the session started, not counted in today's tallies.
        #expect(log.stats?.pomodoroTallies?.sessionsAbandoned ?? 0 == 0)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func shortLockKeepsTheSession() async {
        let (coordinator, _, _, log) = makeCoordinator()
        defer { coordinator.stop() }
        let start = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: start)
        coordinator.handleScreenLock(now: start.addingTimeInterval(5))
        coordinator.handleScreenUnlock(now: start.addingTimeInterval(10))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(dropped(log).isEmpty)
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    /// A rebuild hands the session to `start`: the schedules must not arm for one turn first,
    /// or the progress anchor moves twice.
    @Test
    func startWithASessionArmsOnlyTheFocus() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: MockDetector(), locker: MockLocker())
        defer { coordinator.stop() }
        let log = EventLog(coordinator)
        let now = Date()
        var session = PomodoroSession.start(at: now.addingTimeInterval(-30), configuration: oneMinute)
        session.phaseEnd = now.addingTimeInterval(30)
        coordinator.start(with: [makeSchedule()], preferences: AppPreferences(idleDetectionEnabled: false),
                          pomodoro: (session, .gentle))
        #expect(await waitUntil { !log.nextBreaks.isEmpty })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.nextBreaks == [session.phaseEnd])
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    /// A schedule break postponed before the session is replaced by the session's breaks.
    @Test
    func sessionDropsAPostponedScheduleBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let (coordinator, _, locker, _) = makeCoordinator(schedules: [makeSchedule()], scheduler: scheduler)
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(3600)
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        #expect(coordinator.captureEnforcementState().postponedScheduleID == nil)
        coordinator.stopPomodoro()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(locker.showCount == 1)
    }

    /// Skip phase queues the focus end; a lock in the same turn cancels it, and the
    /// cancelled task must not move the session into a break nothing opens.
    @Test
    func cancelledSkipPhaseLeavesTheFocusRunning() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        let start = Date()
        coordinator.startPomodoro(oneMinute, level: .gentle, now: start)
        coordinator.skipPomodoroPhase()
        coordinator.handleScreenLock(now: start)
        coordinator.handleScreenUnlock(now: start.addingTimeInterval(1))
        try? await Task.sleep(for: .milliseconds(100))
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func idleAtFocusEndCreditsTheBreakOnceAndStartsNextFocus() async {
        let (coordinator, detector, locker, log) = makeCoordinator(
            preferences: AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: true))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { coordinator.pomodoroSession?.phase == .focus(round: 2) })
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.completed == 1)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func stopDuringAPostponeLeavesNoBreakBehind() async {
        let detector = MockDetector()
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: detector, locker: locker,
                                           deferralPollingInterval: 0.05)
        defer { coordinator.stop() }
        coordinator.start(with: [], preferences: AppPreferences(cameraDetection: .deferBreak, postponeReturnDelay: 0.1,
                                                                idleDetectionEnabled: false))
        coordinator.startPomodoro(oneMinute, level: .gentle, now: Date())
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.isShowing })
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.postponeActiveBreak()
        coordinator.stopPomodoro()
        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(300))
        #expect(coordinator.pomodoroSession == nil)
        #expect(locker.showCount == 1)
    }
}

private let oneMinuteFocusCover = PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 120, rounds: 2, cover: .focus)

@Suite("BreakCoordinator focus cover")
@MainActor
struct PomodoroFocusCoverTests {

    private func make(preferences: AppPreferences = AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false),
                      streak: Int = 3) -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
        let detector = MockDetector()
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: MockScheduler(), detector: detector, locker: locker,
                                           deferralPollingInterval: 0.05)
        let log = EventLog(coordinator)
        var stats = BreakStatistics()
        stats.currentStreak = streak
        coordinator.start(with: [], preferences: preferences, statistics: stats)
        return (coordinator, detector, locker, log)
    }

    private func onCover(_ configuration: PomodoroConfiguration = oneMinuteFocusCover)
        async -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
        let made = make()
        made.0.startPomodoro(configuration, level: .gentle)
        _ = await waitUntil { made.2.isShowing }
        return made
    }

    /// An open phase that ends at once: `now` sits a phase length back, so the bounded end
    /// lands just after the real clock and catch-up leaves it alone.
    private func restoreOpenPhaseEndingNow(_ coordinator: BreakCoordinator, _ phase: PomodoroPhase,
                                           configuration: PomodoroConfiguration = oneMinuteFocusCover) {
        let probe = PomodoroSession(startedAt: Date(), configuration: configuration, phase: phase, phaseEnd: Date())
        let now = Date().addingTimeInterval(0.05 - probe.duration(of: phase))
        let session = PomodoroSession(startedAt: now, configuration: configuration, phase: phase,
                                      phaseEnd: Date().addingTimeInterval(10))
        coordinator.restorePomodoro(session, level: .gentle, now: now)
    }

    @Test
    func startingAFocusCoverSessionOpensTheCover() async {
        let (coordinator, _, locker, _) = await onCover()
        defer { coordinator.stop() }
        #expect(locker.isShowing)
        #expect(locker.lastDuration == TimeInterval(60))
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 1, rounds: 2, isLong: false, isFocus: true))
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    @Test
    func strictFallsToFirmOnTheCover() async {
        let (coordinator, _, locker, log) = make()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinuteFocusCover, level: .strict)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .firm)
        #expect(await waitUntil { log.statuses.last??.level == .firm })
    }

    @Test
    func strictStaysStrictInBreaksMode() async {
        let (coordinator, _, _, log) = make()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinute, level: .strict)
        #expect(await waitUntil { log.statuses.last??.level == .strict })
    }

    @Test
    func coverTimeUpOpensTheBreakWithNoCount() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        try? await Task.sleep(for: .milliseconds(20))
        coordinator.completeActiveBreak()
        #expect(!locker.isShowing)
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect((log.stats?.pomodoroTallies?.focusSeconds ?? 0) > 0)
        #expect(log.completed == 0)
        #expect(log.skipped == 0)
        let breakEnd = coordinator.pomodoroSession?.phaseEnd
        #expect(await waitUntil { log.nextBreaks.last == breakEnd })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(locker.showCount == 1)
    }

    @Test
    func openBreakEndCountsOnceAndCoversTheNextFocus() async {
        let (coordinator, _, locker, log) = make()
        defer { coordinator.stop() }
        restoreOpenPhaseEndingNow(coordinator, .shortBreak(afterRound: 1))
        #expect(await waitUntil { locker.isShowing })
        #expect(log.completed == 1)
        #expect(log.stats?.currentStreak == 4)
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 2, rounds: 2, isLong: false, isFocus: true))
        try? await Task.sleep(for: .milliseconds(100))
        #expect(log.completed == 1)
        #expect(locker.showCount == 1)
    }

    @Test
    func skippingTheCoverIsNotASkip() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        coordinator.skipActiveBreak()
        #expect(!locker.isShowing)
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(log.skipped == 0)
        #expect(log.stats?.currentStreak == 3)
    }

    @Test
    func escapingTheCoverIsNotAnEscape() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        coordinator.escapeActiveBreak()
        #expect(!locker.isShowing)
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(log.stats?.breaksEscaped == 0)
        #expect(log.stats?.weeklyEscapeCount == 0)
        #expect(log.stats?.currentStreak == 3)
    }

    @Test
    func idleDoesNotCreditTheCover() async {
        let (coordinator, detector, locker, log) = make(preferences: AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: true))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(idleDuration: 3600)
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        #expect(await waitUntil { locker.isShowing })
        #expect(log.completed == 0)
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    @Test
    func skipPhaseDuringTheOpenBreakCountsASkipAndCovers() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        coordinator.completeActiveBreak()
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(log.skipped == 1)
        #expect(locker.lastPomodoroChip == PomodoroChip(round: 2, rounds: 2, isLong: false, isFocus: true))
    }

    @Test
    func waitingCoverSkipPhaseEndsFocusWithoutASkip() async {
        let (coordinator, detector, locker, log) = make(preferences: AppPreferences(cameraDetection: .deferBreak, postponeReturnDelay: 0.1,
                                                                                    idleDetectionEnabled: false))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        #expect(await waitUntil { log.events.contains { if case .breakDeferred = $0 { true } else { false } } })
        coordinator.skipPomodoroPhase()
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(log.skipped == 0)
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func lockDuringTheCoverReopensItWithItsTimeLeft() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        let lockedAt = Date()
        coordinator.handleScreenLock(now: lockedAt)
        #expect(!locker.isShowing)
        coordinator.handleScreenUnlock(now: lockedAt.addingTimeInterval(20))
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(abs((locker.lastDuration ?? 0) - 40) < 0.5)
        #expect(log.skipped == 0)
        #expect(log.completed == 0)
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
    }

    @Test
    func returnWithTheBreakOverWaitsAMinuteBeforeTheCover() async {
        let (coordinator, _, locker, _) = await onCover()
        defer { coordinator.stop() }
        coordinator.completeActiveBreak()
        coordinator.handleScreenLock()
        let back = Date().addingTimeInterval(120)
        coordinator.handleScreenUnlock(now: back)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!locker.isShowing)
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect((coordinator.pomodoroSession?.phaseEnd ?? .distantPast) >= back.addingTimeInterval(59))
    }

    @Test
    func restoredOpenBreakNearItsEndWaitsAMinute() async {
        let (coordinator, _, locker, _) = make()
        defer { coordinator.stop() }
        let config = PomodoroConfiguration(focus: 60, shortBreak: 300, longBreak: 300, rounds: 2, cover: .focus)
        let now = Date()
        coordinator.restorePomodoro(PomodoroSession(startedAt: now, configuration: config, phase: .shortBreak(afterRound: 1),
                                                    phaseEnd: now.addingTimeInterval(5)), level: .gentle, now: now)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        let end = coordinator.pomodoroSession?.phaseEnd ?? .distantPast
        #expect(end >= now.addingTimeInterval(59))
        #expect(end < now.addingTimeInterval(120))
    }

    @Test
    func restoredCoverKeepsItsWallClockEnd() async {
        let (coordinator, _, locker, _) = make()
        defer { coordinator.stop() }
        let config = PomodoroConfiguration(focus: 600, shortBreak: 60, longBreak: 120, rounds: 2, cover: .focus)
        let now = Date()
        coordinator.restorePomodoro(PomodoroSession(startedAt: now, configuration: config, phase: .focus(round: 1),
                                                    phaseEnd: now.addingTimeInterval(180)), level: .gentle, now: now)
        #expect(await waitUntil { locker.isShowing })
        #expect(abs((locker.lastDuration ?? 0) - 180) < 1)
    }

    @Test
    func screenSharingSkipAfterDeferralTalliesTheFocus() async {
        let (coordinator, detector, locker, log) = make(preferences: AppPreferences(
            screenSharingDetectionEnabled: true, screenSharingPostDeferral: .skipBreak,
            postponeReturnDelay: 0.1, idleDetectionEnabled: false))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        #expect(await waitUntil { log.events.contains { if case .breakDeferred = $0 { true } else { false } } })
        detector.contextToReturn = .clear
        #expect(await waitUntil { coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1) })
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(log.skipped == 0)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func aLockInTheTurnTheCoverIsArmedCancelsIt() async {
        let (coordinator, _, locker, _) = make()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        coordinator.handleScreenLock()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!locker.showOverlayCalled)
        coordinator.handleScreenUnlock()
        #expect(await waitUntil { locker.isShowing })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(locker.showCount == 1)
    }

    @Test
    func aWaitingCoverHandedToARebuildIsOwedInFull() async {
        // A cover deferred by a call has not run: a rebuild or relaunch after its first end
        // must still show it in full, not credit a focus that never happened.
        let (coordinator, detector, _, log) = make(preferences: AppPreferences(cameraDetection: .deferBreak, postponeReturnDelay: 0.1,
                                                                             idleDetectionEnabled: false))
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle, now: Date().addingTimeInterval(0.05 - 60))
        #expect(await waitUntil { log.events.contains { if case .breakDeferred = $0 { true } else { false } } })
        try? await Task.sleep(for: .milliseconds(100))
        let handed = coordinator.pomodoroSession
        coordinator.stop()

        let (rebuilt, _, locker, newLog) = make()
        defer { rebuilt.stop() }
        rebuilt.start(with: [], preferences: AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false),
                      pomodoro: handed.map { ($0, .gentle) })
        #expect(await waitUntil { locker.isShowing })
        #expect(abs((locker.lastDuration ?? 0) - 60) < 1)
        #expect(newLog.stats?.pomodoroTallies == nil)
    }

    @Test
    func coverThatRanOutAwayTalliesFocusAndCountsNoBreak() async {
        let (coordinator, _, locker, log) = await onCover()
        defer { coordinator.stop() }
        coordinator.handleScreenLock()
        let back = Date().addingTimeInterval(120)
        coordinator.handleScreenUnlock(now: back)
        #expect(await waitUntil { log.stats?.pomodoroTallies?.rounds == 1 })
        #expect(coordinator.pomodoroSession?.phase == .shortBreak(afterRound: 1))
        #expect(log.completed == 0)
        #expect(log.stats?.currentStreak == 3)
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!locker.isShowing)
    }

    @Test
    func restoredStrictCoverRunsAsFirm() async {
        let (coordinator, _, locker, _) = make()
        defer { coordinator.stop() }
        let now = Date()
        coordinator.restorePomodoro(PomodoroSession(startedAt: now, configuration: oneMinuteFocusCover,
                                                    phase: .focus(round: 1), phaseEnd: now.addingTimeInterval(30)),
                                    level: .strict, now: now)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .firm)
    }

    @Test
    func coverCuePlaysOnTimeUpOnlyNotOnSkip() async {
        let preferences = AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false, soundAfterBreak: true)
        let isEndCue: (CoordinatorEvent) -> Bool = { if case .breakCue(.ended) = $0 { true } else { false } }
        let (coordinator, _, locker, log) = make(preferences: preferences)
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        #expect(await waitUntil { locker.isShowing })
        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(!log.events.contains(where: isEndCue))
        coordinator.skipPomodoroPhase()
        #expect(await waitUntil { locker.showCount == 2 })
        coordinator.completeActiveBreak()
        #expect(await waitUntil { log.events.contains(where: isEndCue) })
    }

    @Test
    func lockDuringAWaitingCoverOwesItInFull() async {
        let (coordinator, detector, _, log) = make(preferences: AppPreferences(cameraDetection: .deferBreak, postponeReturnDelay: 0.1,
                                                                             idleDetectionEnabled: false))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startPomodoro(oneMinuteFocusCover, level: .gentle)
        #expect(await waitUntil { log.events.contains { if case .breakDeferred = $0 { true } else { false } } })
        let lockedAt = Date().addingTimeInterval(90)
        coordinator.handleScreenLock(now: lockedAt)
        coordinator.handleScreenUnlock(now: lockedAt.addingTimeInterval(5))
        #expect(coordinator.pomodoroSession?.phase == .focus(round: 1))
        try? await Task.sleep(for: .milliseconds(100))
        #expect(log.stats?.pomodoroTallies == nil)
    }

    @Test
    func postponedCoverReturnsAsAFullFocusCover() async {
        let (coordinator, _, locker, _) = await onCover()
        defer { coordinator.stop() }
        coordinator.postponeActiveBreak()
        #expect(!locker.isShowing)
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(locker.lastPomodoroChip?.isFocus == true)
        #expect(abs((locker.lastDuration ?? 0) - 60) < 1)
        #expect(locker.lastCanPostpone == false)
    }

    @Test
    func lastBreakEndsTheSessionInCoverMode() async {
        let single = PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 60, rounds: 1, cover: .focus)
        let (coordinator, _, _, _) = await onCover(single)
        coordinator.completeActiveBreak()
        #expect(coordinator.pomodoroSession?.phase == .longBreak)
        coordinator.stop()

        let (restored, _, locker, log) = make()
        defer { restored.stop() }
        restoreOpenPhaseEndingNow(restored, .longBreak, configuration: single)
        #expect(await waitUntil { log.stats?.pomodoroTallies?.sessionsFinished == 1 && log.statuses.last == .some(nil) })
        #expect(restored.pomodoroSession == nil)
        #expect(log.completed == 1)
        #expect(!locker.showOverlayCalled)
    }
}

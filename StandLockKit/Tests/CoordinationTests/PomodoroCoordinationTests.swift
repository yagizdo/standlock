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
        #expect(await waitUntil { log.completed == 1 })
        #expect(coordinator.pomodoroSession == nil)
        #expect(log.statuses.last == .some(nil))
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

        // Break still running when the app went away: what is left of it opens.
        let (midBreak, midLocker, _) = await restored(.shortBreak(afterRound: 2), end: now.addingTimeInterval(25))
        #expect(await waitUntil { midLocker.isShowing })
        #expect(abs((midLocker.lastDuration ?? 0) - 25) < 1)
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

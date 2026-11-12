import Testing
import Foundation
@testable import Coordination
@testable import StandLockCore

/// What the coordinator reports to the break-on-screen marker, in order.
@MainActor
private final class MarkerLog {
    private(set) var calls: [Date?] = []
    func record(_ date: Date?) { calls.append(date) }
    var isSet: Bool { calls.last.map { $0 != nil } ?? false }
}

@MainActor
private func makeGuarded(
    schedules: [Schedule] = [],
    preferences: AppPreferences = AppPreferences(postponeReturnDelay: 0, idleDetectionEnabled: false),
    scheduler: MockScheduler = MockScheduler(),
    detector: MockDetector = MockDetector(),
    state: EnforcementState = EnforcementState(),
    launchGuard: LaunchGuard? = nil
) -> (BreakCoordinator, MockLocker, MarkerLog) {
    let locker = MockLocker()
    let coordinator = BreakCoordinator(
        scheduler: scheduler, detector: detector, locker: locker, deferralPollingInterval: 0.02
    )
    let marker = MarkerLog()
    coordinator.onBreakOnScreenChanged = { marker.record($0) }
    coordinator.start(with: schedules, preferences: preferences, restoring: state, launchGuard: launchGuard)
    return (coordinator, locker, marker)
}

@MainActor
private func dueNow() -> MockScheduler {
    let scheduler = MockScheduler()
    scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.01)
    return scheduler
}

private let oneMinuteBreaks = PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 120, rounds: 2)
private let oneMinuteCover = PomodoroConfiguration(focus: 60, shortBreak: 60, longBreak: 120, rounds: 2, cover: .focus)

// MARK: - Marker

@Suite("Break-on-screen marker")
@MainActor
struct BreakOnScreenMarkerTests {

    /// Every way a break leaves the screen while the process lives must clear the marker, or
    /// every normal launch would look like an unclean exit.
    @Test(arguments: ["complete", "skip", "escape", "lock", "sleep", "stop"])
    func markerIsSetOnScreenAndClearedByEachEnd(end: String) async {
        let (coordinator, locker, marker) = makeGuarded(schedules: [makeSchedule()], scheduler: dueNow())
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        #expect(marker.calls.count == 1)
        #expect(marker.isSet)

        switch end {
        case "complete": coordinator.completeActiveBreak()
        case "skip": coordinator.skipActiveBreak()
        case "escape": coordinator.escapeActiveBreak()
        case "lock": coordinator.handleScreenLock()
        case "sleep": coordinator.handleSystemSleep()
        default: coordinator.stop()
        }
        #expect(marker.calls.count == 2)
        #expect(!marker.isSet)
    }

    @Test
    func postponeClearsAndTheReturnSetsAgain() async {
        let (coordinator, locker, marker) = makeGuarded(schedules: [makeSchedule()], scheduler: dueNow())
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        #expect(!marker.isSet)
        locker.showOverlayCalled = false
        #expect(await waitUntil { locker.showOverlayCalled })
        #expect(marker.calls.count == 3)
        #expect(marker.isSet)
    }

    @Test
    func idleCreditAndDeferralNeverSetIt() async {
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(idleDuration: 3600)
        let (idle, idleLocker, idleMarker) = makeGuarded(
            schedules: [makeSchedule()],
            preferences: AppPreferences(idleDetectionEnabled: true), scheduler: dueNow(), detector: detector
        )
        defer { idle.stop() }
        let camera = MockDetector()
        camera.contextToReturn = DetectionContext(cameraActive: true)
        let (deferring, deferLocker, deferMarker) = makeGuarded(
            schedules: [makeSchedule()],
            preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false),
            scheduler: dueNow(), detector: camera
        )
        defer { deferring.stop() }
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!idleLocker.showOverlayCalled && !deferLocker.showOverlayCalled)
        #expect(idleMarker.calls.isEmpty)
        #expect(deferMarker.calls.isEmpty)
    }

    @Test(arguments: [PomodoroCover.breaks, .focus])
    func sessionCoveredPhaseSetsAndClears(cover: PomodoroCover) async {
        let (coordinator, locker, marker) = makeGuarded()
        defer { coordinator.stop() }
        let configuration = cover == .breaks ? oneMinuteBreaks : oneMinuteCover
        // Dated one focus ago: in break mode the focus ends at once; a cover opens at start.
        coordinator.startPomodoro(configuration, level: .gentle, now: Date().addingTimeInterval(0.05 - 60))
        #expect(await waitUntil { locker.isShowing })
        #expect(marker.isSet)
        if cover == .breaks { coordinator.completeActiveBreak() } else { coordinator.skipActiveBreak() }
        #expect(!marker.isSet)
    }

    /// A session break taken down by a lock emits no event, which is why the marker does not
    /// follow events.
    @Test
    func sessionBreakTakenDownByLockClears() async {
        let (coordinator, locker, marker) = makeGuarded()
        defer { coordinator.stop() }
        coordinator.startPomodoro(oneMinuteBreaks, level: .gentle, now: Date().addingTimeInterval(0.05 - 60))
        #expect(await waitUntil { locker.isShowing })
        coordinator.handleScreenLock()
        #expect(marker.calls.count == 2)
        #expect(!marker.isSet)
    }
}

// MARK: - Guard

@Suite("Launch guard after an unclean exit")
@MainActor
struct LaunchGuardCoordinationTests {

    private func guardIn(_ seconds: TimeInterval) -> LaunchGuard {
        LaunchGuard(notBefore: Date().addingTimeInterval(seconds), level: .gentle)
    }

    /// The slot that was due, a carried one included, waits for the grace; the break then opens
    /// at Gentle from the base tier, so no bug in the Strict path can hold the user twice.
    @Test
    func launchGuardDelaysAndSoftensTheFirstBreak() async {
        let schedule = makeSchedule(level: .strict, progressiveEnforcement: true)
        let state = EnforcementState(escalationTiers: [schedule.id: 2],
                                     pendingBreakDates: [schedule.id: Date().addingTimeInterval(0.01)])
        let (coordinator, locker, _) = makeGuarded(schedules: [schedule], scheduler: dueNow(),
                                                   state: state, launchGuard: guardIn(1))
        defer { coordinator.stop() }
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        #expect(coordinator.launchGuard != nil)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .gentle)
        #expect(locker.lastEscalationTier == 0)
        #expect(coordinator.launchGuard == nil)
    }

    /// The day's skips may be used up when the app died: the guarded break still has its Skip,
    /// and the break after it has the limit back.
    @Test
    func guardedBreakIgnoresTheDailySkipLimit() async {
        let scheduler = dueNow()
        let preferences = AppPreferences(gentleDailySkipLimit: 0, postponeReturnDelay: 0, idleDetectionEnabled: false)
        let (coordinator, locker, _) = makeGuarded(schedules: [makeSchedule(level: .gentle)], preferences: preferences,
                                                   scheduler: scheduler, launchGuard: guardIn(0.05))
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        let guarded = try? #require(locker.lastPreferences)
        #expect(guarded.map { DisciplineLevel.gentle.dailySkipLimitReached(preferences: $0, skipsToday: 1_000, isFocusCover: false) } == false)

        locker.showOverlayCalled = false
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.01)
        coordinator.completeActiveBreak()
        #expect(await waitUntil { locker.showOverlayCalled })
        #expect(locker.lastPreferences?.gentleDailySkipLimit == 0)
    }

    @Test
    func launchGuardIsUsedOnce() async {
        let scheduler = dueNow()
        let (coordinator, locker, _) = makeGuarded(schedules: [makeSchedule(level: .strict)], scheduler: scheduler,
                                                   launchGuard: guardIn(0.05))
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        locker.showOverlayCalled = false
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.01)
        coordinator.completeActiveBreak()
        #expect(await waitUntil { locker.showOverlayCalled })
        #expect(locker.lastLevel == .strict)
    }

    @Test
    func noGuardKeepsTheSlotAndLevel() async {
        let (coordinator, locker, _) = makeGuarded(schedules: [makeSchedule(level: .strict)], scheduler: dueNow())
        defer { coordinator.stop() }
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .strict)
    }

    @Test
    func launchGuardSurvivesALockBeforeTheBreak() async {
        let launchGuard = guardIn(1)
        let (coordinator, locker, _) = makeGuarded(schedules: [makeSchedule(level: .strict)], scheduler: dueNow(),
                                                   launchGuard: launchGuard)
        defer { coordinator.stop() }
        coordinator.handleScreenLock()
        coordinator.handleScreenUnlock()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        #expect(await waitUntil { locker.isShowing })
        #expect((locker.lastShownAt ?? .distantPast) >= launchGuard.notBefore)
    }

    /// A postponed break carried in the saved state comes back through the postpone wait, which
    /// never passes `scheduleNextBreak`.
    @Test
    func launchGuardDelaysARestoredPostponedBreak() async {
        let schedule = makeSchedule(level: .strict)
        let launchGuard = guardIn(1)
        let (coordinator, locker, _) = makeGuarded(schedules: [schedule], state: EnforcementState(postponedScheduleID: schedule.id),
                                                   launchGuard: launchGuard)
        defer { coordinator.stop() }
        let log = EventLog(coordinator)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        // The menu bar counts down to the guarded return, not to the postpone delay.
        #expect((log.nextBreaks.last ?? .distantPast) >= launchGuard.notBefore)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .gentle)
    }

    /// Restored after an unclean exit, a session's covered phase waits too: in break mode a break,
    /// in cover mode a cover with time left. Before the guard it opened at launch.
    @Test(arguments: [PomodoroCover.breaks, .focus])
    func restoredCoveredPhaseWaitsForTheGrace(cover: PomodoroCover) async {
        let launchGuard = guardIn(1)
        let (coordinator, locker, _) = makeGuarded(launchGuard: launchGuard)
        defer { coordinator.stop() }
        let now = Date()
        let session = cover == .breaks
            ? PomodoroSession(startedAt: now, configuration: oneMinuteBreaks, phase: .shortBreak(afterRound: 1),
                              phaseEnd: now.addingTimeInterval(30))
            : PomodoroSession(startedAt: now, configuration: oneMinuteCover, phase: .focus(round: 1),
                              phaseEnd: now.addingTimeInterval(30))
        coordinator.restorePomodoro(session, level: .firm, now: now)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        #expect(coordinator.pomodoroSession != nil)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastLevel == .gentle)
        #expect((locker.lastShownAt ?? .distantPast) >= launchGuard.notBefore)
    }
}

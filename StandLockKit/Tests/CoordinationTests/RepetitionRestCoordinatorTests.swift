import Foundation
import Testing
@testable import Coordination
import Scheduling
import StandLockCore

@Suite("Repetition after observed rest")
@MainActor
struct RepetitionRestCoordinatorTests {
    private func schedule(longDuration: TimeInterval = 1200) -> Schedule {
        makeSchedule(breakInterval: 100, repetitionRule: RepetitionRule(
            shortBreakCount: 3, shortBreakDuration: 300, longBreakDuration: longDuration))
    }

    private func start(_ time: ManualCoordinatorClock, _ locker: MockLocker, schedules: [Schedule],
                       preferences: AppPreferences = AppPreferences(),
                       state: EnforcementState = EnforcementState()) -> BreakCoordinator {
        let coordinator = BreakCoordinator(scheduler: ScheduleEvaluator(), detector: MockDetector(),
            locker: locker, clock: time.clock)
        coordinator.start(with: schedules, preferences: preferences, restoring: state)
        return coordinator
    }

    @Test(arguments: [1199.0, 1200.0, 1800.0])
    func lockedRestUsesActualDurationWhileAShortBreakIsDue(duration: TimeInterval) async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        coordinator.handleScreenLock()
        time.advance(duration)
        coordinator.handleScreenUnlock()
        let expectedIndex = duration >= 1200 ? 0 : 3
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == expectedIndex)
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == (duration >= 1200 ? 300 : 1200))
        coordinator.stop()
    }

    @Test func shorterQualifyingRestDoesNotSatisfyADueLongBreak() {
        let time = ManualCoordinatorClock()
        let schedule = schedule()
        let coordinator = start(time, MockLocker(), schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 3]))
        coordinator.handleScreenLock()
        time.advance(300)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 3)
        coordinator.stop()
    }

    @Test func activeBreakAndFollowingLockAreOneContinuousRest() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        coordinator.handleScreenLock()
        time.advance(1020)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        #expect(coordinator.captureEnforcementState().dailyBreakCounts[schedule.id] == 1)
        coordinator.stop()
    }

    @Test func rebuildRetainsRestBeforeLocking() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let first = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        first.handleScreenLock()
        let state = first.captureEnforcementState()
        first.stop()
        let rebuilt = start(time, locker, schedules: [schedule], state: state)
        time.advance(1020)
        rebuilt.handleScreenUnlock()
        #expect(rebuilt.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        rebuilt.stop()
    }

    @Test func differentThresholdsResetWithoutAnEligibleCompletion() async {
        let time = ManualCoordinatorClock()
        var disabled = schedule(longDuration: 600)
        disabled.isEnabled = false
        var outsideHours = schedule(longDuration: 1200)
        outsideHours.windows = [TimeWindow(startHour: 20, startMinute: 0, endHour: 21, endMinute: 0)]
        let coordinator = start(time, MockLocker(), schedules: [disabled, outsideHours],
            preferences: AppPreferences(naturalBreakThresholdMinutes: 30),
            state: EnforcementState(repetitionIndices: [disabled.id: 2, outsideHours.id: 2]))
        var completions = 0
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted = event { completions += 1 }
            }
        }
        coordinator.handleScreenLock()
        time.advance(600)
        coordinator.handleScreenUnlock()
        var state = coordinator.captureEnforcementState()
        #expect(state.repetitionIndices[disabled.id] == 0)
        #expect(state.repetitionIndices[outsideHours.id] == 2)
        coordinator.handleScreenLock()
        time.advance(1200)
        coordinator.handleScreenUnlock()
        state = coordinator.captureEnforcementState()
        #expect(state.repetitionIndices[outsideHours.id] == 0)
        #expect(state.dailyBreakCounts.isEmpty)
        for _ in 0..<20 { await Task.yield() }
        #expect(completions == 0)
        coordinator.stop()
        listener.cancel()
    }

    @Test func shorterAbsencesSeparatedByWorkDoNotCombine() {
        let time = ManualCoordinatorClock()
        let schedule = schedule()
        let coordinator = start(time, MockLocker(), schedules: [schedule])
        coordinator.handleScreenLock()
        time.advance(600)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 1)
        time.advance(60)
        coordinator.handleScreenLock()
        time.advance(600)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        coordinator.stop()
    }

    @Test func overlappingSleepAndLockResetOnlyOnFinalReturn() {
        let time = ManualCoordinatorClock()
        let schedule = schedule()
        let coordinator = start(time, MockLocker(), schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        coordinator.handleScreenLock()
        coordinator.handleSystemSleep()
        time.advance(600)
        coordinator.handleSystemWake()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        time.advance(600)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        coordinator.stop()
    }

    @Test func dailyResetAndRelaunchRetainTheCompletedShortCount() throws {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        var state = EnforcementState(repetitionIndices: [schedule.id: 2])
        state.resetDailyCounters()
        let decoded = try JSONDecoder().decode(EnforcementState.self, from: JSONEncoder().encode(state))
        let coordinator = start(time, locker, schedules: [schedule], state: decoded)
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        coordinator.stop()
    }

    @Test func skippingEscapingAndPostponingLeaveTheShortCountUnchanged() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        coordinator.skipNextBreak(expectedSlotID: coordinator.pendingSlotID)
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        for action in ["skip", "escape", "postpone"] {
            let next = coordinator.captureEnforcementState().pendingBreakDates[schedule.id]!
            time.advance(next.timeIntervalSince(time.clock.now()))
            #expect(await waitUntil { locker.isShowing })
            switch action {
            case "skip": coordinator.skipActiveBreak(expectedBreakID: locker.lastBreakID)
            case "escape": coordinator.escapeActiveBreak(expectedBreakID: locker.lastBreakID)
            default: coordinator.postponeActiveBreak(expectedBreakID: locker.lastBreakID)
            }
            #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        }
        coordinator.stop()
    }

    @Test func postponingInterruptsContinuousRest() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        coordinator.postponeActiveBreak()
        coordinator.handleScreenLock()
        time.advance(1020)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 3)
        coordinator.stop()
    }

    @Test func aShortRestCreditsOnlyTheOwnedSchedule() {
        let time = ManualCoordinatorClock()
        let a = schedule()
        let b = schedule()
        let coordinator = start(time, MockLocker(), schedules: [a, b],
            state: EnforcementState(repetitionIndices: [a.id: 1, b.id: 1]))
        coordinator.handleScreenLock()
        time.advance(300)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[a.id] == 2)
        #expect(coordinator.captureEnforcementState().repetitionIndices[b.id] == 1)
        coordinator.stop()
    }

    @Test func liveDailyRolloverKeepsRepetitionProgress() {
        let time = ManualCoordinatorClock()
        let schedule = schedule()
        let coordinator = start(time, MockLocker(), schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(86_400)
        coordinator.refreshDailyRollover()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 2)
        coordinator.stop()
    }

    @Test func aCompletedOnscreenLongRestAlsoResetsOtherSchedules() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let a = schedule()
        var disabled = schedule()
        disabled.isEnabled = false
        let coordinator = start(time, locker, schedules: [a, disabled],
            state: EnforcementState(repetitionIndices: [a.id: 3, disabled.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(1200)
        #expect(await waitUntil { !locker.isShowing })
        #expect(coordinator.captureEnforcementState().repetitionIndices[a.id] == 0)
        #expect(coordinator.captureEnforcementState().repetitionIndices[disabled.id] == 0)
        coordinator.stop()
    }

    @Test func workDuringPauseCannotBecomeObservedLongRest() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule()
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        coordinator.pause(for: 1800)
        coordinator.handleScreenLock()
        time.advance(60)
        coordinator.handleScreenUnlock()
        #expect(!locker.isShowing)
        time.advance(960)
        coordinator.resume()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 3)
        coordinator.stop()
    }

    @Test func aLongRestBeforePausedWorkIsNotCountedAgainAsAShortBreak() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule(longDuration: 200)
        let coordinator = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        coordinator.pause(for: 1800)
        coordinator.handleScreenLock()
        time.advance(60)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        time.advance(960)
        coordinator.resume()
        #expect(coordinator.captureEnforcementState().repetitionIndices[schedule.id] == 0)
        coordinator.stop()
    }

    @Test func interruptedOnscreenRestUsesItsLongestSegmentAcrossRebuild() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = schedule(longDuration: 280)
        let first = start(time, locker, schedules: [schedule],
            state: EnforcementState(repetitionIndices: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        time.advance(180)
        first.pause(for: 1800)
        first.handleScreenLock()
        time.advance(60)
        first.handleScreenUnlock()
        let state = first.captureEnforcementState()
        first.stop()
        let rebuilt = start(time, locker, schedules: [schedule], state: state)
        time.advance(10)
        rebuilt.resume()
        #expect(locker.isShowing)
        time.advance(50)
        #expect(await waitUntil { !locker.isShowing })
        #expect(rebuilt.captureEnforcementState().repetitionIndices[schedule.id] == 3)
        rebuilt.stop()
    }
}

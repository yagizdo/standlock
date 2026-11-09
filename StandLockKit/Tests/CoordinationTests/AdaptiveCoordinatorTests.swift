import Foundation
import Testing
@testable import Coordination
import StandLockCore
import Scheduling

@Suite("Adaptive coordinator")
@MainActor
struct AdaptiveCoordinatorTests {
    private func make(_ time: ManualCoordinatorClock, _ locker: MockLocker, schedules: [Schedule],
                      state: EnforcementState = EnforcementState()) -> BreakCoordinator {
        let result = BreakCoordinator(scheduler: ScheduleEvaluator(), detector: MockDetector(),
                                      locker: locker, clock: time.clock)
        result.start(with: schedules, preferences: AppPreferences(), restoring: state)
        return result
    }

    @Test func shortAbsencePreservesEveryRemainingDeadline() {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let a = makeSchedule(breakInterval: 2700)
        let b = makeSchedule(breakInterval: 3600)
        let coordinator = make(time, locker, schedules: [a, b])
        time.advance(1200)
        coordinator.handleScreenLock()
        time.advance(30)
        coordinator.handleScreenUnlock()
        let slots = coordinator.captureEnforcementState().pendingBreakDates
        #expect(slots[a.id] == time.clock.now().addingTimeInterval(1500))
        #expect(slots[b.id] == time.clock.now().addingTimeInterval(2400))
        coordinator.stop()
    }

    @Test(arguments: [299.0, 300.0, 600.0])
    func exactThresholdDeterminesReset(duration: TimeInterval) {
        let time = ManualCoordinatorClock()
        let schedule = makeSchedule(breakInterval: 2700, progressiveEnforcement: true)
        let disabledID = UUID()
        let initial = EnforcementState(escalationTiers: [schedule.id: 2, disabledID: 2],
            consecutiveDismissalCounts: [schedule.id: 2, disabledID: 2])
        let coordinator = make(time, MockLocker(), schedules: [schedule], state: initial)
        time.advance(1200)
        coordinator.handleScreenLock()
        time.advance(duration)
        coordinator.handleScreenUnlock()
        let state = coordinator.captureEnforcementState()
        #expect(state.pendingBreakDates[schedule.id] == time.clock.now().addingTimeInterval(duration >= 300 ? 2700 : 1500))
        #expect(state.consecutiveDismissalCounts[disabledID] == (duration >= 300 ? nil : 2))
        #expect(state.dailyBreakCounts[schedule.id, default: 0] == (duration >= 300 ? 1 : 0))
        coordinator.stop()
    }

    @Test func wakeDoesNotResumeBeforeUnlock() {
        let time = ManualCoordinatorClock()
        let schedule = makeSchedule(breakInterval: 2700)
        let coordinator = make(time, MockLocker(), schedules: [schedule])
        coordinator.handleScreenLock()
        coordinator.handleSystemSleep()
        time.advance(600)
        coordinator.handleSystemWake()
        #expect(!coordinator.canSkipNextBreak)
        coordinator.handleScreenUnlock()
        #expect(coordinator.canSkipNextBreak)
        let slots = coordinator.captureEnforcementState().pendingBreakDates
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().pendingBreakDates == slots)
        coordinator.stop()
    }

    @Test func activeBreakResumesSameIdentityAndCompletesWhileLocked() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = makeSchedule(breakInterval: 100, breakDuration: 60)
        let coordinator = make(time, locker, schedules: [schedule])
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        let id = locker.lastBreakID
        coordinator.handleScreenLock()
        time.advance(30)
        coordinator.handleScreenUnlock()
        #expect(locker.lastBreakID == id)
        #expect(locker.lastDuration == 30)
        #expect(coordinator.captureEnforcementState().cycleIndices[schedule.id] == 1)
        coordinator.handleScreenLock()
        time.advance(30)
        coordinator.handleScreenUnlock()
        #expect(!locker.isShowing)
        #expect(coordinator.captureEnforcementState().pendingBreakDates[schedule.id] == time.clock.now().addingTimeInterval(100))
        coordinator.stop()
    }

    @Test func postponedBreakIsSatisfiedOnceByNaturalRest() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let schedule = makeSchedule(breakInterval: 100)
        let coordinator = make(time, locker, schedules: [schedule])
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        coordinator.handleScreenLock()
        time.advance(300)
        coordinator.handleScreenUnlock()
        let state = coordinator.captureEnforcementState()
        #expect(state.postponedScheduleID == nil)
        #expect(state.dailyBreakCounts[schedule.id] == 1)
        #expect(state.cycleIndices[schedule.id] == 1)
        #expect(!locker.isShowing)
        coordinator.stop()
    }

    @Test func manualPauseSurvivesAnAbsence() async {
        let time = ManualCoordinatorClock()
        let schedule = makeSchedule(breakInterval: 100)
        let coordinator = make(time, MockLocker(), schedules: [schedule])
        coordinator.pause(for: 600)
        coordinator.handleScreenLock()
        time.advance(300)
        coordinator.handleScreenUnlock()
        #expect(!coordinator.canSkipNextBreak)
        time.advance(300)
        #expect(await waitUntil { coordinator.canSkipNextBreak })
        coordinator.stop()
    }

    @Test func suspendedRuntimeSurvivesCoordinatorRebuild() {
        let time = ManualCoordinatorClock()
        let schedule = makeSchedule(breakInterval: 2700)
        let first = make(time, MockLocker(), schedules: [schedule])
        time.advance(1200)
        first.handleScreenLock()
        let state = first.captureEnforcementState()
        first.stop()
        let rebuilt = make(time, MockLocker(), schedules: [schedule], state: state)
        time.advance(30)
        rebuilt.handleScreenUnlock()
        #expect(rebuilt.captureEnforcementState().pendingBreakDates[schedule.id] == time.clock.now().addingTimeInterval(1500))
        rebuilt.stop()
    }

    @Test(arguments: DisciplineLevel.allCases)
    func mixedDismissalsHitCapAndCompletionRestoresIt(level: DisciplineLevel) async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(level: level, breakInterval: 100, breakDuration: 600, progressiveEnforcement: true)
        schedule.consecutiveSkipLimit = 2
        let coordinator = make(time, locker, schedules: [schedule])
        coordinator.skipNextBreak(expectedSlotID: coordinator.pendingSlotID)
        let next = coordinator.captureEnforcementState().pendingBreakDates[schedule.id]!
        time.advance(next.timeIntervalSince(time.clock.now()))
        #expect(await waitUntil { locker.isShowing })
        let oldID = locker.lastBreakID
        coordinator.escapeActiveBreak(expectedBreakID: oldID)
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        let state = coordinator.captureEnforcementState()
        #expect(!locker.lastAvailability.emergencyEscapeAllowed)
        coordinator.skipActiveBreak(expectedBreakID: locker.lastBreakID)
        coordinator.escapeActiveBreak(expectedBreakID: locker.lastBreakID)
        #expect(locker.isShowing)
        #expect(coordinator.captureEnforcementState().consecutiveDismissalCounts == state.consecutiveDismissalCounts)
        coordinator.completeActiveBreak(expectedBreakID: oldID)
        #expect(locker.isShowing)
        coordinator.completeActiveBreak(expectedBreakID: locker.lastBreakID)
        #expect(coordinator.captureEnforcementState().consecutiveDismissalCounts[schedule.id] == 0)
        #expect(coordinator.canSkipNextBreak)
        coordinator.stop()
    }

    @Test func staleMenuSlotCannotSpendAllowance() {
        let time = ManualCoordinatorClock()
        var schedule = makeSchedule(breakInterval: 100, progressiveEnforcement: true)
        schedule.consecutiveSkipLimit = 2
        let coordinator = make(time, MockLocker(), schedules: [schedule])
        let old = coordinator.pendingSlotID
        coordinator.skipNextBreak(expectedSlotID: old)
        coordinator.skipNextBreak(expectedSlotID: old)
        #expect(coordinator.captureEnforcementState().consecutiveDismissalCounts[schedule.id] == 1)
        coordinator.stop()
    }

    @Test func lifetimeCountSurvivesMidnightAndJSON() throws {
        let id = UUID()
        var state = EnforcementState(dailyBreakCounts: [id: 3], escalationTiers: [id: 2],
                                     consecutiveDismissalCounts: [id: 2])
        state.resetDailyCounters()
        let decoded = try JSONDecoder().decode(EnforcementState.self, from: JSONEncoder().encode(state))
        #expect(decoded.consecutiveDismissalCounts[id] == 2)
        #expect(decoded.dailyBreakCounts.isEmpty)
        #expect(try JSONDecoder().decode(EnforcementState.self, from: Data("{}".utf8)).consecutiveDismissalCounts.isEmpty)
    }

    @Test func deletingAnActiveScheduleDoesNotStrandOtherSchedules() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let a = makeSchedule(breakInterval: 100, breakDuration: 600)
        let b = makeSchedule(breakInterval: 200)
        let first = make(time, locker, schedules: [a, b])
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        let state = first.captureEnforcementState()
        first.stop()
        let next = make(time, locker, schedules: [b], state: state)
        #expect(next.captureEnforcementState().pendingBreakDates[b.id] != nil)
        #expect(next.canSkipNextBreak)
        next.stop()
    }

    @Test func liveCapChangesDoNotRecreateTheOverlay() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(breakInterval: 100, breakDuration: 600, progressiveEnforcement: true)
        let state = EnforcementState(consecutiveDismissalCounts: [schedule.id: 2])
        let coordinator = make(time, locker, schedules: [schedule], state: state)
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        let id = locker.lastBreakID
        locker.showOverlayCalled = false
        schedule.consecutiveSkipLimit = 2
        coordinator.updateEnforcementSettings(for: schedule)
        #expect(!locker.lastAvailability.emergencyEscapeAllowed)
        #expect(!locker.showOverlayCalled)
        #expect(locker.lastBreakID == id)
        schedule.consecutiveSkipLimit = 3
        coordinator.updateEnforcementSettings(for: schedule)
        #expect(locker.lastAvailability.emergencyEscapeAllowed)
        coordinator.stop()
    }

    @Test func capChangedWhileWorkIsPendingAppliesToTheNextBreak() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(breakInterval: 100, breakDuration: 600, progressiveEnforcement: true)
        let coordinator = make(time, locker, schedules: [schedule],
            state: EnforcementState(consecutiveDismissalCounts: [schedule.id: 2]))
        schedule.consecutiveSkipLimit = 2
        coordinator.updateEnforcementSettings(for: schedule)
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        #expect(!locker.lastAvailability.emergencyEscapeAllowed)
        coordinator.escapeActiveBreak(expectedBreakID: locker.lastBreakID)
        #expect(locker.isShowing)
        coordinator.stop()
    }

    @Test func capChangedDuringPostponeAppliesOnReturn() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(breakInterval: 100, breakDuration: 600, progressiveEnforcement: true)
        let coordinator = make(time, locker, schedules: [schedule],
            state: EnforcementState(consecutiveDismissalCounts: [schedule.id: 2]))
        time.advance(100)
        #expect(await waitUntil { locker.isShowing })
        var returnArmed = false
        let listener = Task {
            for await event in coordinator.events {
                if case .nextBreakScheduled(let date) = event, date > time.clock.now() { returnArmed = true }
            }
        }
        coordinator.postponeActiveBreak()
        schedule.consecutiveSkipLimit = 2
        coordinator.updateEnforcementSettings(for: schedule)
        for _ in 0..<20 { await Task.yield() }
        time.advance(10)
        #expect(await waitUntil { returnArmed })
        time.advance(120)
        #expect(await waitUntil { locker.isShowing })
        #expect(!locker.lastAvailability.emergencyEscapeAllowed)
        coordinator.stop()
        listener.cancel()
    }

    @Test func disabledPostponedBreakCannotBecomeAnotherSchedulesBreak() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let a = makeSchedule(breakInterval: 30, breakDuration: 60)
        let b = makeSchedule(breakInterval: 200, breakDuration: 120)
        let first = make(time, locker, schedules: [a, b])
        time.advance(30)
        #expect(await waitUntil { locker.isShowing })
        let id = locker.lastBreakID
        first.postponeActiveBreak()
        let state = first.captureEnforcementState()
        first.stop()
        let next = make(time, locker, schedules: [b], state: state)
        time.advance(200)
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastBreakID != id)
        #expect(locker.lastDuration == 120)
        next.stop()
    }

    @Test func completedBreakIsCreditedAfterItsWindowEnds() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(breakInterval: 30, breakDuration: 60, progressiveEnforcement: true)
        schedule.windows = [TimeWindow(startHour: 10, startMinute: 0, endHour: 10, endMinute: 2)]
        let coordinator = make(time, locker, schedules: [schedule],
            state: EnforcementState(consecutiveDismissalCounts: [schedule.id: 2]))
        time.advance(30)
        #expect(await waitUntil { locker.isShowing })
        coordinator.handleScreenLock()
        time.advance(90)
        coordinator.handleScreenUnlock()
        #expect(coordinator.captureEnforcementState().consecutiveDismissalCounts[schedule.id] == 0)
        #expect(!locker.isShowing)
        coordinator.stop()
    }

    @Test func postponedBreakDoesNotAppearOutsideItsWindow() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(breakInterval: 30, breakDuration: 60)
        schedule.windows = [TimeWindow(startHour: 10, startMinute: 0, endHour: 10, endMinute: 2)]
        let coordinator = make(time, locker, schedules: [schedule])
        time.advance(30)
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        coordinator.handleScreenLock()
        time.advance(90)
        coordinator.handleScreenUnlock()
        for _ in 0..<20 { await Task.yield() }
        time.advance(10)
        for _ in 0..<20 { await Task.yield() }
        time.advance(120)
        for _ in 0..<20 { await Task.yield() }
        #expect(!locker.isShowing)
        #expect(coordinator.captureEnforcementState().postponedScheduleID == schedule.id)
        coordinator.stop()
    }

    @Test func overnightRestClearsDisabledStreaksWithoutInventingACompletion() async {
        let time = ManualCoordinatorClock()
        let schedule = makeSchedule(breakInterval: 2700, dailyBreakCap: 1)
        var disabled = makeSchedule()
        disabled.isEnabled = false
        let state = EnforcementState(dailyBreakCounts: [schedule.id: 1],
            consecutiveDismissalCounts: [schedule.id: 2, disabled.id: 2])
        let coordinator = make(time, MockLocker(), schedules: [schedule, disabled], state: state)
        var completed = false
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted = event { completed = true }
            }
        }
        coordinator.handleScreenLock()
        time.advance(86_400)
        coordinator.handleScreenUnlock()
        for _ in 0..<20 { await Task.yield() }
        #expect(!completed)
        #expect(coordinator.captureEnforcementState().consecutiveDismissalCounts.isEmpty)
        #expect(coordinator.captureEnforcementState().dailyBreakCounts.isEmpty)
        #expect(coordinator.canSkipNextBreak)
        coordinator.stop()
        listener.cancel()
    }

    @Test func naturalRestCannotCreditADormantEventToAnotherOwner() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        let a = makeSchedule(breakInterval: 30, breakDuration: 60)
        let b = makeSchedule(breakInterval: 200, breakDuration: 120)
        let first = make(time, locker, schedules: [a, b])
        time.advance(30)
        #expect(await waitUntil { locker.isShowing })
        first.postponeActiveBreak()
        let state = first.captureEnforcementState()
        first.stop()
        let next = make(time, locker, schedules: [b], state: state)
        var completions: [BreakEvent] = []
        let listener = Task {
            for await event in next.events {
                if case .breakCompleted(let completed) = event { completions.append(completed) }
            }
        }
        next.handleScreenLock()
        time.advance(300)
        next.handleScreenUnlock()
        #expect(await waitUntil { completions.count == 1 })
        #expect(completions.first?.scheduleId == b.id)
        next.stop()
        listener.cancel()
    }

    @Test func permissionDowngradeAppliesToARestoredActiveBreak() async {
        let time = ManualCoordinatorClock()
        let locker = MockLocker()
        var schedule = makeSchedule(level: .strict, breakInterval: 30, breakDuration: 600)
        let first = make(time, locker, schedules: [schedule])
        time.advance(30)
        #expect(await waitUntil { locker.isShowing })
        let id = locker.lastBreakID
        let state = first.captureEnforcementState()
        first.stop()
        schedule.disciplineLevel = .firm
        let rebuilt = make(time, locker, schedules: [schedule], state: state)
        #expect(locker.lastBreakID == id)
        #expect(locker.lastLevel == .firm)
        rebuilt.stop()
    }
}

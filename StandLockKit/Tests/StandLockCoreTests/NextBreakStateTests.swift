import Foundation
import Testing
@testable import StandLockCore

@Suite("Next Break State Tests")
struct NextBreakStateTests {

    private let until = Date(timeIntervalSince1970: 1_000)
    private let next = Date(timeIntervalSince1970: 2_000)

    private func state(
        isBreakActive: Bool = false,
        isPaused: Bool = false,
        pausedUntil: Date? = nil,
        deferralReason: DeferralReason? = nil,
        nextBreakTime: Date? = nil,
        hasSchedules: Bool = true
    ) -> NextBreakState {
        NextBreakState(
            isBreakActive: isBreakActive,
            isPaused: isPaused,
            pausedUntil: pausedUntil,
            deferralReason: deferralReason,
            nextBreakTime: nextBreakTime,
            hasSchedules: hasSchedules
        )
    }

    @Test func aRunningBreakWinsOverEverything() {
        let result = state(
            isBreakActive: true, isPaused: true, pausedUntil: until,
            deferralReason: .calendarEvent, nextBreakTime: next
        )
        #expect(result == .breakActive)
    }

    @Test func aPauseWinsOverADeferralAndTheNextBreak() {
        let result = state(
            isPaused: true, pausedUntil: until, deferralReason: .cameraActive, nextBreakTime: next
        )
        #expect(result == .paused(until: until))
    }

    @Test func anEndTimeWithoutAPauseIsIgnored() {
        #expect(state(pausedUntil: until, nextBreakTime: next) == .countingDown(to: next))
    }

    // The coordinator always sets the two together. These record that the menu bar's chain has
    // no paused state of its own without a time.
    @Test func aPauseWithNoTimeFallsThroughToADeferral() {
        #expect(state(isPaused: true, deferralReason: .postponed) == .deferred(.postponed))
    }

    @Test func aPauseWithNoTimeFallsThroughToNoSchedules() {
        #expect(state(isPaused: true, hasSchedules: false) == .noSchedules)
    }

    @Test func aDeferralWinsOverTheNextBreak() {
        let result = state(deferralReason: .screenSharing, nextBreakTime: next)
        #expect(result == .deferred(.screenSharing))
    }

    @Test func aNextBreakWinsOverAnEmptyScheduleList() {
        #expect(state(nextBreakTime: next, hasSchedules: false) == .countingDown(to: next))
    }

    @Test func noSchedulesAndNoNextBreak() {
        #expect(state(hasSchedules: false) == .noSchedules)
    }

    @Test func schedulesWithNoNextBreakAreNotActive() {
        #expect(state() == .noActiveSchedules)
    }
}

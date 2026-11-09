import Testing
import StandLockCore
@testable import Scheduling

@Suite("Repetition rest durations")
struct RepetitionRestTests {
    private let rule = RepetitionRule(shortBreakCount: 3, shortBreakDuration: 300, longBreakDuration: 1200)

    @Test func completedShortsLeadToLongAndLongRestResets() {
        var tracker = RepetitionTracker(rule: rule)
        for expected in 1...3 {
            tracker.recordBreak(duration: 300)
            #expect(tracker.currentBreakIndex == expected)
        }
        #expect(tracker.isLongBreak)
        tracker.recordBreak(duration: 1200)
        #expect(tracker.currentBreakIndex == 0)
        #expect(!tracker.isLongBreak)
    }

    @Test(arguments: [1199.0, 1200.0, 1800.0])
    func actualDurationOverridesScheduledType(duration: Double) {
        var tracker = RepetitionTracker(rule: rule, currentBreakIndex: 2)
        tracker.recordBreak(duration: duration)
        #expect(tracker.currentBreakIndex == (duration >= 1200 ? 0 : 3))
    }

    @Test func shorterRestCannotClearOrOverflowALongBreakDue() {
        var tracker = RepetitionTracker(rule: rule, currentBreakIndex: Int.max)
        tracker.recordBreak(duration: 300)
        tracker.recordBreak(duration: 300)
        #expect(tracker.currentBreakIndex == 3)
        #expect(tracker.isLongBreak)
    }

    @Test func timeAwayResetsOnlyWhenItIsLongEnough() {
        var tracker = RepetitionTracker(rule: rule, currentBreakIndex: 2)
        tracker.recordTimeAway(duration: 1199)
        #expect(tracker.currentBreakIndex == 2)
        tracker.recordTimeAway(duration: 1200)
        #expect(tracker.currentBreakIndex == 0)
        tracker.recordTimeAway(duration: 300)
        #expect(tracker.currentBreakIndex == 0)
    }

    @Test func scheduledDurationCompatibilityIsRetained() {
        var tracker = RepetitionTracker(rule: rule)
        for _ in 0..<3 { tracker.recordBreak() }
        #expect(tracker.isLongBreak)
        tracker.recordBreak()
        #expect(!tracker.isLongBreak)
    }
}

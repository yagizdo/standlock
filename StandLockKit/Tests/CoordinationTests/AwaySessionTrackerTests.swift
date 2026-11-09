import Testing
@testable import Coordination

@Suite("Away session tracker")
struct AwaySessionTrackerTests {
    @Test func overlappingReasonsReturnOnlyOnce() {
        var tracker = AwaySessionTracker()
        #expect(tracker.set(.locked, active: true, at: 10) == .departed)
        #expect(tracker.set(.locked, active: true, at: 20) == nil)
        #expect(tracker.set(.sleeping, active: true, at: 30) == nil)
        #expect(tracker.set(.sleeping, active: false, at: 60) == nil)
        #expect(tracker.isAway)
        #expect(tracker.set(.locked, active: false, at: 310) == .returned(duration: 300))
        #expect(tracker.set(.locked, active: false, at: 320) == nil)
    }

    @Test func reversedReturnOrderAndUnmatchedReturns() {
        var tracker = AwaySessionTracker()
        #expect(tracker.set(.locked, active: false, at: 0) == nil)
        _ = tracker.set(.sleeping, active: true, at: 10)
        _ = tracker.set(.locked, active: true, at: 20)
        #expect(tracker.set(.locked, active: false, at: 30) == nil)
        #expect(tracker.set(.sleeping, active: false, at: 70) == .returned(duration: 60))
    }
}

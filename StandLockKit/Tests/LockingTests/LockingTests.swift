import Foundation
import Testing
@testable import Locking
@testable import StandLockCore

// MARK: - EscapeDetector Tests

@Suite("EscapeDetector Tests")
struct EscapeDetectorTests {
    @Test func allKeysHeld10Seconds() {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: start)
        #expect(detector.isHolding)
        #expect(!detector.isEscapeTriggered(at: start))

        let after10 = start.addingTimeInterval(10)
        #expect(detector.isEscapeTriggered(at: after10))
    }

    @Test func partialHoldDoesNotTrigger() {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: false, at: start)
        #expect(!detector.isHolding)
        #expect(!detector.isEscapeTriggered(at: start.addingTimeInterval(15)))
    }

    @Test func holdInterruptedResetsTimer() {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()

        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: start)
        #expect(detector.isHolding)

        let at8s = start.addingTimeInterval(8)
        detector.flagsChanged(controlDown: true, optionDown: false, commandDown: true, at: at8s)
        #expect(!detector.isHolding)
        #expect(detector.holdStartTime == nil)

        let rehold = at8s.addingTimeInterval(1)
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: rehold)
        #expect(!detector.isEscapeTriggered(at: rehold.addingTimeInterval(9)))
        #expect(detector.isEscapeTriggered(at: rehold.addingTimeInterval(10)))
    }

    @Test func reset() {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: start)
        #expect(detector.isHolding)
        detector.reset()
        #expect(!detector.isHolding)
        #expect(detector.holdStartTime == nil)
    }
}

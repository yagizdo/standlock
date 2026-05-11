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

// MARK: - LockStateMachine Tests

@Suite("LockStateMachine Tests")
struct LockStateMachineTests {

    @Test func gentleActivateAndSkip() {
        var sm = LockStateMachine()
        sm.handle(.activate(level: .gentle, duration: 300))
        #expect(sm.state == .active(level: .gentle, remainingSeconds: 300))

        sm.handle(.skipRequested)
        #expect(sm.state == .dismissed(outcome: .skipped))
        #expect(sm.dailySkipCount == 1)
    }

    @Test func firmSkipDelay() {
        var sm = LockStateMachine(skipDelay: 10, dailySkipLimit: 5)
        sm.handle(.activate(level: .firm, duration: 300))

        // Immediate skip should not work for Firm
        sm.handle(.skipRequested)
        #expect(sm.state == .active(level: .firm, remainingSeconds: 300))

        // After 10s delay
        sm.handle(.tick(elapsed: 10))
        #expect(sm.state == .skipAvailable)

        sm.handle(.skipRequested)
        #expect(sm.state == .dismissed(outcome: .skipped))
    }

    @Test func firmPhraseTyping() {
        var sm = LockStateMachine(skipDelay: 10, dailySkipLimit: 5)
        sm.handle(.activate(level: .firm, duration: 300))

        sm.handle(.phraseTyped(correct: true))
        #expect(sm.state == .dismissed(outcome: .skipped))
        #expect(sm.dailySkipCount == 1)
    }

    @Test func firmWrongPhrase() {
        var sm = LockStateMachine(skipDelay: 10, dailySkipLimit: 5)
        sm.handle(.activate(level: .firm, duration: 300))

        sm.handle(.phraseTyped(correct: false))
        #expect(sm.state == .active(level: .firm, remainingSeconds: 300))
    }

    @Test func firmDailySkipLimitReached() {
        var sm = LockStateMachine(skipDelay: 10, dailySkipLimit: 2)

        // Use up 2 skips
        sm.handle(.activate(level: .firm, duration: 300))
        sm.handle(.phraseTyped(correct: true))
        #expect(sm.dailySkipCount == 1)

        sm.handle(.activate(level: .firm, duration: 300))
        sm.handle(.phraseTyped(correct: true))
        #expect(sm.dailySkipCount == 2)

        // Third attempt should not skip
        sm.handle(.activate(level: .firm, duration: 300))
        sm.handle(.phraseTyped(correct: true))
        #expect(sm.state == .active(level: .firm, remainingSeconds: 300))
    }

    @Test func strictEscape() {
        var sm = LockStateMachine()
        sm.handle(.activate(level: .strict, duration: 300))
        sm.handle(.escapeTriggered)
        #expect(sm.state == .dismissed(outcome: .escaped))
    }

    @Test func strictNoSkip() {
        var sm = LockStateMachine()
        sm.handle(.activate(level: .strict, duration: 300))
        sm.handle(.skipRequested)
        #expect(sm.state == .active(level: .strict, remainingSeconds: 300))
    }

    @Test func timerExpired() {
        var sm = LockStateMachine()
        sm.handle(.activate(level: .gentle, duration: 300))
        sm.handle(.timerExpired)
        #expect(sm.state == .dismissed(outcome: .completed))
    }
}

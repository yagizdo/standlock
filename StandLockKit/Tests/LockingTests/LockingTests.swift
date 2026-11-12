import CoreGraphics
import Foundation
import Testing
@testable import Locking
@testable import StandLockCore

// MARK: - EscapeDetector Tests

@Suite("EscapeDetector Tests")
struct EscapeDetectorTests {
    @Test(arguments: [366.0 * 86_400, Double.infinity, Double.nan, -1.0])
    func unsafeStoredHoldStillAllowsEmergencyEscape(duration: Double) {
        var detector = EscapeDetector(requiredDuration: duration)
        let start = Date()
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: start)
        #expect(detector.requiredDuration.isFinite)
        #expect((0...30).contains(detector.requiredDuration))
        #expect(detector.isEscapeTriggered(at: start.addingTimeInterval(30)))
    }

    @Test func allKeysHeld10Seconds() {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()
        detector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: start)
        #expect(detector.isHolding)
        #expect(!detector.isEscapeTriggered(at: start))

        let after10 = start.addingTimeInterval(10)
        #expect(detector.isEscapeTriggered(at: after10))
    }

    @Test(arguments: [
        (control: false, option: true, command: true),
        (control: true, option: false, command: true),
        (control: true, option: true, command: false),
    ])
    func partialHoldDoesNotTrigger(keys: (control: Bool, option: Bool, command: Bool)) {
        var detector = EscapeDetector(requiredDuration: 10)
        let start = Date()
        detector.flagsChanged(controlDown: keys.control, optionDown: keys.option, commandDown: keys.command, at: start)
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

// MARK: - Hold timer under a modal

private final class Fired: @unchecked Sendable {
    var count = 0
}

@Suite("EventTapController hold timer")
struct EventTapHoldTimerTests {
    /// An app-modal alert runs the main run loop in the modal panel mode. The tap source is in
    /// the common modes and keeps blocking there, so a hold timer that only fires in the default
    /// mode leaves a steady Strict hold unable to end the break.
    @Test @MainActor
    func holdTimerFiresUnderAModal() throws {
        let modal = RunLoop.Mode("NSModalPanelRunLoopMode")
        // AppKit puts the modal mode in the common modes at launch; a test process has no AppKit.
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(modal.rawValue as CFString))
        let fired = Fired()
        let controller = EventTapController(escapeHoldDuration: 0.05) { fired.count += 1 }
        let event = try #require(CGEvent(source: nil))
        event.type = .flagsChanged
        event.flags = [.maskControl, .maskAlternate, .maskCommand]
        _ = controller.handleEvent(proxy: OpaquePointer(bitPattern: 1)!, type: .flagsChanged, event: event)

        let deadline = Date().addingTimeInterval(1)
        while fired.count == 0, Date() < deadline {
            _ = RunLoop.main.run(mode: modal, before: Date().addingTimeInterval(0.02))
        }
        #expect(fired.count == 1)
    }
}

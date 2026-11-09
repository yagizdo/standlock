import CoreGraphics
import Foundation
import Testing
@testable import Locking

@Suite("Escape availability")
struct EscapeAvailabilityTests {
    @Test func disabledEscapeNeverStartsAHold() throws {
        let controller = EventTapController(onEscapeTriggered: {})
        controller.escapeEnabled = false
        let event = try #require(CGEvent(source: nil))
        event.flags = [.maskControl, .maskAlternate, .maskCommand]
        _ = controller.handleEvent(proxy: OpaquePointer(bitPattern: 1)!, type: .flagsChanged, event: event)
        #expect(!controller.escapeDetector.isHolding)
    }

    @Test func disablingEscapeClearsAnExistingHold() {
        let controller = EventTapController(onEscapeTriggered: {})
        controller.escapeDetector.flagsChanged(controlDown: true, optionDown: true, commandDown: true, at: Date())
        controller.escapeEnabled = false
        #expect(!controller.escapeDetector.isHolding)
    }
}

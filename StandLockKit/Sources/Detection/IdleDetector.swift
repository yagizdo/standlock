import CoreGraphics
import Foundation

public struct IdleDetector: Sendable {
    public init() {}

    public func idleDuration() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
    }

    public func inputIdleDuration() -> TimeInterval {
        // Read activity at the HID source, upstream of Strict's session event tap.
        CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: CGEventType(rawValue: ~0)!
        )
    }
}

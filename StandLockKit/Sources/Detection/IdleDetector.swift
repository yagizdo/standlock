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
}

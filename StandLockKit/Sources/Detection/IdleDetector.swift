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
        // Read physical input before Strict's session event tap can discard it.
        let inputTypes: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged, .mouseMoved, .scrollWheel,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        ]
        return inputTypes.map {
            CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0)
        }.min() ?? 0
    }
}

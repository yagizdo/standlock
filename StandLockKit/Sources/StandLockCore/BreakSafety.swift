import Foundation

/// Recovery limits apply to imported files and preferences saved by older releases.
public enum BreakSafety {
    public static let maximumBreakDuration: TimeInterval = 60 * 60
    public static let maximumEscapeHoldDuration: TimeInterval = 30
    public static let maximumSkipDelay: TimeInterval = 60

    public static func escapeHoldDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration >= 0 else { return 10 }
        return min(max(0, duration), maximumEscapeHoldDuration)
    }

    public static func skipDelay(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration >= 0 else { return 10 }
        return min(duration, maximumSkipDelay)
    }

    public static func breakDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        return min(duration, maximumBreakDuration)
    }
}

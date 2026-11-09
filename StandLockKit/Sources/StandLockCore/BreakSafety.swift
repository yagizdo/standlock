import Foundation

/// Recovery limits apply to imported files and preferences saved by older releases.
public enum BreakSafety {
    public static let maximumBreakDuration: TimeInterval = 60 * 60
    public static let maximumEscapeHoldDuration: TimeInterval = 30
    public static let maximumSkipDelay: TimeInterval = 60
    /// The form's floor. Below it a skip or a finished break opens the next one at once.
    public static let minimumBreakInterval: TimeInterval = 60
    public static let maximumEscapePhraseLength = 100

    public static func breakInterval(_ interval: TimeInterval) -> TimeInterval {
        max(interval, minimumBreakInterval)
    }

    /// The phrase has no Settings field, so one that cannot be typed falls back to the default.
    public static func escapePhrase(_ phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumEscapePhraseLength,
              trimmed.rangeOfCharacter(from: .newlines) == nil
        else { return AppPreferences.defaultFirmEscapePhrase }
        return trimmed
    }

    public static func escapeHoldDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration >= 0 else { return 10 }
        return min(duration, maximumEscapeHoldDuration)
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

import Foundation
import StandLockCore

public struct RepetitionTracker: Sendable {
    private let rule: RepetitionRule
    public private(set) var currentBreakIndex: Int = 0

    /// Completed short breaks since the last observed long rest survive coordinator rebuilds
    /// and calendar-day changes. A rule whose
    /// `shortBreakCount` shrank below the restored index simply makes the next break the long one.
    public init(rule: RepetitionRule, currentBreakIndex: Int = 0) {
        self.rule = rule
        self.currentBreakIndex = max(0, currentBreakIndex)
    }

    public var isLongBreak: Bool {
        currentBreakIndex >= rule.shortBreakCount
    }

    public var currentDuration: TimeInterval {
        isLongBreak ? rule.longBreakDuration : rule.shortBreakDuration
    }

    public mutating func recordBreak() {
        recordBreak(duration: currentDuration)
    }

    /// A completed rest is classified by its observed duration, not the scheduled break type.
    public mutating func recordBreak(duration: TimeInterval) {
        if duration >= rule.longBreakDuration {
            reset()
        } else if currentBreakIndex < rule.shortBreakCount {
            currentBreakIndex += 1
        } else {
            currentBreakIndex = max(0, rule.shortBreakCount)
        }
    }

    /// Other schedules share the same rest, without gaining extra short-break completions.
    public mutating func recordTimeAway(duration: TimeInterval) {
        if duration >= rule.longBreakDuration { reset() }
    }

    public mutating func reset() {
        currentBreakIndex = 0
    }
}

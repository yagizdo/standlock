import Foundation
import StandLockCore

public struct RepetitionTracker: Sendable {
    private let rule: RepetitionRule
    public private(set) var currentBreakIndex: Int = 0

    /// `currentBreakIndex` is carried over when a coordinator is rebuilt mid-day, so a schedule
    /// edit does not send the user back to the start of the short-break run. A rule whose
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
        if isLongBreak {
            currentBreakIndex = 0
        } else {
            currentBreakIndex += 1
        }
    }

    public mutating func reset() {
        currentBreakIndex = 0
    }
}

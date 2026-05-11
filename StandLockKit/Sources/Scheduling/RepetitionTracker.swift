import Foundation
import StandLockCore

public struct RepetitionTracker: Sendable {
    private let rule: RepetitionRule
    public private(set) var currentBreakIndex: Int = 0

    public init(rule: RepetitionRule) {
        self.rule = rule
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

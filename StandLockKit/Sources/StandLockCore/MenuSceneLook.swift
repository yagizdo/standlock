import Foundation

/// What a menu bar scene draws. `NextBreakState` plus the last minute.
public enum MenuSceneLook: Equatable, Sendable {
    case working
    case breakSoon
    case timeToStand
    case paused
    case breakWaiting
    case noSchedules

    public init(state: NextBreakState, now: Date = Date()) {
        switch state {
        case .breakActive:
            self = .timeToStand
        case .paused:
            self = .paused
        case .deferred:
            self = .breakWaiting
        case .countingDown(let nextBreak):
            // The rounded seconds, so the look turns when the digits read 1:00.
            self = breakSecondsRemaining(until: nextBreak, now: now) > 60 ? .working : .breakSoon
        case .noSchedules, .noActiveSchedules:
            self = .noSchedules
        }
    }
}

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

    /// During a session, a covered phase that is not on screen waits: a postponed break counts
    /// down to its return through `.countingDown`, which would otherwise read as focus. In cover
    /// mode the open break is rest, so it reads as standing.
    public init(state: NextBreakState, pomodoro: PomodoroStatus?, now: Date = Date()) {
        if let pomodoro, pomodoro.isCovered, state != .breakActive {
            self = .breakWaiting
        } else if let pomodoro, pomodoro.phase.isBreak, !pomodoro.isCovered {
            self = .timeToStand
        } else {
            self.init(state: state, now: now)
        }
    }
}

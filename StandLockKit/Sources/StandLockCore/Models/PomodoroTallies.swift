import Foundation

/// What Pomodoro sessions added up to on one day. Not breaks: the session's breaks count in the
/// ordinary completed, skipped and escaped counters.
public struct PomodoroTallies: Codable, Sendable, Equatable {
    /// Focus time that ran, ended by its timer or by Skip phase.
    public var focusSeconds: TimeInterval
    /// Focus phases that ended.
    public var rounds: Int
    /// Sessions that reached the end of their long break.
    public var sessionsFinished: Int
    /// Sessions stopped before that, or dropped at launch on a later day.
    public var sessionsAbandoned: Int

    public init(focusSeconds: TimeInterval = 0, rounds: Int = 0, sessionsFinished: Int = 0, sessionsAbandoned: Int = 0) {
        self.focusSeconds = focusSeconds
        self.rounds = rounds
        self.sessionsFinished = sessionsFinished
        self.sessionsAbandoned = sessionsAbandoned
    }

    public var isEmpty: Bool { self == PomodoroTallies() }

    public static func + (lhs: PomodoroTallies, rhs: PomodoroTallies) -> PomodoroTallies {
        PomodoroTallies(
            focusSeconds: lhs.focusSeconds + rhs.focusSeconds,
            rounds: lhs.rounds + rhs.rounds,
            sessionsFinished: lhs.sessionsFinished + rhs.sessionsFinished,
            sessionsAbandoned: lhs.sessionsAbandoned + rhs.sessionsAbandoned
        )
    }
}

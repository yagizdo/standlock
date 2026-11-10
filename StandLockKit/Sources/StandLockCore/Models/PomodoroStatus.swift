import Foundation

/// What the panel shows of a running session.
public struct PomodoroStatus: Equatable, Sendable {
    public var phase: PomodoroPhase
    public var rounds: Int
    public var phaseEnd: Date
    public var level: DisciplineLevel

    public init(session: PomodoroSession, level: DisciplineLevel) {
        phase = session.phase
        rounds = session.configuration.rounds
        phaseEnd = session.phaseEnd
        self.level = level
    }

    /// The focus round in progress, or the next one during a short break (`next Focus n/4`).
    public var round: Int {
        switch phase {
        case .focus(let round): round
        case .shortBreak(let round): round + 1
        case .longBreak: rounds
        }
    }

    /// The overlay chip for a session break; nil during focus.
    public var chip: PomodoroChip? {
        switch phase {
        case .focus: nil
        case .shortBreak(let round): PomodoroChip(round: round, rounds: rounds, isLong: false)
        case .longBreak: PomodoroChip(round: rounds, rounds: rounds, isLong: true)
        }
    }
}

/// What the overlay chip shows. The app's view is `PomodoroChipView`: this name in the app
/// would hide the Kit type, and Kit's empty `enum StandLockCore` blocks module qualification.
public struct PomodoroChip: Equatable, Sendable {
    public var round: Int
    public var rounds: Int
    public var isLong: Bool

    public init(round: Int, rounds: Int, isLong: Bool) {
        self.round = round
        self.rounds = rounds
        self.isLong = isLong
    }
}

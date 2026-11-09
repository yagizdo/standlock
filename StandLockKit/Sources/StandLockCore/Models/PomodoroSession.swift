import Foundation

public enum PomodoroPhase: Codable, Sendable, Equatable {
    case focus(round: Int)
    case shortBreak(afterRound: Int)
    case longBreak

    public var isBreak: Bool {
        if case .focus = self { return false }
        return true
    }
}

/// A Pomodoro session the user started: focus and break phases on the wall clock, so sleep
/// and lock do not stop it. Pure value; the coordinator owns the timer.
public struct PomodoroSession: Codable, Sendable, Equatable {
    public var id: UUID
    public var startedAt: Date
    /// Copied at start: a Settings change applies to the next session.
    public var configuration: PomodoroConfiguration
    public var phase: PomodoroPhase
    public var phaseEnd: Date
    public var focusSecondsDone: TimeInterval

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        configuration: PomodoroConfiguration,
        phase: PomodoroPhase,
        phaseEnd: Date,
        focusSecondsDone: TimeInterval = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.configuration = configuration
        self.phase = phase
        self.phaseEnd = phaseEnd
        self.focusSecondsDone = focusSecondsDone
    }

    public static func start(at now: Date, configuration: PomodoroConfiguration) -> PomodoroSession {
        PomodoroSession(
            startedAt: now,
            configuration: configuration,
            phase: .focus(round: 1),
            phaseEnd: now.addingTimeInterval(configuration.focus)
        )
    }

    public func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: configuration.focus
        case .shortBreak: configuration.shortBreak
        case .longBreak: configuration.longBreak
        }
    }

    /// The phase after this one, starting at `now`, or nil when the long break ends the session.
    public func next(at now: Date) -> PomodoroSession? {
        var next = self
        switch phase {
        case .focus(let round):
            next.focusSecondsDone += configuration.focus
            next.phase = round >= configuration.rounds ? .longBreak : .shortBreak(afterRound: round)
        case .shortBreak(let round):
            next.phase = .focus(round: round + 1)
        case .longBreak:
            return nil
        }
        next.phaseEnd = now.addingTimeInterval(duration(of: next.phase))
        return next
    }

    /// Applies a stretch away (sleep, lock, quit) from `awayFrom` to `to`. Time away counts as
    /// rest: a break it covers is credited and the next focus starts at `to`.
    public func catchUp(awayFrom: Date, to: Date) -> PomodoroCatchUp {
        guard to >= phaseEnd else { return .unchanged }
        if phase.isBreak {
            return .creditedBreaks(count: 1, session: next(at: to))
        }
        // Focus ended while away; the break that follows is due now.
        guard let onBreak = next(at: to) else { return .unchanged }
        let remaining = duration(of: onBreak.phase) - to.timeIntervalSince(awayFrom)
        guard remaining > 0 else {
            return .creditedBreaks(count: 1, session: onBreak.next(at: to))
        }
        var open = onBreak
        open.phaseEnd = to.addingTimeInterval(remaining)
        return .openBreak(remaining: remaining, session: open)
    }

    /// A saved session made safe to run, or nil to drop it: lengths outside the form's ranges
    /// (a zero-length phase loops), or a round the session does not have. The phase end is pulled
    /// back to one phase length after `now`, so a clock set back cannot stretch it.
    public func bounded(now: Date) -> PomodoroSession? {
        guard configuration.isWithinBounds, phaseEnd.timeIntervalSinceReferenceDate.isFinite else { return nil }
        switch phase {
        case .focus(let round): guard (1...configuration.rounds).contains(round) else { return nil }
        case .shortBreak(let round): guard (1..<configuration.rounds).contains(round) else { return nil }
        case .longBreak: break
        }
        var copy = self
        copy.phaseEnd = min(phaseEnd, now.addingTimeInterval(duration(of: phase)))
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, configuration, phase, phaseEnd, focusSecondsDone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        configuration = try c.decodeIfPresent(PomodoroConfiguration.self, forKey: .configuration) ?? .standard
        phase = try c.decode(PomodoroPhase.self, forKey: .phase)
        phaseEnd = try c.decode(Date.self, forKey: .phaseEnd)
        focusSecondsDone = try c.decodeIfPresent(TimeInterval.self, forKey: .focusSecondsDone) ?? 0
    }
}

public enum PomodoroCatchUp: Sendable, Equatable {
    case unchanged
    /// Breaks the time away covered; `session` is nil when the session finished.
    case creditedBreaks(count: Int, session: PomodoroSession?)
    /// A break the time away covered only in part, ending `remaining` seconds after the return.
    case openBreak(remaining: TimeInterval, session: PomodoroSession)
}

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

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        configuration: PomodoroConfiguration,
        phase: PomodoroPhase,
        phaseEnd: Date
    ) {
        self.id = id
        self.startedAt = startedAt
        self.configuration = configuration
        self.phase = phase
        self.phaseEnd = phaseEnd
    }

    public static func start(at now: Date, configuration: PomodoroConfiguration) -> PomodoroSession {
        var session = PomodoroSession(startedAt: now, configuration: configuration, phase: .focus(round: 1), phaseEnd: now)
        session.phaseEnd = now.addingTimeInterval(session.duration(of: session.phase))
        return session
    }

    /// The phase the overlay covers right now: the break in the classic mode, the focus in `.focus`.
    public var isCovered: Bool { covers(phase) }

    private func covers(_ phase: PomodoroPhase) -> Bool {
        configuration.cover == .focus ? !phase.isBreak : phase.isBreak
    }

    public func duration(of phase: PomodoroPhase) -> TimeInterval {
        let length: TimeInterval = switch phase {
        case .focus: configuration.focus
        case .shortBreak: configuration.shortBreak
        case .longBreak: configuration.longBreak
        }
        // A covered phase is an overlay: bounded at use as every break is.
        return covers(phase) ? BreakSafety.breakDuration(length) : length
    }

    /// Focus time that ran by `now`: none outside a focus, all of it once the focus is over,
    /// the part before an early end (Skip phase).
    public func focusElapsed(at now: Date) -> TimeInterval {
        guard case .focus = phase else { return 0 }
        let left = max(0, phaseEnd.timeIntervalSince(now))
        return max(0, duration(of: phase) - left)
    }

    /// The phase after this one, starting at `now`, or nil when the long break ends the session.
    public func next(at now: Date) -> PomodoroSession? {
        var next = self
        switch phase {
        case .focus(let round):
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
        if configuration.cover == .focus, !isCovered {
            // An open break that ran out away, or nearly: the next cover waits a minute after the return.
            let earliest = to.addingTimeInterval(BreakSafety.minimumBreakInterval)
            guard phaseEnd < earliest else { return .unchanged }
            var delayed = self
            delayed.phaseEnd = earliest
            return .coverDelayed(session: delayed)
        }
        guard to >= phaseEnd else { return .unchanged }
        if isCovered {
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

    /// A saved session comes back after a relaunch on the day it started only, as `EnforcementState`.
    public func isRestorable(now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(startedAt, inSameDayAs: now)
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
        case id, startedAt, configuration, phase, phaseEnd
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        configuration = try c.decodeIfPresent(PomodoroConfiguration.self, forKey: .configuration) ?? .standard
        phase = try c.decode(PomodoroPhase.self, forKey: .phase)
        phaseEnd = try c.decode(Date.self, forKey: .phaseEnd)
    }
}

public enum PomodoroCatchUp: Sendable, Equatable {
    case unchanged
    /// Breaks the time away covered; `session` is nil when the session finished.
    case creditedBreaks(count: Int, session: PomodoroSession?)
    /// A break the time away covered only in part, ending `remaining` seconds after the return.
    case openBreak(remaining: TimeInterval, session: PomodoroSession)
    /// Cover mode: the open break ends no sooner than a minute after the return.
    case coverDelayed(session: PomodoroSession)
}

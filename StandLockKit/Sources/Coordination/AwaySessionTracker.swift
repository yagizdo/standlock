import Foundation

/// Combines overlapping lock and sleep notifications into one continuous absence.
public struct AwaySessionTracker: Sendable {
    public enum Reason: Hashable, Sendable { case locked, sleeping }
    public enum Transition: Equatable, Sendable {
        case departed
        case returned(duration: TimeInterval)
    }

    private var reasons: Set<Reason> = []
    private var startedAt: TimeInterval?
    public var isAway: Bool { !reasons.isEmpty }

    public init() {}

    public mutating func set(_ reason: Reason, active: Bool, at time: TimeInterval) -> Transition? {
        let wasAway = isAway
        if active { reasons.insert(reason) } else { reasons.remove(reason) }
        if !wasAway && isAway {
            startedAt = time
            return .departed
        }
        if wasAway && !isAway {
            let duration = max(0, time - (startedAt ?? time))
            startedAt = nil
            return .returned(duration: duration)
        }
        return nil
    }
}

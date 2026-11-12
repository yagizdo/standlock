import Foundation

/// What the Troubleshooting page says about a launch that followed a run which died with a break
/// on screen. The app records the launch date; the marker itself is gone by then.
public struct UncleanExitStatus: Equatable, Sendable {
    /// How long after that launch the page still mentions it.
    public static let shownFor: TimeInterval = 7 * 24 * 60 * 60

    public var reopenedAt: Date
    /// No break opened before this (`UncleanExit.launchGuard`).
    public var firstBreakNotBefore: Date
    public var isFirstBreakPending: Bool

    public init(reopenedAt: Date, firstBreakNotBefore: Date, isFirstBreakPending: Bool) {
        self.reopenedAt = reopenedAt
        self.firstBreakNotBefore = firstBreakNotBefore
        self.isFirstBreakPending = isFirstBreakPending
    }

    /// A date in the future means the clock moved back after that launch; it is still shown.
    /// `launchedAt` is this run's start: only the run that wrote the record holds the guard, so a
    /// relaunch within the grace has no pending first break.
    public static func make(reopenedAt: Date?, launchedAt: Date, now: Date) -> UncleanExitStatus? {
        guard let reopenedAt, now.timeIntervalSince(reopenedAt) < shownFor else { return nil }
        let notBefore = reopenedAt.addingTimeInterval(UncleanExit.grace)
        return UncleanExitStatus(reopenedAt: reopenedAt, firstBreakNotBefore: notBefore,
                                 isFirstBreakPending: reopenedAt >= launchedAt && now < notBefore)
    }
}

/// The one action that answers "why is no break coming?" for the current state.
public enum TroubleshootingFix: Equatable, Sendable {
    case resume, openSchedules, openDetection

    public init?(_ state: NextBreakState) {
        switch state {
        case .paused: self = .resume
        case .noActiveSchedules, .noSchedules: self = .openSchedules
        case .deferred(let reason) where reason != .postponed: self = .openDetection
        case .deferred, .breakActive, .countingDown: return nil
        }
    }
}

extension Array where Element == Schedule {
    /// Every Strict schedule, on or off, moved to Firm, which needs no permission.
    public func strictLoweredToFirm() -> [Schedule] {
        map { schedule in
            var lowered = schedule
            if lowered.disciplineLevel == .strict { lowered.disciplineLevel = .firm }
            return lowered
        }
    }

    /// Off schedules count: turning one on brings Strict back.
    public var containsStrict: Bool {
        contains { $0.disciplineLevel == .strict }
    }
}

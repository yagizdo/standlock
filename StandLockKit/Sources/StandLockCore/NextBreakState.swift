import Foundation

/// What the Settings sidebar and the menu bar panel say about the next break. The order is the
/// priority: a running break hides a pause, and a pause hides a deferral.
public enum NextBreakState: Equatable, Sendable {
    case breakActive
    case paused(until: Date)
    case deferred(DeferralReason)
    case countingDown(to: Date)
    case noSchedules
    case noActiveSchedules

    public init(
        isBreakActive: Bool,
        isPaused: Bool,
        pausedUntil: Date?,
        deferralReason: DeferralReason?,
        nextBreakTime: Date?,
        hasSchedules: Bool
    ) {
        if isBreakActive {
            self = .breakActive
        } else if isPaused, let pausedUntil {
            self = .paused(until: pausedUntil)
        } else if let deferralReason {
            self = .deferred(deferralReason)
        } else if let nextBreakTime {
            self = .countingDown(to: nextBreakTime)
        } else if hasSchedules {
            self = .noActiveSchedules
        } else {
            self = .noSchedules
        }
    }
}

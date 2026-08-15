import Foundation

public enum CoordinatorEvent: Sendable {
    case nextBreakScheduled(Date)
    case breakStarted(BreakEvent)
    case breakCompleted(BreakEvent)
    case breakSkipped(BreakEvent)
    case breakEscaped(BreakEvent)
    case breakDeferred(DeferralReason, nextAttempt: Date)
    case schedulePaused(until: Date)
    case scheduleResumed
    case statisticsUpdated(BreakStatistics)
}

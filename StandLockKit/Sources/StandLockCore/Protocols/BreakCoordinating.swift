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

public protocol BreakCoordinating: Sendable {
    var events: AsyncStream<CoordinatorEvent> { get }
    @MainActor func start(with schedules: [Schedule], preferences: AppPreferences)
    @MainActor func stop()
    @MainActor func pause(for duration: TimeInterval)
    @MainActor func resume()
    @MainActor func skipNextBreak()
    @MainActor func changeDisciplineLevel(_ level: DisciplineLevel)
}

import Foundation

public protocol LockPresenting: Sendable {
    /// - Parameter escalationTier: Per-schedule enforcement tier (0-3). 0 = base behavior, 3 = maximum friction.
    /// - Parameter nextIntervalLabel: Label of the work block that follows this break; `nil` for
    ///   schedules without a labeled interval cycle.
    @MainActor func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                                exercise: Exercise?, preferences: AppPreferences,
                                statistics: BreakStatistics, escalationTier: Int,
                                nextIntervalLabel: String?)
    @MainActor func dismissOverlay()
    @MainActor var isShowing: Bool { get }
}

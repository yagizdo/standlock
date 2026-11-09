import Foundation

public protocol LockPresenting: Sendable {
    /// - Parameter escalationTier: Per-schedule enforcement tier. Zero is the base behavior.
    /// - Parameter nextIntervalLabel: Label of the work block that follows this break; `nil` for
    ///   schedules without a labeled interval cycle.
    /// - Parameter canPostpone: `false` for a break that has already been postponed once.
    @MainActor func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                                exercise: Exercise?, preferences: AppPreferences,
                                statistics: BreakStatistics, escalationTier: Int,
                                nextIntervalLabel: String?, canPostpone: Bool,
                                breakID: UUID, dismissalAvailability: DismissalAvailability)
    @MainActor func updateDismissalAvailability(_ availability: DismissalAvailability)
    @MainActor func dismissOverlay()
    @MainActor var isShowing: Bool { get }
}

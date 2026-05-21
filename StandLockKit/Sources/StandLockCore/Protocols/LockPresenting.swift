import Foundation

public protocol LockPresenting: Sendable {
    /// - Parameter escalationTier: Progressive friction tier (0-3). 0 = no escalation, 3 = maximum friction.
    @MainActor func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                                exercise: Exercise?, preferences: AppPreferences,
                                statistics: BreakStatistics, escalationTier: Int)
    @MainActor func dismissOverlay()
    @MainActor var isShowing: Bool { get }
}

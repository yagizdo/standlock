import Foundation

public protocol LockPresenting: Sendable {
    @MainActor func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                                exercise: Exercise?, preferences: AppPreferences,
                                statistics: BreakStatistics)
    @MainActor func dismissOverlay()
    @MainActor var isShowing: Bool { get }
}

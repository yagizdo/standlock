import Foundation

/// What the first break after launch may be when the last run ended with a break on screen.
public struct LaunchGuard: Equatable, Sendable {
    /// No break opens before this.
    public var notBefore: Date
    /// The first break opens at this level, at its base tier.
    public var level: DisciplineLevel

    public init(notBefore: Date, level: DisciplineLevel) {
        self.notBefore = notBefore
        self.level = level
    }
}

/// A break still on screen when the process died (crash, kill, forced power-off) may be one
/// the user could only leave by holding the power button. The next launch must not lock them in
/// again: they get time to reach Settings, and a first break with an immediate Skip.
public enum UncleanExit {
    public static let grace: TimeInterval = 15 * 60

    /// `marker` is when the last run's break came on screen, written while it was there and
    /// removed when it ended. Its date is not trusted: a clock change or a marker left months
    /// ago still means that run never ended its break.
    public static func launchGuard(breakOnScreenSince marker: Date?, now: Date) -> LaunchGuard? {
        guard marker != nil else { return nil }
        return LaunchGuard(notBefore: now.addingTimeInterval(grace), level: .gentle)
    }
}

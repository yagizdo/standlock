import Foundation

/// Calendar time is separate from elapsed time, which continues through system sleep.
public struct CoordinatorClock: Sendable {
    public var now: @Sendable () -> Date
    public var elapsed: @Sendable () -> TimeInterval
    public var sleep: @Sendable (TimeInterval) async throws -> Void

    public init(now: @escaping @Sendable () -> Date,
                elapsed: @escaping @Sendable () -> TimeInterval,
                sleep: @escaping @Sendable (TimeInterval) async throws -> Void) {
        self.now = now
        self.elapsed = elapsed
        self.sleep = sleep
    }

    private static let epoch = ContinuousClock.now
    public static let live = CoordinatorClock(
        now: { Date() },
        elapsed: {
            let duration = epoch.duration(to: .now).components
            return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        },
        sleep: { try await Task.sleep(for: .seconds(max(0, $0))) }
    )
}

import Foundation

public func calculateBreakProgress(
    scheduledAt: Date?,
    nextBreak: Date?,
    isBreakActive: Bool,
    now: Date = Date()
) -> Double {
    if isBreakActive { return 1.0 }
    guard let scheduledAt, let nextBreak else { return 0 }
    let total = nextBreak.timeIntervalSince(scheduledAt)
    guard total > 0 else { return 0 }
    let elapsed = now.timeIntervalSince(scheduledAt)
    return min(1.0, max(0.0, elapsed / total))
}

public enum ProgressDisplayBranch: Sendable, Equatable {
    case empty
    case partial
    case full

    public init(progress: Double) {
        let clamped = min(1.0, max(0.0, progress))
        if clamped <= 0.005 {
            self = .empty
        } else if clamped >= 0.995 {
            self = .full
        } else {
            self = .partial
        }
    }
}

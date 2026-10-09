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

/// Whole seconds left on a break that ends at `end`.
///
/// Read from the clock, not counted down per tick: a tick that wakes late behind a busy
/// main thread would otherwise add its delay to the break, and the lock outlasts its length.
public func breakSecondsRemaining(until end: Date, now: Date = Date()) -> TimeInterval {
    max(0, end.timeIntervalSince(now).rounded())
}

public func formatMenuBarTimer(
    secondsRemaining: TimeInterval,
    showFullTimer: Bool,
    countdownMinutes: Int,
    isBreakActive: Bool,
    isPaused: Bool,
    hasScheduledBreak: Bool,
    /// Localised by the caller: the Kit ships no string catalog, so the app resolves it.
    minuteSuffix: String = "m"
) -> String? {
    if isBreakActive || isPaused || !hasScheduledBreak { return nil }
    let remaining = max(0, secondsRemaining)

    if !showFullTimer {
        let threshold = TimeInterval(countdownMinutes * 60)
        if remaining > threshold { return nil }
    }

    let wholeSeconds = remaining.rounded(.down)
    if wholeSeconds < 60 {
        let seconds = Int(wholeSeconds) % 60
        return String(format: "0:%02d", seconds)
    } else {
        let minutes = Int(ceil(wholeSeconds / 60))
        return "\(minutes)\(minuteSuffix)"
    }
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

/// The anchor `calculateBreakProgress` measures the interval from.
///
/// A rebuilt coordinator re-arms the slot it inherited rather than computing a fresh one, so
/// re-anchoring on that re-arm shrinks the measured interval down to whatever is left of it --
/// the menu bar ring emptied and refilled at speed on every schedule edit. Same for a window
/// -anchored slot re-yielded on wake or unlock: the target has not moved, so neither should the
/// anchor. Only a slot that actually differs from the armed one starts a new interval.
///
/// Depends on the caller keeping its previous `nextBreak` across a coordinator teardown --
/// `AppCoordinator.clearActiveBreakState` deliberately leaves it alone for this reason.
public func breakProgressAnchor(
    existingAnchor: Date?,
    existingNextBreak: Date?,
    newNextBreak: Date,
    now: Date = Date()
) -> Date {
    guard let existingAnchor, existingNextBreak == newNextBreak else { return now }
    return existingAnchor
}

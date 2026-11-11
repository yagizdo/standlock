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

/// `12:04`, or `1:12:04` from an hour up.
public func formatCountdown(secondsRemaining: TimeInterval) -> String {
    let total = Int(max(0, secondsRemaining))
    let hours = total / 3600
    let minutes = total / 60 % 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

public func formatMenuBarTimer(
    secondsRemaining: TimeInterval,
    showFullTimer: Bool,
    countdownMinutes: Int,
    isBreakActive: Bool,
    isPaused: Bool,
    hasScheduledBreak: Bool,
    /// Localised by the caller: the Kit ships no string catalog, so the app resolves it.
    minuteSuffix: String = "m",
    hourSuffix: String = "h"
) -> String? {
    // `Int(_:)` below traps on NaN, infinity and anything past `Int.max`.
    if isBreakActive || isPaused || !hasScheduledBreak || !secondsRemaining.isFinite { return nil }
    let remaining = min(max(0, secondsRemaining), TimeInterval(Int32.max))

    if !showFullTimer {
        let threshold = TimeInterval(countdownMinutes * 60)
        if remaining > threshold { return nil }
    }

    let wholeSeconds = remaining.rounded(.down)
    if wholeSeconds < 60 {
        let seconds = Int(wholeSeconds) % 60
        return String(format: "0:%02d", seconds)
    } else {
        // Rounded up before the split, so 59:59 reads as `1h`, never `60m`.
        let minutes = Int(ceil(wholeSeconds / 60))
        if minutes < 60 { return "\(minutes)\(minuteSuffix)" }
        let hours = "\(minutes / 60)\(hourSuffix)"
        return minutes % 60 == 0 ? hours : "\(hours)\(minutes % 60)\(minuteSuffix)"
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

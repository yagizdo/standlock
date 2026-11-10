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
    case breakCue(BreakCue)
    /// A session phase began or its end moved; nil when the session ended.
    case pomodoroChanged(PomodoroStatus?)
    /// A session ended because the time away crossed midnight; the app records it as abandoned
    /// on the day it started, as for a relaunch on a later day.
    case pomodoroDropped(PomodoroSession)
}

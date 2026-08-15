import Foundation
import StandLockCore
import Scheduling
import Detection
import Locking

@MainActor
public final class BreakCoordinator {
    private let scheduler: any SchedulingEngine
    private let detector: any ContextDetecting
    private let locker: any LockPresenting

    private var activeSchedules: [Schedule] = []
    private var preferences: AppPreferences = AppPreferences()
    private var repetitionTrackers: [UUID: RepetitionTracker] = [:]
    private var breakTimer: Task<Void, Never>?
    private var isPaused: Bool = false
    /// Set while the screen is locked or the machine is asleep. Distinct from `isPaused`, which
    /// is the user-facing pause; suspension only blocks work being started behind a dark screen.
    private var isSuspended: Bool = false
    private var currentBreak: BreakEvent?
    private var currentSchedule: Schedule?
    private var statistics: BreakStatistics = BreakStatistics()
    private var dailyBreakCounts: [UUID: Int] = [:]
    private var escalationTiers: [UUID: Int] = [:]
    public var exercises: [Exercise] = []

    private let deferralPollingInterval: TimeInterval
    private let eventContinuation: AsyncStream<CoordinatorEvent>.Continuation
    public nonisolated let events: AsyncStream<CoordinatorEvent>

    public init(scheduler: any SchedulingEngine, detector: any ContextDetecting,
                locker: any LockPresenting, deferralPollingInterval: TimeInterval = 10) {
        var continuation: AsyncStream<CoordinatorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
        self.scheduler = scheduler
        self.detector = detector
        self.locker = locker
        self.deferralPollingInterval = deferralPollingInterval
    }

    /// Pass previously persisted `statistics` so a relaunch during the day keeps today's
    /// counters instead of restarting them from zero.
    public func start(with schedules: [Schedule], preferences: AppPreferences,
                      statistics: BreakStatistics = BreakStatistics()) {
        self.activeSchedules = schedules
        self.preferences = preferences
        self.statistics = statistics
        for schedule in schedules {
            if let rule = schedule.repetitionRule {
                repetitionTrackers[schedule.id] = RepetitionTracker(rule: rule)
            }
        }
        scheduleNextBreak()
    }

    public func stop() {
        breakTimer?.cancel()
        breakTimer = nil
        if locker.isShowing { locker.dismissOverlay() }
        currentBreak = nil
        currentSchedule = nil
        escalationTiers.removeAll()
    }

    public func pause(for duration: TimeInterval) {
        breakTimer?.cancel()
        breakTimer = nil
        isPaused = true
        let until = Date().addingTimeInterval(duration)
        eventContinuation.yield(.schedulePaused(until: until))
        breakTimer = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            resume()
        }
    }

    public func resume() {
        isPaused = false
        eventContinuation.yield(.scheduleResumed)
        scheduleNextBreak()
    }

    /// Rolls the daily counters over when the calendar day has changed. Safe to call often --
    /// it is a no-op while the recorded day is still the current one.
    public func refreshDailyRollover(now: Date = Date()) {
        guard rolloverIfNeeded(now: now) else { return }
        // A schedule that exhausted its daily cap leaves no pending timer behind, so it has to
        // be re-armed once the new day frees the cap. Nothing may be armed behind a locked or
        // sleeping screen, and a live timer is never touched: while paused it holds the resume
        // task, and otherwise it holds the next break.
        if !isPaused && !isSuspended && breakTimer == nil {
            scheduleNextBreak(now: now)
        }
    }

    @discardableResult
    private func rolloverIfNeeded(now: Date = Date()) -> Bool {
        guard statistics.resetDailyIfNeeded(currentDate: now) else { return false }
        statistics.resetWeeklyIfNeeded(currentDate: now)
        dailyBreakCounts.removeAll()
        // Progressive enforcement escalates within a day; a new day starts from the base tier.
        escalationTiers.removeAll()
        eventContinuation.yield(.statisticsUpdated(statistics))
        return true
    }

    private func updateStatistics(_ mutate: (inout BreakStatistics) -> Void) {
        rolloverIfNeeded()
        mutate(&statistics)
        eventContinuation.yield(.statisticsUpdated(statistics))
    }

    public func handleSystemSleep() {
        isSuspended = true
        cancelAndDismissIfShowing()
    }

    public func handleSystemWake() {
        isSuspended = false
        if isPaused {
            resume()
        } else {
            scheduleNextBreak()
        }
    }

    public func handleScreenLock() {
        isSuspended = true
        cancelAndDismissIfShowing()
    }

    public func handleScreenUnlock() {
        isSuspended = false
        if isPaused {
            resume()
        } else {
            scheduleNextBreak()
        }
    }

    private func cancelAndDismissIfShowing() {
        breakTimer?.cancel()
        breakTimer = nil
        if locker.isShowing {
            locker.dismissOverlay()
            if var event = currentBreak {
                event.outcome = .skipped
                eventContinuation.yield(.breakSkipped(event))
                updateStatistics {
                    $0.breaksSkipped += 1
                    $0.currentStreak = 0
                }
            }
            currentBreak = nil
            currentSchedule = nil
        }
    }

    public func skipNextBreak() {
        breakTimer?.cancel()
        breakTimer = nil
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
        scheduleNextBreak()
    }

    public func skipActiveBreak() {
        guard var event = currentBreak else { return }
        event.outcome = .skipped
        if let scheduleID = currentBreak?.scheduleId {
            let maxTier = (currentSchedule?.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count ?? 5) - 1
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, maxTier)
        }
        locker.dismissOverlay()
        eventContinuation.yield(.breakSkipped(event))
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }

    public func escapeActiveBreak() {
        guard var event = currentBreak else { return }
        event.outcome = .escaped
        if let scheduleID = currentBreak?.scheduleId {
            let maxTier = (currentSchedule?.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count ?? 5) - 1
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, maxTier)
        }
        locker.dismissOverlay()
        eventContinuation.yield(.breakEscaped(event))
        updateStatistics {
            $0.breaksEscaped += 1
            $0.weeklyEscapeCount += 1
        }
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }

    public func completeActiveBreak() {
        guard let event = currentBreak, let schedule = currentSchedule else { return }
        completeBreak(event: event, schedule: schedule)
    }

    public func changeDisciplineLevel(_ level: DisciplineLevel) {
        for i in activeSchedules.indices {
            activeSchedules[i].disciplineLevel = level
        }
    }

    public func updatePreferences(_ preferences: AppPreferences) {
        self.preferences = preferences
    }

    // MARK: - Escalation

    private func currentTier(for schedule: Schedule) -> Int {
        guard schedule.progressiveEnforcement else { return 0 }
        let maxTier = schedule.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count - 1
        return min(escalationTiers[schedule.id, default: 0], maxTier)
    }

    // MARK: - Private

    /// `now` governs both the rollover check and the search for the next break, so an injected
    /// date describes one consistent moment. Without it the rollover here would re-read the real
    /// clock and undo a caller-injected day change, since `resetDailyIfNeeded` fires in both
    /// directions.
    private func scheduleNextBreak(now: Date = Date()) {
        breakTimer?.cancel()
        breakTimer = nil
        rolloverIfNeeded(now: now)
        guard !isPaused else { return }

        var earliest: (date: Date, schedule: Schedule)?
        for schedule in activeSchedules where schedule.isEnabled {
            if let cap = schedule.dailyBreakCap,
               (dailyBreakCounts[schedule.id] ?? 0) >= cap { continue }
            if let next = scheduler.nextBreakTime(for: schedule, after: now) {
                if earliest == nil || next < earliest!.date {
                    earliest = (next, schedule)
                }
            }
        }

        guard let target = earliest else { return }
        eventContinuation.yield(.nextBreakScheduled(target.date))

        breakTimer = Task {
            let delay = target.date.timeIntervalSince(Date())
            let leadTime: TimeInterval = 3
            let earlyDelay = max(0, delay - leadTime)
            if earlyDelay > 0 { try? await Task.sleep(for: .seconds(earlyDelay)) }
            guard !Task.isCancelled else { return }
            let context = await self.detector.currentContext()
            let remaining = target.date.timeIntervalSince(Date())
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            await self.triggerBreak(for: target.schedule, context: context)
        }
    }

    private func triggerBreak(for schedule: Schedule) async {
        let context = await detector.currentContext()
        await triggerBreak(for: schedule, context: context)
    }

    private func triggerBreak(for schedule: Schedule, context: DetectionContext) async {
        rolloverIfNeeded()
        if preferences.idleDetectionEnabled {
            let breakDuration = currentBreakDuration(for: schedule)
            if context.idleDuration >= breakDuration {
                let idleEvent = BreakEvent(
                    scheduledAt: Date(), duration: breakDuration,
                    level: schedule.disciplineLevel, scheduleId: schedule.id,
                    outcome: .idleCounted
                )
                if var tracker = repetitionTrackers[schedule.id] {
                    tracker.recordBreak()
                    repetitionTrackers[schedule.id] = tracker
                }
                dailyBreakCounts[schedule.id, default: 0] += 1
                escalationTiers[schedule.id] = 0
                eventContinuation.yield(.breakCompleted(idleEvent))
                updateStatistics {
                    $0.breaksCompleted += 1
                    $0.currentStreak += 1
                }
                scheduleNextBreak()
                return
            }
        }

        if let deferral = shouldDefer(context: context) {
            eventContinuation.yield(.breakDeferred(deferral, nextAttempt: Date().addingTimeInterval(deferralPollingInterval)))
            updateStatistics { $0.breaksDeferred += 1 }
            breakTimer = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(self.deferralPollingInterval))
                    guard !Task.isCancelled else { return }
                    let freshContext = await self.detector.currentContext()
                    if let newReason = self.shouldDefer(context: freshContext) {
                        self.eventContinuation.yield(.breakDeferred(newReason, nextAttempt: Date().addingTimeInterval(self.deferralPollingInterval)))
                    } else if self.shouldSkipAfterDeferral(reason: deferral) {
                        self.scheduleNextBreak()
                        return
                    } else {
                        await self.triggerBreak(for: schedule, context: freshContext)
                        return
                    }
                }
            }
            return
        }

        var effectiveLevel = schedule.disciplineLevel
        if let reduction = shouldReduce(context: context) {
            effectiveLevel = reduction
        }

        let duration = currentBreakDuration(for: schedule)
        let exercise = exercises.randomElement()
        let tier = currentTier(for: schedule)
        let breakEvent = BreakEvent(
            scheduledAt: Date(), duration: duration,
            level: effectiveLevel, scheduleId: schedule.id
        )
        currentBreak = breakEvent
        currentSchedule = schedule
        dailyBreakCounts[schedule.id, default: 0] += 1

        eventContinuation.yield(.breakStarted(breakEvent))
        locker.showOverlay(level: effectiveLevel, duration: duration,
                           exercise: exercise, preferences: preferences,
                           statistics: statistics, escalationTier: tier)
    }

    private func currentBreakDuration(for schedule: Schedule) -> TimeInterval {
        if let tracker = repetitionTrackers[schedule.id] {
            return tracker.currentDuration
        }
        return schedule.breakDuration
    }

    private func shouldDefer(context: DetectionContext) -> DeferralReason? {
        if context.cameraActive && preferences.cameraDetection == .deferBreak { return .cameraActive }
        if context.microphoneActive && preferences.microphoneDetection == .deferBreak { return .microphoneActive }
        if context.calendarEventActive && preferences.calendarDetectionEnabled { return .calendarEvent }
        if context.screenSharingActive && preferences.screenSharingDetectionEnabled { return .screenSharing }
        if context.focusModeActive && preferences.focusModeDetection == .deferBreak { return .focusMode }
        return nil
    }

    private func shouldSkipAfterDeferral(reason: DeferralReason) -> Bool {
        reason == .screenSharing && preferences.screenSharingPostDeferral == .skipBreak
    }

    private func shouldReduce(context: DetectionContext) -> DisciplineLevel? {
        if context.cameraActive && preferences.cameraDetection == .reduceToGentle { return .gentle }
        if context.microphoneActive && preferences.microphoneDetection == .reduceToGentle { return .gentle }
        if context.focusModeActive && preferences.focusModeDetection == .reduceToGentle { return .gentle }
        return nil
    }

    private func completeBreak(event: BreakEvent, schedule: Schedule) {
        var completed = event
        completed.outcome = .completed
        escalationTiers[schedule.id] = 0
        locker.dismissOverlay()
        if var tracker = repetitionTrackers[schedule.id] {
            tracker.recordBreak()
            repetitionTrackers[schedule.id] = tracker
        }
        eventContinuation.yield(.breakCompleted(completed))
        updateStatistics {
            $0.breaksCompleted += 1
            $0.currentStreak += 1
        }
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }
}

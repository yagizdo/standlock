import Foundation
import StandLockCore
import Scheduling
import Detection
import Locking

/// Per-schedule counters that have to outlive a coordinator rebuild. Editing a schedule tears
/// the coordinator down and builds a new one, and every counter here lives on the instance: a
/// fresh one re-arms `dailyBreakCap` from zero, sends `intervalCycle` back to its first entry,
/// drops progressive enforcement to the base tier and forgets how far into the short-break run
/// the user was. A day change still clears all of it, in `rolloverIfNeeded`.
public struct EnforcementState: Sendable {
    public var dailyBreakCounts: [UUID: Int]
    public var escalationTiers: [UUID: Int]
    public var cycleIndices: [UUID: Int]
    public var repetitionIndices: [UUID: Int]
    /// The slot the outgoing coordinator had armed, with the schedule it belongs to. The
    /// interval is measured from whenever the rebuilt coordinator starts, so without this any
    /// restart -- a schedule edit, a Strict permission reading that flaps -- pushes the break
    /// out by however far into the interval the user already was. The id travels with the date
    /// because the slot decides which schedule's break fires, not only when.
    public var pendingBreakScheduleID: UUID?
    public var pendingBreakDate: Date?

    public init(dailyBreakCounts: [UUID: Int] = [:], escalationTiers: [UUID: Int] = [:],
                cycleIndices: [UUID: Int] = [:], repetitionIndices: [UUID: Int] = [:],
                pendingBreakScheduleID: UUID? = nil, pendingBreakDate: Date? = nil) {
        self.dailyBreakCounts = dailyBreakCounts
        self.escalationTiers = escalationTiers
        self.cycleIndices = cycleIndices
        self.repetitionIndices = repetitionIndices
        self.pendingBreakScheduleID = pendingBreakScheduleID
        self.pendingBreakDate = pendingBreakDate
    }
}

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
    private var cycleIndices: [UUID: Int] = [:]
    /// Which schedule the armed break timer targets. A menu skip of a not-yet-fired break has
    /// to advance that schedule's cycle; cleared whenever the timer is cancelled or the break
    /// becomes active, so a slot can never advance twice.
    private var pendingBreakScheduleID: UUID?
    /// When the pending slot is due. Kept so a skip that is not allowed to reset the interval
    /// can measure the next one from the slot it skipped instead of from the moment of the skip.
    private var pendingBreakDate: Date?
    /// True only while the deferral poll loop owns `breakTimer`. That loop is suspended between
    /// polls, so anything that re-arms the timer cancels it and drops the deferred break.
    private var isDeferringBreak = false
    /// A slot carried in from the coordinator this one replaces, consumed by the first
    /// `scheduleNextBreak` after `start`. Kept apart from `pendingBreakDate` so it can re-arm
    /// once and only once: a slot left in play would pin every later break to the same date.
    private var restoredPendingBreak: (scheduleID: UUID, date: Date)?
    public var exercises: [Exercise] = []

    /// Floor between a skip and the break it schedules, for the case where the anchored slot
    /// has already gone by.
    private static let minimumLeadTime: TimeInterval = 60

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
                      statistics: BreakStatistics = BreakStatistics(),
                      restoring state: EnforcementState = EnforcementState()) {
        self.activeSchedules = schedules
        self.preferences = preferences
        self.statistics = statistics
        dailyBreakCounts = state.dailyBreakCounts
        escalationTiers = state.escalationTiers
        cycleIndices = state.cycleIndices
        for schedule in schedules {
            if let rule = schedule.repetitionRule {
                repetitionTrackers[schedule.id] = RepetitionTracker(
                    rule: rule, currentBreakIndex: state.repetitionIndices[schedule.id] ?? 0
                )
            }
        }
        if let id = state.pendingBreakScheduleID, let date = state.pendingBreakDate {
            restoredPendingBreak = (id, date)
        }
        scheduleNextBreak()
    }

    /// Read this before `stop()`, which clears `escalationTiers` on its way out.
    public func captureEnforcementState() -> EnforcementState {
        EnforcementState(
            dailyBreakCounts: dailyBreakCounts,
            escalationTiers: escalationTiers,
            cycleIndices: cycleIndices,
            repetitionIndices: repetitionTrackers.mapValues(\.currentBreakIndex),
            pendingBreakScheduleID: pendingBreakScheduleID,
            pendingBreakDate: pendingBreakDate
        )
    }

    public func stop() {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        if locker.isShowing { locker.dismissOverlay() }
        currentBreak = nil
        currentSchedule = nil
        escalationTiers.removeAll()
    }

    public func pause(for duration: TimeInterval) {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
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
        // Re-arm on every rollover: a schedule that exhausted its daily cap left no timer
        // behind, and a timer armed before midnight was computed from the old day's cycle
        // index -- the new day's first break must come from index 0 (scheduleNextBreak
        // cancels any pending timer itself). Nothing may be armed behind a locked or
        // sleeping screen, while paused the timer holds the resume task, and re-arming
        // during a deferral would cancel the poll loop and lose the deferred break.
        if !isPaused && !isSuspended && !isDeferringBreak {
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
        // Every day starts the interval cycle from its first entry.
        cycleIndices.removeAll()
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
        clearPendingBreak()
        if locker.isShowing {
            locker.dismissOverlay()
            if let event = currentBreak {
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
        if let id = pendingBreakScheduleID {
            cycleIndices[id, default: 0] += 1
        }
        let anchor = skipAnchor(slot: pendingBreakDate)
        clearPendingBreak()
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
        scheduleNextBreak(searchFrom: anchor)
    }

    public func skipActiveBreak() {
        guard let event = currentBreak else { return }
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
        let anchor = skipAnchor(slot: event.scheduledAt)
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak(searchFrom: anchor)
    }

    public func escapeActiveBreak() {
        guard let event = currentBreak else { return }
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

    /// Nil keeps the default `now` anchor. A slot date is returned only when the user has turned
    /// off `resetIntervalOnSkip`, which is what makes a skip cost the time it saved.
    private func skipAnchor(slot: Date?) -> Date? {
        preferences.resetIntervalOnSkip ? nil : slot
    }

    private func currentTier(for schedule: Schedule) -> Int {
        guard schedule.progressiveEnforcement else { return 0 }
        let maxTier = schedule.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count - 1
        return min(escalationTiers[schedule.id, default: 0], maxTier)
    }

    // MARK: - Private

    /// The pending slot and the deferral flag always end together: whoever concludes a slot
    /// concludes the poll that was waiting on it.
    private func clearPendingBreak() {
        pendingBreakScheduleID = nil
        pendingBreakDate = nil
        isDeferringBreak = false
    }

    private func isCapReached(_ schedule: Schedule) -> Bool {
        guard let cap = schedule.dailyBreakCap else { return false }
        return (dailyBreakCounts[schedule.id] ?? 0) >= cap
    }

    /// `now` governs both the rollover check and the search for the next break, so an injected
    /// date describes one consistent moment. Without it the rollover here would re-read the real
    /// clock and undo a caller-injected day change, since `resetDailyIfNeeded` fires in both
    /// directions.
    /// `searchFrom` is the moment the next interval is measured from. It differs from `now` only
    /// when `resetIntervalOnSkip` is off, where the skipped slot stays the anchor so a skip
    /// neither buys work time nor pulls the next break closer.
    private func scheduleNextBreak(now: Date = Date(), searchFrom: Date? = nil) {
        breakTimer?.cancel()
        breakTimer = nil
        rolloverIfNeeded(now: now)
        guard !isPaused else { return }

        var earliest: (date: Date, schedule: Schedule)?
        // The carried slot competes with the freshly computed ones instead of overriding them,
        // so a schedule whose interval the user just shortened still wins with its earlier date.
        // A slot already in the past is dropped: it belongs to a gap the coordinator sat out --
        // every schedule disabled, then re-enabled -- and re-arming it would fire on the spot.
        if let restored = restoredPendingBreak {
            restoredPendingBreak = nil
            if restored.date > now,
               let schedule = activeSchedules.first(where: {
                   $0.id == restored.scheduleID && $0.isEnabled
               }), !isCapReached(schedule) {
                earliest = (restored.date, schedule)
            }
        }
        for schedule in activeSchedules where schedule.isEnabled {
            if isCapReached(schedule) { continue }
            if let next = scheduler.nextBreakTime(for: schedule, after: searchFrom ?? now,
                                                  cycleIndex: cycleIndices[schedule.id, default: 0]) {
                if earliest == nil || next < earliest!.date {
                    earliest = (next, schedule)
                }
            }
        }

        guard let target = earliest else { return }
        // An anchored slot can already have gone by; a break must never open right on top of the
        // skip that scheduled it. The unanchored path keeps its exact slot, short ones included.
        let fireDate = searchFrom == nil
            ? target.date
            : max(target.date, now.addingTimeInterval(Self.minimumLeadTime))
        pendingBreakScheduleID = target.schedule.id
        pendingBreakDate = fireDate
        eventContinuation.yield(.nextBreakScheduled(fireDate))

        breakTimer = Task {
            let delay = fireDate.timeIntervalSince(Date())
            let leadTime: TimeInterval = 3
            let earlyDelay = max(0, delay - leadTime)
            if earlyDelay > 0 { try? await Task.sleep(for: .seconds(earlyDelay)) }
            guard !Task.isCancelled else { return }
            let context = await self.detector.currentContext()
            let remaining = fireDate.timeIntervalSince(Date())
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            await self.triggerBreak(for: target.schedule, context: context)
        }
    }

    private func triggerBreak(for schedule: Schedule, context: DetectionContext) async {
        // The pending break is now active; a menu skip from here on must not advance again.
        clearPendingBreak()
        rolloverIfNeeded()
        if preferences.idleDetectionEnabled {
            let breakDuration = currentBreakDuration(for: schedule)
            if context.idleDuration >= breakDuration {
                let idleEvent = BreakEvent(
                    scheduledAt: Date(), duration: breakDuration,
                    level: schedule.disciplineLevel, scheduleId: schedule.id
                )
                if var tracker = repetitionTrackers[schedule.id] {
                    tracker.recordBreak()
                    repetitionTrackers[schedule.id] = tracker
                }
                dailyBreakCounts[schedule.id, default: 0] += 1
                cycleIndices[schedule.id, default: 0] += 1
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
            // The deferred slot is still pending, so a menu skip during the poll loop
            // must conclude it for this schedule.
            pendingBreakScheduleID = schedule.id
            pendingBreakDate = Date()
            isDeferringBreak = true
            eventContinuation.yield(.breakDeferred(deferral, nextAttempt: Date().addingTimeInterval(deferralPollingInterval)))
            updateStatistics { $0.breaksDeferred += 1 }
            breakTimer = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(self.deferralPollingInterval))
                    guard !Task.isCancelled else { return }
                    let freshContext = await self.detector.currentContext()
                    // Cancellation does not interrupt the await above, so re-check before
                    // mutating: a menu skip during it already concluded this slot.
                    guard !Task.isCancelled else { return }
                    if let newReason = self.shouldDefer(context: freshContext) {
                        self.eventContinuation.yield(.breakDeferred(newReason, nextAttempt: Date().addingTimeInterval(self.deferralPollingInterval)))
                    } else if self.shouldSkipAfterDeferral(reason: deferral) {
                        self.cycleIndices[schedule.id, default: 0] += 1
                        self.clearPendingBreak()
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
        cycleIndices[schedule.id, default: 0] += 1

        eventContinuation.yield(.breakStarted(breakEvent))
        locker.showOverlay(level: effectiveLevel, duration: duration,
                           exercise: exercise, preferences: preferences,
                           statistics: statistics, escalationTier: tier,
                           nextIntervalLabel: nextIntervalLabel(for: schedule))
    }

    /// The cycle index was already advanced when this break triggered, so it points at the
    /// upcoming work block.
    private func nextIntervalLabel(for schedule: Schedule) -> String? {
        guard let cycle = schedule.intervalCycle, !cycle.isEmpty else { return nil }
        return cycle[cycleIndices[schedule.id, default: 0] % cycle.count].label
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
        return nil
    }

    private func shouldSkipAfterDeferral(reason: DeferralReason) -> Bool {
        reason == .screenSharing && preferences.screenSharingPostDeferral == .skipBreak
    }

    private func shouldReduce(context: DetectionContext) -> DisciplineLevel? {
        if context.cameraActive && preferences.cameraDetection == .reduceToGentle { return .gentle }
        if context.microphoneActive && preferences.microphoneDetection == .reduceToGentle { return .gentle }
        return nil
    }

    private func completeBreak(event: BreakEvent, schedule: Schedule) {
        escalationTiers[schedule.id] = 0
        locker.dismissOverlay()
        if var tracker = repetitionTrackers[schedule.id] {
            tracker.recordBreak()
            repetitionTrackers[schedule.id] = tracker
        }
        eventContinuation.yield(.breakCompleted(event))
        updateStatistics {
            $0.breaksCompleted += 1
            $0.currentStreak += 1
        }
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }
}

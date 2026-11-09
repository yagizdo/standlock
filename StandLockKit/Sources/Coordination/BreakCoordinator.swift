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
    private let clock: CoordinatorClock

    private var activeSchedules: [Schedule] = []
    private var preferences: AppPreferences = AppPreferences()
    private var repetitionTrackers: [UUID: RepetitionTracker] = [:]
    private var breakTimer: Task<Void, Never>?
    private var isPaused: Bool = false
    /// Set while the screen is locked or the machine is asleep. Distinct from `isPaused`, which
    /// is the user-facing pause; suspension only blocks work being started behind a dark screen.
    private var isSuspended: Bool { awayTracker.isAway }
    private var awayTracker = AwaySessionTracker()
    private var awayRemainingWork: [UUID: TimeInterval] = [:]
    private var awayOwnerID: UUID?
    private var pendingDates: [UUID: Date] = [:]
    private var consecutiveDismissalCounts: [UUID: Int] = [:]
    private var activeDeadline: TimeInterval?
    private var activeRestStartedAt: TimeInterval?
    /// Interrupted rest segments do not accumulate across periods with the overlay hidden.
    private var longestActiveRest: TimeInterval = 0
    private var currentExercise: Exercise?
    private var completionTimer: Task<Void, Never>?
    private var pauseTimer: Task<Void, Never>?
    private var pauseDeadline: Date?
    private var resumedDeferredScheduleID: UUID?
    public private(set) var pendingSlotID: UUID?
    private var currentBreak: BreakEvent?
    private var currentSchedule: Schedule?
    /// A break may be postponed once; the one that comes back after the call cannot be again.
    private var activeBreakCanPostpone = false
    /// The break owed after a postpone, until it returns. The wait itself lives in `breakTimer`,
    /// which lock, sleep and pause cancel; this is what lets them start it again.
    private var postponedSchedule: Schedule?
    private var postponedBreak: BreakEvent?
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
    private var restoredPendingBreaks: [UUID: Date] = [:]
    /// Carried slots of schedules this coordinator was not given, handed on untouched by
    /// `captureEnforcementState` so they are still there when the schedule is switched back on.
    private var dormantPendingBreaks: [UUID: Date] = [:]
    /// A carried postponed break whose schedule this coordinator was not given, handed on the
    /// same way as `dormantPendingBreaks`.
    private var dormantPostponedScheduleID: UUID?
    public var exercises: [Exercise] = []

    /// Floor between a skip and the break it schedules, for the case where the anchored slot
    /// has already gone by.
    private static let minimumLeadTime: TimeInterval = 60

    private let deferralPollingInterval: TimeInterval
    /// How long before a break `.breakCue(.approaching)` plays.
    private let cueLead: TimeInterval
    private let eventContinuation: AsyncStream<CoordinatorEvent>.Continuation
    public nonisolated let events: AsyncStream<CoordinatorEvent>

    public init(scheduler: any SchedulingEngine, detector: any ContextDetecting,
                locker: any LockPresenting, deferralPollingInterval: TimeInterval = 10,
                cueLead: TimeInterval = 60, clock: CoordinatorClock = .live) {
        var continuation: AsyncStream<CoordinatorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
        self.clock = clock
        self.scheduler = scheduler
        self.detector = detector
        self.locker = locker
        self.deferralPollingInterval = deferralPollingInterval
        self.cueLead = cueLead
    }

    /// Pass previously persisted `statistics` so a relaunch during the day keeps today's
    /// counters instead of restarting them from zero.
    public func start(with schedules: [Schedule], preferences: AppPreferences,
                      statistics: BreakStatistics? = nil,
                      restoring state: EnforcementState = EnforcementState()) {
        self.activeSchedules = schedules
        self.preferences = preferences
        self.statistics = statistics ?? BreakStatistics(date: clock.now())
        consecutiveDismissalCounts = state.consecutiveDismissalCounts
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
        restoredPendingBreaks = state.pendingBreakDates
        if let id = state.postponedScheduleID {
            if let schedule = schedules.first(where: { $0.id == id && $0.isEnabled }) {
                postponedSchedule = schedule
                eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: clock.now().addingTimeInterval(deferralPollingInterval)))
            } else {
                dormantPostponedScheduleID = id
            }
        }
        if let runtime = state.runtime {
            awayTracker = runtime.awayTracker
            awayRemainingWork = runtime.remainingWork
            awayOwnerID = runtime.awayOwnerID
            currentBreak = runtime.activeBreak
            currentSchedule = schedules.first { $0.id == runtime.activeScheduleID }
            if currentSchedule == nil { currentBreak = nil }
            activeDeadline = runtime.activeDeadline
            activeRestStartedAt = currentBreak == nil ? nil : runtime.activeRestStartedAt
            longestActiveRest = currentBreak == nil ? 0 : runtime.longestActiveRest
            currentExercise = runtime.exercise
            activeBreakCanPostpone = runtime.canPostpone
            postponedBreak = runtime.postponedBreak
            resumedDeferredScheduleID = runtime.deferredScheduleID
            if let deadline = runtime.pauseDeadline, deadline > clock.now() {
                restorePause(until: deadline)
            }
        }
        rearm()
    }

    /// Read this before `stop()`, which clears `escalationTiers` on its way out.
    public func captureEnforcementState() -> EnforcementState {
        // A restored postponed break skips `scheduleNextBreak`, so restored slots can still be unconsumed.
        var pendingBreakDates = dormantPendingBreaks.merging(restoredPendingBreaks) { current, _ in current }
        pendingBreakDates.merge(pendingDates) { _, next in next }
        if let id = pendingBreakScheduleID, let date = pendingBreakDate {
            pendingBreakDates[id] = date
        }
        var state = EnforcementState(
            dailyBreakCounts: dailyBreakCounts,
            escalationTiers: escalationTiers,
            cycleIndices: cycleIndices,
            repetitionIndices: repetitionTrackers.mapValues(\.currentBreakIndex),
            pendingBreakDates: pendingBreakDates,
            postponedScheduleID: postponedSchedule?.id ?? dormantPostponedScheduleID,
            consecutiveDismissalCounts: consecutiveDismissalCounts
        )
        state.runtime = CoordinatorRuntimeState(
            awayTracker: awayTracker, remainingWork: awayRemainingWork, awayOwnerID: awayOwnerID,
            activeBreak: currentBreak, activeScheduleID: currentSchedule?.id,
            activeDeadline: activeDeadline, activeRestStartedAt: activeRestStartedAt,
            longestActiveRest: longestActiveRest,
            exercise: currentExercise, canPostpone: activeBreakCanPostpone,
            postponedBreak: postponedBreak, pauseDeadline: pauseDeadline,
            deferredScheduleID: isDeferringBreak ? pendingBreakScheduleID : resumedDeferredScheduleID
        )
        return state
    }

    public func stop() {
        completionTimer?.cancel()
        pauseTimer?.cancel()
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        postponedSchedule = nil
        if locker.isShowing { locker.dismissOverlay() }
        currentBreak = nil
        currentSchedule = nil
        activeRestStartedAt = nil
        longestActiveRest = 0
        escalationTiers.removeAll()
    }

    public func pause(for duration: TimeInterval) {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        restorePause(until: clock.now().addingTimeInterval(duration))
        stateChanged()
    }

    private func restorePause(until deadline: Date) {
        pauseTimer?.cancel()
        isPaused = true
        pauseDeadline = deadline
        eventContinuation.yield(.schedulePaused(until: deadline))
        pauseTimer = Task {
            do { try await self.clock.sleep(max(0, deadline.timeIntervalSince(self.clock.now()))) }
            catch { return }
            guard !Task.isCancelled else { return }
            self.resume()
        }
    }

    public func resume() {
        pauseTimer?.cancel()
        pauseTimer = nil
        pauseDeadline = nil
        isPaused = false
        eventContinuation.yield(.scheduleResumed)
        rearm()
        stateChanged()
    }

    /// Rolls the daily counters over when the calendar day has changed. Safe to call often --
    /// it is a no-op while the recorded day is still the current one.
    public func refreshDailyRollover(now: Date? = nil) {
        let now = now ?? clock.now()
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
    private func rolloverIfNeeded(now: Date? = nil) -> Bool {
        let now = now ?? clock.now()
        guard statistics.resetDailyIfNeeded(currentDate: now) else { return false }
        statistics.resetWeeklyIfNeeded(currentDate: now)
        dailyBreakCounts.removeAll()
        // Progressive enforcement escalates within a day; a new day starts from the base tier.
        escalationTiers.removeAll()
        // Every day starts the interval cycle from its first entry.
        cycleIndices.removeAll()
        eventContinuation.yield(.statisticsUpdated(statistics))
        if let schedule = currentSchedule {
            locker.updateDismissalAvailability(availability(for: schedule))
        }
        stateChanged()
        return true
    }

    private func updateStatistics(_ mutate: (inout BreakStatistics) -> Void) {
        rolloverIfNeeded()
        mutate(&statistics)
        eventContinuation.yield(.statisticsUpdated(statistics))
        stateChanged()
    }

    public func handleSystemSleep() { setAway(.sleeping, active: true) }
    public func handleSystemWake() { setAway(.sleeping, active: false) }
    public func handleScreenLock() { setAway(.locked, active: true) }
    public func handleScreenUnlock() { setAway(.locked, active: false) }

    private func setAway(_ reason: AwaySessionTracker.Reason, active: Bool) {
        guard let transition = awayTracker.set(reason, active: active, at: clock.elapsed()) else { return }
        switch transition {
        case .departed:
            let now = clock.now()
            awayRemainingWork = pendingDates.mapValues { max(0, $0.timeIntervalSince(now)) }
            awayOwnerID = currentSchedule?.id ?? postponedSchedule?.id
            if awayOwnerID == nil, let id = pendingBreakScheduleID,
               let schedule = activeSchedules.first(where: { $0.id == id }),
               scheduler.isWithinActiveWindow(schedule, at: now), !isCapReached(schedule) {
                awayOwnerID = id
            }
            resumedDeferredScheduleID = isDeferringBreak ? pendingBreakScheduleID : nil
            breakTimer?.cancel()
            breakTimer = nil
            completionTimer?.cancel()
            if locker.isShowing { locker.dismissOverlay() }
            eventContinuation.yield(.systemSuspensionChanged(true))
        case .returned(let duration):
            rolloverIfNeeded()
            eventContinuation.yield(.systemSuspensionChanged(false))
            let restDuration = currentBreak == nil ? duration : max(longestActiveRest,
                activeRestStartedAt.map { max(0, clock.elapsed() - $0) } ?? duration)
            let qualifies = duration >= TimeInterval(min(30, max(1, preferences.naturalBreakThresholdMinutes)) * 60)
            if qualifies {
                escalationTiers.removeAll()
                consecutiveDismissalCounts.removeAll()
                if let event = currentBreak, let schedule = currentSchedule {
                    finishBreak(event: event, schedule: schedule, playSound: false, restDuration: restDuration)
                } else if let id = awayOwnerID,
                          let schedule = activeSchedules.first(where: { $0.id == id }) {
                    if postponedSchedule == nil {
                        dailyBreakCounts[id, default: 0] += 1
                        cycleIndices[id, default: 0] += 1
                    }
                    let event = postponedBreak.flatMap { $0.scheduleId == id ? $0 : nil }
                        ?? BreakEvent(scheduledAt: clock.now(),
                        duration: currentBreakDuration(for: schedule), level: schedule.disciplineLevel, scheduleId: id)
                    finishBreak(event: event, schedule: schedule, playSound: false, restDuration: restDuration)
                }
                postponedSchedule = nil
                postponedBreak = nil
                dormantPostponedScheduleID = nil
                restoredPendingBreaks = [:]
                dormantPendingBreaks = [:]
                resumedDeferredScheduleID = nil
                clearPendingBreak()
            } else {
                restoredPendingBreaks = awayRemainingWork.mapValues {
                    clock.now().addingTimeInterval(max(0.001, $0))
                }
            }
            awayRemainingWork = [:]
            awayOwnerID = nil
            recordObservedLongRest(duration: restDuration)
            if isPaused, currentBreak != nil {
                longestActiveRest = max(longestActiveRest, restDuration)
                activeRestStartedAt = nil
            }
            rearm()
        }
        stateChanged()
    }

    public var canSkipNextBreak: Bool {
        guard !isSuspended, !isPaused, currentBreak == nil, let schedule = pendingSkipSchedule else { return false }
        return availability(for: schedule).normalSkipAllowed
    }

    private var pendingSkipSchedule: Schedule? {
        if let postponedSchedule { return postponedSchedule }
        return activeSchedules.first { $0.id == pendingBreakScheduleID && $0.isEnabled }
    }

    private func availability(for schedule: Schedule) -> DismissalAvailability {
        DismissalAvailability(progressiveEnforcement: schedule.progressiveEnforcement,
            consecutiveSkipLimit: schedule.consecutiveSkipLimit,
            consecutiveDismissals: consecutiveDismissalCounts[schedule.id, default: 0],
            dailySkipLimit: schedule.disciplineLevel.dailySkipLimit(preferences: preferences),
            dailySkips: statistics.breaksSkipped)
    }

    private func recordDismissal(for schedule: Schedule) {
        consecutiveDismissalCounts[schedule.id] = min(20, consecutiveDismissalCounts[schedule.id, default: 0] + 1)
        let maxTier = schedule.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count - 1
        escalationTiers[schedule.id] = min(escalationTiers[schedule.id, default: 0] + 1, maxTier)
    }

    private func stateChanged() {
        eventContinuation.yield(.enforcementStateChanged)
    }

    public func skipNextBreak(expectedSlotID: UUID? = nil) {
        rolloverIfNeeded()
        guard expectedSlotID == nil || expectedSlotID == pendingSlotID,
              canSkipNextBreak, let schedule = pendingSkipSchedule else { return }
        recordDismissal(for: schedule)
        breakTimer?.cancel()
        breakTimer = nil
        if let id = pendingBreakScheduleID {
            cycleIndices[id, default: 0] += 1
        }
        let anchor = skipAnchor(slot: pendingBreakDate)
        clearPendingBreak()
        postponedSchedule = nil
        postponedBreak = nil
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
        scheduleNextBreak(searchFrom: anchor)
    }

    public func skipActiveBreak(expectedBreakID: UUID? = nil) {
        rolloverIfNeeded()
        guard let event = currentBreak, let schedule = currentSchedule, !isSuspended,
              expectedBreakID == nil || expectedBreakID == event.id,
              availability(for: schedule).normalSkipAllowed else { return }
        recordDismissal(for: schedule)
        completionTimer?.cancel()
        locker.dismissOverlay()
        eventContinuation.yield(.breakSkipped(event))
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
        let anchor = skipAnchor(slot: event.scheduledAt)
        currentBreak = nil
        currentSchedule = nil
        activeRestStartedAt = nil
        longestActiveRest = 0
        scheduleNextBreak(searchFrom: anchor)
    }

    public func escapeActiveBreak(expectedBreakID: UUID? = nil) {
        rolloverIfNeeded()
        guard let event = currentBreak, let schedule = currentSchedule, !isSuspended,
              expectedBreakID == nil || expectedBreakID == event.id,
              availability(for: schedule).emergencyEscapeAllowed else { return }
        recordDismissal(for: schedule)
        completionTimer?.cancel()
        locker.dismissOverlay()
        eventContinuation.yield(.breakEscaped(event))
        updateStatistics {
            $0.breaksEscaped += 1
            $0.weeklyEscapeCount += 1
        }
        currentBreak = nil
        currentSchedule = nil
        activeRestStartedAt = nil
        longestActiveRest = 0
        scheduleNextBreak()
    }

    /// Closes the break screen without counting a skip and brings the same break back, at full
    /// length, once camera and microphone have both been free for `postponeReturnDelay`. The
    /// wait ignores the detection preferences: postponing is the user saying they are on a call.
    public func postponeActiveBreak(expectedBreakID: UUID? = nil) {
        guard let event = currentBreak, let schedule = currentSchedule, activeBreakCanPostpone, !isSuspended,
              expectedBreakID == nil || expectedBreakID == event.id else { return }
        completionTimer?.cancel()
        postponedBreak = event
        pendingSlotID = UUID()
        breakTimer?.cancel()
        breakTimer = nil
        locker.dismissOverlay()
        currentBreak = nil
        currentSchedule = nil
        activeRestStartedAt = nil
        longestActiveRest = 0
        postponedSchedule = schedule
        eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: clock.now().addingTimeInterval(deferralPollingInterval)))
        updateStatistics { $0.breaksDeferred += 1 }
        startPostponeWait(for: schedule)
    }

    private func startPostponeWait(for schedule: Schedule) {
        breakTimer?.cancel()
        // Keeps `refreshDailyRollover` from re-arming over the wait. The pending slot stays nil:
        // `triggerBreak` already advanced the cycle, and a set ID would let a menu skip advance it again.
        isDeferringBreak = true
        breakTimer = Task {
            var clearSince: Date?
            while !Task.isCancelled {
                try? await self.clock.sleep(self.deferralPollingInterval)
                guard !Task.isCancelled else { return }
                guard !self.isSuspended, !self.isPaused,
                      let current = self.activeSchedules.first(where: { $0.id == schedule.id && $0.isEnabled }) else { return }
                guard self.scheduler.isWithinActiveWindow(current, at: self.clock.now()) else {
                    clearSince = nil
                    self.eventContinuation.yield(.breakDeferred(.postponed,
                        nextAttempt: self.clock.now().addingTimeInterval(self.deferralPollingInterval)))
                    continue
                }
                let context = await self.detector.currentContext()
                guard !Task.isCancelled else { return }
                if context.cameraActive || context.microphoneActive {
                    clearSince = nil
                    self.eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: clock.now().addingTimeInterval(self.deferralPollingInterval)))
                    continue
                }
                let since = clearSince ?? clock.now()
                if clearSince == nil {
                    // Lets the menu bar count down to the return instead of sitting at 0:00.
                    self.eventContinuation.yield(.nextBreakScheduled(since.addingTimeInterval(self.preferences.postponeReturnDelay)))
                }
                clearSince = since
                if clock.now().timeIntervalSince(since) >= self.preferences.postponeReturnDelay {
                    guard self.scheduler.isWithinActiveWindow(current, at: self.clock.now()) else {
                        clearSince = nil
                        continue
                    }
                    self.clearPendingBreak()
                    if self.presentBreak(for: current, context: context, canPostpone: false) {
                        self.postponedSchedule = nil
                        return
                    }
                }
            }
        }
    }

    public func completeActiveBreak(expectedBreakID: UUID? = nil) {
        guard let event = currentBreak, let schedule = currentSchedule, !isSuspended,
              expectedBreakID == nil || expectedBreakID == event.id else { return }
        completeBreak(event: event, schedule: schedule)
    }

    public func changeDisciplineLevel(_ level: DisciplineLevel) {
        for i in activeSchedules.indices {
            activeSchedules[i].disciplineLevel = level
        }
    }

    public func updatePreferences(_ preferences: AppPreferences) {
        self.preferences = preferences
        if let schedule = currentSchedule {
            locker.updateDismissalAvailability(availability(for: schedule))
        }
        stateChanged()
    }

    /// Enforcement edits affect existing controls without restarting the break or its challenges.
    public func updateEnforcementSettings(for schedule: Schedule) {
        guard let index = activeSchedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        activeSchedules[index].progressiveEnforcement = schedule.progressiveEnforcement
        activeSchedules[index].consecutiveSkipLimit = schedule.consecutiveSkipLimit
        if currentSchedule?.id == schedule.id {
            currentSchedule?.progressiveEnforcement = schedule.progressiveEnforcement
            currentSchedule?.consecutiveSkipLimit = schedule.consecutiveSkipLimit
            locker.updateDismissalAvailability(availability(for: activeSchedules[index]))
        }
        if postponedSchedule?.id == schedule.id {
            postponedSchedule?.progressiveEnforcement = schedule.progressiveEnforcement
            postponedSchedule?.consecutiveSkipLimit = schedule.consecutiveSkipLimit
        }
        stateChanged()
    }

    // MARK: - Escalation

    /// Nil keeps the default `now` anchor. A slot date is returned when the user has turned off
    /// `resetIntervalOnSkip`, which is what makes a skip cost the time it saved, and when a search
    /// from `now` cannot get past the slot: outside the schedule's hours, or too near their end,
    /// it lands on the same break, and the skip would count while the break stayed.
    private func skipAnchor(slot: Date?) -> Date? {
        guard let slot, preferences.resetIntervalOnSkip else { return slot }
        guard let schedule = activeSchedules.first(where: { $0.id == pendingBreakScheduleID }),
              let next = scheduler.nextBreakTime(
                for: schedule, after: clock.now(), cycleIndex: cycleIndices[schedule.id, default: 0]
              )
        else { return nil }
        return next <= slot ? slot : nil
    }

    private func currentTier(for schedule: Schedule) -> Int {
        guard schedule.progressiveEnforcement else { return 0 }
        let maxTier = schedule.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count - 1
        return min(escalationTiers[schedule.id, default: 0], maxTier)
    }

    // MARK: - Private

    private func rearm() {
        guard !isSuspended, !isPaused else { return }
        if let event = currentBreak, let schedule = currentSchedule {
            if (activeDeadline ?? clock.elapsed()) <= clock.elapsed() {
                completeBreak(event: event, schedule: schedule)
                return
            }
            guard schedule.isEnabled, scheduler.isWithinActiveWindow(schedule, at: clock.now()) else {
                currentBreak = nil
                currentSchedule = nil
                activeRestStartedAt = nil
                longestActiveRest = 0
                scheduleNextBreak()
                return
            }
            showCurrentBreak()
        } else if let schedule = postponedSchedule {
            startPostponeWait(for: schedule)
        } else if let id = resumedDeferredScheduleID,
                  let schedule = activeSchedules.first(where: { $0.id == id && $0.isEnabled }),
                  scheduler.isWithinActiveWindow(schedule, at: clock.now()) {
            resumedDeferredScheduleID = nil
            breakTimer = Task {
                let context = await self.detector.currentContext()
                guard !Task.isCancelled, !self.isSuspended else { return }
                await self.triggerBreak(for: schedule, context: context)
            }
        } else {
            scheduleNextBreak()
        }
    }

    /// The pending slot and the deferral flag always end together: whoever concludes a slot
    /// concludes the poll that was waiting on it.
    private func clearPendingBreak() {
        pendingBreakScheduleID = nil
        pendingBreakDate = nil
        pendingSlotID = nil
        pendingDates = [:]
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
    private func scheduleNextBreak(now: Date? = nil, searchFrom: Date? = nil) {
        let now = now ?? clock.now()
        breakTimer?.cancel()
        breakTimer = nil
        rolloverIfNeeded(now: now)
        guard !isPaused, !isSuspended, currentBreak == nil else { return }

        var earliest: (date: Date, schedule: Schedule)?
        pendingDates = [:]
        // Carried slots compete with the freshly computed ones instead of overriding them, so a
        // schedule whose interval the user just shortened still wins with its earlier date. A
        // slot already in the past is dropped: it belongs to a gap the coordinator sat out --
        // every schedule disabled, then re-enabled -- and re-arming it would fire on the spot.
        let restored = restoredPendingBreaks
        restoredPendingBreaks = [:]
        for (id, date) in restored where date > now {
            guard let schedule = activeSchedules.first(where: { $0.id == id && $0.isEnabled }) else {
                dormantPendingBreaks[id] = date
                continue
            }
            guard scheduler.isWithinActiveWindow(schedule, at: date) else { continue }
            pendingDates[id] = date
            if !isCapReached(schedule), earliest == nil || date < earliest!.date {
                earliest = (date, schedule)
            }
        }
        for schedule in activeSchedules where schedule.isEnabled {
            if isCapReached(schedule) { continue }
            if let next = scheduler.nextBreakTime(for: schedule, after: searchFrom ?? now,
                                                  cycleIndex: cycleIndices[schedule.id, default: 0]) {
                pendingDates[schedule.id] = min(pendingDates[schedule.id] ?? next, next)
                if earliest == nil || next < earliest!.date {
                    earliest = (next, schedule)
                }
            }
        }

        guard let target = earliest else {
            clearPendingBreak()
            stateChanged()
            return
        }
        // An anchored slot can already have gone by; a break must never open right on top of the
        // skip that scheduled it. The unanchored path keeps its exact slot, short ones included.
        let fireDate = searchFrom == nil
            ? target.date
            : max(target.date, now.addingTimeInterval(Self.minimumLeadTime))
        pendingSlotID = UUID()
        pendingBreakScheduleID = target.schedule.id
        pendingBreakDate = fireDate
        pendingDates[target.schedule.id] = fireDate
        stateChanged()
        eventContinuation.yield(.nextBreakScheduled(fireDate))

        breakTimer = Task {
            let untilCue = fireDate.timeIntervalSince(clock.now()) - self.cueLead
            if untilCue > 0 {
                try? await self.clock.sleep(untilCue)
                guard !Task.isCancelled else { return }
                await self.playApproachingCue()
                guard !Task.isCancelled else { return }
            }
            let delay = fireDate.timeIntervalSince(clock.now())
            let leadTime: TimeInterval = 3
            let earlyDelay = max(0, delay - leadTime)
            if earlyDelay > 0 { try? await self.clock.sleep(earlyDelay) }
            guard !Task.isCancelled else { return }
            let context = await self.detector.currentContext()
            let remaining = fireDate.timeIntervalSince(clock.now())
            if remaining > 0 { try? await self.clock.sleep(remaining) }
            guard !Task.isCancelled else { return }
            await self.triggerBreak(for: target.schedule, context: context)
        }
    }

    /// The preference is read here, not when the timer is armed: `updatePreferences` does not
    /// re-arm it. A cue for a break that will defer, or for someone who is away, would be a false alarm.
    private func playApproachingCue() async {
        guard preferences.soundBeforeBreak else { return }
        let context = await detector.currentContext()
        guard !Task.isCancelled, shouldDefer(context: context) == nil, context.idleDuration < cueLead else { return }
        eventContinuation.yield(.breakCue(.approaching))
    }

    private func triggerBreak(for schedule: Schedule, context: DetectionContext) async {
        guard !isSuspended, !isPaused, currentBreak == nil,
              let current = activeSchedules.first(where: { $0.id == schedule.id && $0.isEnabled }),
              scheduler.isWithinActiveWindow(current, at: clock.now()) else { return }
        let schedule = current
        // The pending break is now active; a menu skip from here on must not advance again.
        clearPendingBreak()
        rolloverIfNeeded()
        if let deferral = shouldDefer(context: context) {
            // The deferred slot is still pending, so a menu skip during the poll loop
            // must conclude it for this schedule.
            pendingSlotID = UUID()
            pendingBreakScheduleID = schedule.id
            pendingBreakDate = clock.now()
            pendingDates[schedule.id] = pendingBreakDate
            isDeferringBreak = true
            eventContinuation.yield(.breakDeferred(deferral, nextAttempt: clock.now().addingTimeInterval(deferralPollingInterval)))
            updateStatistics { $0.breaksDeferred += 1 }
            breakTimer = Task {
                while !Task.isCancelled {
                    try? await self.clock.sleep(self.deferralPollingInterval)
                    guard !Task.isCancelled else { return }
                    let freshContext = await self.detector.currentContext()
                    // Cancellation does not interrupt the await above, so re-check before
                    // mutating: a menu skip during it already concluded this slot.
                    guard !Task.isCancelled else { return }
                    if let newReason = self.shouldDefer(context: freshContext) {
                        self.eventContinuation.yield(.breakDeferred(newReason, nextAttempt: clock.now().addingTimeInterval(self.deferralPollingInterval)))
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

        dailyBreakCounts[schedule.id, default: 0] += 1
        cycleIndices[schedule.id, default: 0] += 1
        presentBreak(for: schedule, context: context, canPostpone: true)
    }

    /// Shows a break without counting it. A postponed break returns through here, so the daily
    /// count and the cycle advance only once, in `triggerBreak`.
    @discardableResult
    private func presentBreak(for schedule: Schedule, context: DetectionContext, canPostpone: Bool) -> Bool {
        guard !isSuspended, !isPaused,
              let current = activeSchedules.first(where: { $0.id == schedule.id && $0.isEnabled }),
              scheduler.isWithinActiveWindow(current, at: clock.now()) else { return false }
        let schedule = current
        var effectiveLevel = schedule.disciplineLevel
        if let reduction = shouldReduce(context: context) {
            effectiveLevel = reduction
        }

        let duration = currentBreakDuration(for: schedule)
        currentExercise = exercises.randomElement()
        let resumed = postponedBreak.flatMap { $0.scheduleId == schedule.id ? $0 : nil }
        let breakEvent = resumed ?? BreakEvent(
            scheduledAt: clock.now(), duration: duration,
            level: effectiveLevel, scheduleId: schedule.id
        )
        if resumed != nil { postponedBreak = nil }
        currentBreak = breakEvent
        activeRestStartedAt = clock.elapsed()
        longestActiveRest = 0
        activeDeadline = clock.elapsed() + duration
        currentSchedule = schedule
        activeBreakCanPostpone = canPostpone

        showCurrentBreak()
        return true
    }

    private func showCurrentBreak() {
        guard let event = currentBreak, let schedule = currentSchedule, let deadline = activeDeadline,
              !isSuspended, !isPaused else { return }
        if activeRestStartedAt == nil { activeRestStartedAt = clock.elapsed() }
        let remaining = min(event.duration, ceil(max(0, deadline - clock.elapsed())))
        // A permission-driven downgrade must also apply to a break restored during a rebuild.
        let level: DisciplineLevel
        switch (event.level, schedule.disciplineLevel) {
        case (.strict, .firm), (.strict, .gentle), (.firm, .gentle):
            level = schedule.disciplineLevel
        default:
            level = event.level
        }
        let displayEvent = BreakEvent(id: event.id, scheduledAt: event.scheduledAt, duration: remaining,
                                     level: level, scheduleId: event.scheduleId)
        eventContinuation.yield(.breakStarted(displayEvent))
        locker.showOverlay(level: level, duration: remaining,
            exercise: currentExercise, preferences: preferences,
            statistics: statistics, escalationTier: currentTier(for: schedule),
            nextIntervalLabel: nextIntervalLabel(for: schedule), canPostpone: activeBreakCanPostpone,
            breakID: event.id, dismissalAvailability: availability(for: schedule))
        completionTimer?.cancel()
        completionTimer = Task {
            do { try await self.clock.sleep(max(0, deadline - self.clock.elapsed())) }
            catch { return }
            guard !Task.isCancelled, !self.isSuspended, self.clock.elapsed() >= deadline else { return }
            self.completeActiveBreak(expectedBreakID: event.id)
        }
        stateChanged()
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
        finishBreak(event: event, schedule: schedule, playSound: true)
        scheduleNextBreak()
    }

    private func finishBreak(event: BreakEvent, schedule: Schedule, playSound: Bool,
                             restDuration: TimeInterval? = nil) {
        let completedDuration = restDuration ?? max(longestActiveRest,
            activeRestStartedAt.map { max(0, clock.elapsed() - $0) } ?? 0)
        completionTimer?.cancel()
        escalationTiers[schedule.id] = 0
        consecutiveDismissalCounts[schedule.id] = 0
        locker.dismissOverlay()
        currentBreak = nil
        currentSchedule = nil
        activeDeadline = nil
        activeRestStartedAt = nil
        longestActiveRest = 0
        if var tracker = repetitionTrackers[schedule.id] {
            tracker.recordBreak(duration: completedDuration)
            repetitionTrackers[schedule.id] = tracker
        }
        recordObservedLongRest(duration: completedDuration)
        eventContinuation.yield(.breakCompleted(event))
        if playSound && preferences.soundAfterBreak { eventContinuation.yield(.breakCue(.ended)) }
        updateStatistics {
            $0.breaksCompleted += 1
            $0.currentStreak += 1
        }
        stateChanged()
    }

    private func recordObservedLongRest(duration: TimeInterval) {
        for (id, var tracker) in repetitionTrackers {
            tracker.recordTimeAway(duration: duration)
            repetitionTrackers[id] = tracker
        }
    }
}

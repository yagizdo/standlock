import Foundation
import StandLockCore
import Scheduling
import Detection
import Locking

/// Per-schedule counters that have to outlive a coordinator rebuild. Editing a schedule tears
/// the coordinator down and builds a new one, and every counter here lives on the instance: a
/// fresh one re-arms `dailyBreakCap` from zero, sends `intervalCycle` back to its first entry,
/// drops progressive enforcement to the base tier and forgets how far into the short-break run
/// the user was. A day change still clears all of it, in `rolloverIfNeeded`. Codable so it can
/// also outlive a quit: relaunching otherwise hands the user all of the above for free.
public struct EnforcementState: Codable, Sendable {
    public var dailyBreakCounts: [UUID: Int]
    public var escalationTiers: [UUID: Int]
    public var cycleIndices: [UUID: Int]
    public var repetitionIndices: [UUID: Int]
    /// Slots the outgoing coordinator was counting down to, by schedule. The interval is
    /// measured from whenever the rebuilt coordinator starts, so without this any restart -- a
    /// schedule edit, a Strict permission reading that flaps -- pushes the break out by however
    /// far into the interval the user already was. Keyed by schedule because the slot decides
    /// which break fires, and because a disabled schedule's slot has to wait out the rebuilds
    /// that exclude it: switching a schedule off and on again must not buy a fresh interval.
    public var pendingBreakDates: [UUID: Date]
    /// The schedule whose break was postponed and is still owed. Carried across a rebuild so a
    /// schedule edit during the wait cannot drop the break, but left out of `CodingKeys`: a
    /// postponed break does not survive a quit.
    public var postponedScheduleID: UUID?

    private enum CodingKeys: String, CodingKey {
        case dailyBreakCounts, escalationTiers, cycleIndices, repetitionIndices, pendingBreakDates
    }

    public init(dailyBreakCounts: [UUID: Int] = [:], escalationTiers: [UUID: Int] = [:],
                cycleIndices: [UUID: Int] = [:], repetitionIndices: [UUID: Int] = [:],
                pendingBreakDates: [UUID: Date] = [:], postponedScheduleID: UUID? = nil) {
        self.dailyBreakCounts = dailyBreakCounts
        self.escalationTiers = escalationTiers
        self.cycleIndices = cycleIndices
        self.repetitionIndices = repetitionIndices
        self.pendingBreakDates = pendingBreakDates
        self.postponedScheduleID = postponedScheduleID
    }
}

/// A break no schedule owns: a Pomodoro break, later "take a break now". It runs the same idle
/// check, deferral, counting and overlay as a schedule break, at the base tier of `level`.
public struct ExternalBreak: Sendable, Equatable {
    public var duration: TimeInterval
    public var level: DisciplineLevel
    public var chip: PomodoroChip?

    public init(duration: TimeInterval, level: DisciplineLevel, chip: PomodoroChip? = nil) {
        self.duration = duration
        self.level = level
        self.chip = chip
    }
}

/// Who a break belongs to, so Done, Skip, Escape and Postpone work without a schedule.
private enum BreakSource {
    case schedule(Schedule)
    case external(ExternalBreak)

    var schedule: Schedule? {
        if case .schedule(let schedule) = self { return schedule }
        return nil
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
    /// When the first of sleep or lock arrived; a session's catch-up measures time away from it.
    private var suspendedAt: Date?
    private var currentBreak: BreakEvent?
    private var currentSource: BreakSource?
    private var currentSchedule: Schedule? { currentSource?.schedule }
    /// A break may be postponed once; the one that comes back after the call cannot be again.
    private var activeBreakCanPostpone = false
    /// The break owed after a postpone, until it returns. The wait itself lives in `breakTimer`,
    /// which lock, sleep and pause cancel; this is what lets them start it again.
    private var postponedSchedule: Schedule?
    /// The external break owed after a postpone. Not carried across a rebuild: a session's
    /// restore reopens its break from the saved phase.
    private var postponedExternal: ExternalBreak?
    /// A running Pomodoro session. While it exists the schedules arm nothing: its phase timer
    /// holds `breakTimer`, so the two can never both fire.
    private var pomodoro: PomodoroSession?
    /// Picked by the app at session start (S87); a session break uses its base tier.
    private var pomodoroLevel: DisciplineLevel = .gentle
    /// The session's break has used its one postpone. Kept apart from `activeBreakCanPostpone`
    /// because a lock takes the break off screen and the return opens it afresh.
    private var pomodoroBreakPostponed = false
    public var pomodoroSession: PomodoroSession? { pomodoro }
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
    /// Carried short-break positions of schedules this coordinator was not given, handed on the
    /// same way: with every schedule off the coordinator still runs, for a Pomodoro session.
    private var dormantRepetitionIndices: [UUID: Int] = [:]
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
                cueLead: TimeInterval = 60) {
        var continuation: AsyncStream<CoordinatorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
        self.scheduler = scheduler
        self.detector = detector
        self.locker = locker
        self.deferralPollingInterval = deferralPollingInterval
        self.cueLead = cueLead
    }

    /// Pass previously persisted `statistics` so a relaunch during the day keeps today's
    /// counters instead of restarting them from zero.
    public func start(with schedules: [Schedule], preferences: AppPreferences,
                      statistics: BreakStatistics = BreakStatistics(),
                      restoring state: EnforcementState = EnforcementState(),
                      pomodoro carried: (session: PomodoroSession, level: DisciplineLevel)? = nil) {
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
        dormantRepetitionIndices = state.repetitionIndices.filter { repetitionTrackers[$0.key] == nil }
        restoredPendingBreaks = state.pendingBreakDates
        if let carried {
            // A rebuild during a session: the schedules start fresh after it (S88), so only the
            // slots of schedules not running now are kept. Arming them first would move the
            // progress anchor twice.
            let active = Set(schedules.map(\.id))
            dormantPendingBreaks.merge(restoredPendingBreaks.filter { !active.contains($0.key) && $0.value > Date() }) { kept, _ in kept }
            restoredPendingBreaks = [:]
            restorePomodoro(carried.session, level: carried.level)
            return
        }
        if let id = state.postponedScheduleID {
            if let schedule = schedules.first(where: { $0.id == id && $0.isEnabled }) {
                postponedSchedule = schedule
                eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: Date().addingTimeInterval(deferralPollingInterval)))
            } else {
                dormantPostponedScheduleID = id
            }
        }
        rearm()
    }

    /// Read this before `stop()`, which clears `escalationTiers` on its way out.
    public func captureEnforcementState() -> EnforcementState {
        // A restored postponed break skips `scheduleNextBreak`, so restored slots can still be unconsumed.
        var pendingBreakDates = dormantPendingBreaks.merging(restoredPendingBreaks) { current, _ in current }
        if let id = pendingBreakScheduleID, let date = pendingBreakDate {
            pendingBreakDates[id] = date
        }
        return EnforcementState(
            dailyBreakCounts: dailyBreakCounts,
            escalationTiers: escalationTiers,
            cycleIndices: cycleIndices,
            repetitionIndices: dormantRepetitionIndices.merging(repetitionTrackers.mapValues(\.currentBreakIndex)) { _, live in live },
            pendingBreakDates: pendingBreakDates,
            postponedScheduleID: postponedSchedule?.id ?? dormantPostponedScheduleID
        )
    }

    public func stop() {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        postponedSchedule = nil
        postponedExternal = nil
        pomodoro = nil
        if locker.isShowing { locker.dismissOverlay() }
        currentBreak = nil
        currentSource = nil
        escalationTiers.removeAll()
    }

    /// Ignored while a Pomodoro session runs: stop the session instead.
    public func pause(for duration: TimeInterval) {
        // Pause and the phase timer share `breakTimer`; a session is stopped, not paused.
        guard pomodoro == nil else { return }
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
        rearm()
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

    public func handleSystemSleep(now: Date = Date()) {
        beginSuspension(now: now)
    }

    public func handleSystemWake(now: Date = Date()) {
        endSuspension(now: now)
    }

    public func handleScreenLock(now: Date = Date()) {
        beginSuspension(now: now)
    }

    public func handleScreenUnlock(now: Date = Date()) {
        endSuspension(now: now)
    }

    private func beginSuspension(now: Date) {
        isSuspended = true
        // A session break that is waiting (deferred, postponed) has not been rested yet: it is
        // owed in full from here, so only time away can credit it.
        if suspendedAt == nil, var session = pomodoro, session.phase.isBreak, !locker.isShowing {
            session.phaseEnd = now.addingTimeInterval(postponedExternal?.duration ?? session.duration(of: session.phase))
            pomodoro = session
        }
        suspendedAt = suspendedAt ?? now
        cancelAndDismissIfShowing()
    }

    /// Wake and unlock often both arrive; a session catches up on the first only.
    private func endSuspension(now: Date) {
        isSuspended = false
        let awayFrom = suspendedAt
        suspendedAt = nil
        if pomodoro != nil {
            guard let awayFrom else { return }
            catchUpPomodoro(awayFrom: awayFrom, to: now)
        } else if isPaused {
            resume()
        } else {
            rearm()
        }
    }

    private func cancelAndDismissIfShowing() {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        if locker.isShowing {
            locker.dismissOverlay()
            // A session's break waits for the return instead (S84): time away may cover it.
            let isSessionBreak = currentSource?.schedule == nil && pomodoro != nil
            if let event = currentBreak, !isSessionBreak {
                eventContinuation.yield(.breakSkipped(event))
                countSkippedBreak()
            }
            currentBreak = nil
            currentSource = nil
        }
    }

    /// Ignored while a Pomodoro session runs: use `skipPomodoroPhase()`.
    public func skipNextBreak() {
        guard pomodoro == nil else { return }
        breakTimer?.cancel()
        breakTimer = nil
        if let id = pendingBreakScheduleID {
            cycleIndices[id, default: 0] += 1
        }
        let anchor = skipAnchor(slot: pendingBreakDate)
        clearPendingBreak()
        postponedSchedule = nil
        countSkippedBreak()
        scheduleNextBreak(searchFrom: anchor)
    }

    public func skipActiveBreak() {
        guard let event = currentBreak else { return }
        if let scheduleID = event.scheduleId {
            let maxTier = (currentSchedule?.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count ?? 5) - 1
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, maxTier)
        }
        locker.dismissOverlay()
        eventContinuation.yield(.breakSkipped(event))
        countSkippedBreak()
        let source = currentSource
        let anchor = source?.schedule == nil ? nil : skipAnchor(slot: event.scheduledAt)
        currentBreak = nil
        currentSource = nil
        afterBreak(source, searchFrom: anchor)
    }

    public func escapeActiveBreak() {
        guard let event = currentBreak else { return }
        if let scheduleID = event.scheduleId {
            let maxTier = (currentSchedule?.disciplineLevel.enforcementPolicy(preferences: preferences).tiers.count ?? 5) - 1
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, maxTier)
        }
        locker.dismissOverlay()
        eventContinuation.yield(.breakEscaped(event))
        updateStatistics {
            $0.breaksEscaped += 1
            $0.weeklyEscapeCount += 1
        }
        let source = currentSource
        currentBreak = nil
        currentSource = nil
        // An emergency exit must leave time to change a hostile or accidentally tiny interval.
        afterBreak(source, searchFrom: Date())
    }

    /// Closes the break screen without counting a skip and brings the same break back, at full
    /// length, once camera and microphone have both been free for `postponeReturnDelay`. The
    /// wait ignores the detection preferences: postponing is the user saying they are on a call.
    public func postponeActiveBreak() {
        guard currentBreak != nil, let source = currentSource, activeBreakCanPostpone else { return }
        breakTimer?.cancel()
        breakTimer = nil
        locker.dismissOverlay()
        currentBreak = nil
        currentSource = nil
        switch source {
        case .schedule(let schedule): postponedSchedule = schedule
        case .external(let request):
            postponedExternal = request
            if pomodoro != nil { pomodoroBreakPostponed = true }
        }
        eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: Date().addingTimeInterval(deferralPollingInterval)))
        updateStatistics { $0.breaksDeferred += 1 }
        startPostponeWait(for: source)
    }

    private func startPostponeWait(for source: BreakSource) {
        breakTimer?.cancel()
        // Keeps `refreshDailyRollover` from re-arming over the wait. The pending slot stays nil:
        // `triggerBreak` already advanced the cycle, and a set ID would let a menu skip advance it again.
        isDeferringBreak = true
        breakTimer = Task {
            var clearSince: Date?
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.deferralPollingInterval))
                guard !Task.isCancelled else { return }
                let context = await self.detector.currentContext()
                guard !Task.isCancelled else { return }
                if context.cameraActive || context.microphoneActive {
                    clearSince = nil
                    self.eventContinuation.yield(.breakDeferred(.postponed, nextAttempt: Date().addingTimeInterval(self.deferralPollingInterval)))
                    continue
                }
                let since = clearSince ?? Date()
                if clearSince == nil {
                    // Lets the menu bar count down to the return instead of sitting at 0:00.
                    self.eventContinuation.yield(.nextBreakScheduled(since.addingTimeInterval(self.preferences.postponeReturnDelay)))
                }
                clearSince = since
                if Date().timeIntervalSince(since) >= self.preferences.postponeReturnDelay {
                    self.clearPendingBreak()
                    if source.schedule == nil { self.postponedExternal = nil } else { self.postponedSchedule = nil }
                    self.presentBreak(for: source, context: context, canPostpone: false)
                    return
                }
            }
        }
    }

    public func completeActiveBreak() {
        guard let event = currentBreak, let source = currentSource else { return }
        completeBreak(event: event, source: source)
    }

    public func changeDisciplineLevel(_ level: DisciplineLevel) {
        for i in activeSchedules.indices {
            activeSchedules[i].disciplineLevel = level
        }
    }

    public func updatePreferences(_ preferences: AppPreferences) {
        self.preferences = preferences
    }

    /// Opens a break no schedule owns. A pending schedule slot is dropped; the schedules arm
    /// afresh once this break ends. Ignored while a break is on screen or when the duration
    /// bounds to zero.
    public func startExternalBreak(_ request: ExternalBreak) {
        guard currentBreak == nil, BreakSafety.breakDuration(request.duration) > 0 else { return }
        breakTimer?.cancel()
        clearPendingBreak()
        breakTimer = Task {
            let context = await self.detector.currentContext()
            guard !Task.isCancelled else { return }
            await self.triggerBreak(for: .external(request), context: context)
        }
    }

    /// Starts a session. A configuration outside the form's ranges falls back to the standard
    /// one: a zero-length phase would loop. Ends an active pause, which shares the timer slot.
    public func startPomodoro(_ configuration: PomodoroConfiguration, level: DisciplineLevel, now: Date = Date()) {
        guard pomodoro == nil, currentBreak == nil else { return }
        if isPaused {
            isPaused = false
            eventContinuation.yield(.scheduleResumed)
        }
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        dropPostponedSchedule()
        pomodoroLevel = level
        pomodoro = .start(at: now, configuration: configuration.isWithinBounds ? configuration : .standard)
        emitPomodoro()
        armPomodoroFocus()
    }

    /// Ends the session as abandoned; no skip is counted. Refused while its break is on screen:
    /// the overlay's own exits apply there.
    public func stopPomodoro() {
        guard pomodoro != nil, currentBreak == nil else { return }
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        postponedExternal = nil
        endPomodoro(.stopped)
    }

    /// Picks up a session saved before a relaunch or a coordinator rebuild, caught up as after
    /// a wake. Time the app was not running is not credited as rest. A session outside the
    /// form's ranges is dropped.
    public func restorePomodoro(_ session: PomodoroSession, level: DisciplineLevel, now: Date = Date()) {
        guard pomodoro == nil, currentBreak == nil, var session = session.bounded(now: now) else { return }
        // Time the app was not running, or a deferral, was not rest: a break opens in full. The
        // saved phase end cannot tell an on-screen break from a waiting one, whose end is stale.
        if session.phase.isBreak {
            session.phaseEnd = now.addingTimeInterval(session.duration(of: session.phase))
        }
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        dropPostponedSchedule()
        pomodoroLevel = level
        pomodoro = session
        emitPomodoro()
        catchUpPomodoro(awayFrom: now, to: now)
    }

    /// During focus, opens the break now. During a break that is waiting (deferred or
    /// postponed), skips it: counted as a skip, the next focus starts.
    public func skipPomodoroPhase() {
        guard let session = pomodoro, currentBreak == nil else { return }
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        if case .focus = session.phase {
            breakTimer = Task {
                // A lock or wake in the same turn cancels this before it runs.
                guard !Task.isCancelled else { return }
                await self.endPomodoroFocus()
            }
            return
        }
        postponedExternal = nil
        countSkippedBreak()
        advancePomodoro()
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
                for: schedule, after: Date(), cycleIndex: cycleIndices[schedule.id, default: 0]
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
        if let request = postponedExternal {
            startPostponeWait(for: .external(request))
        } else if pomodoro != nil {
            scheduleNextBreak()
        } else if let schedule = postponedSchedule {
            startPostponeWait(for: .schedule(schedule))
        } else {
            scheduleNextBreak()
        }
    }

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
        if pomodoro != nil {
            rolloverIfNeeded(now: now)
            armPomodoroFocus()
            return
        }
        breakTimer?.cancel()
        breakTimer = nil
        rolloverIfNeeded(now: now)
        guard !isPaused else { return }

        var earliest: (date: Date, schedule: Schedule)?
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
            if !isCapReached(schedule), earliest == nil || date < earliest!.date {
                earliest = (date, schedule)
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
            let untilCue = fireDate.timeIntervalSince(Date()) - self.cueLead
            if untilCue > 0 {
                try? await Task.sleep(for: .seconds(untilCue))
                guard !Task.isCancelled else { return }
                await self.playApproachingCue()
                guard !Task.isCancelled else { return }
            }
            let delay = fireDate.timeIntervalSince(Date())
            let leadTime: TimeInterval = 3
            let earlyDelay = max(0, delay - leadTime)
            if earlyDelay > 0 { try? await Task.sleep(for: .seconds(earlyDelay)) }
            guard !Task.isCancelled else { return }
            let context = await self.detector.currentContext()
            let remaining = fireDate.timeIntervalSince(Date())
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            await self.triggerBreak(for: .schedule(target.schedule), context: context)
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

    private func triggerBreak(for source: BreakSource, context: DetectionContext) async {
        // The pending break is now active; a menu skip from here on must not advance again.
        clearPendingBreak()
        rolloverIfNeeded()
        let schedule = source.schedule
        if preferences.idleDetectionEnabled {
            let breakDuration = breakDuration(for: source)
            // A break under a minute must not be swallowed by a glance away from the keyboard:
            // idle counts as a break only once it reaches a minute, or the full break when longer.
            if context.idleDuration >= max(breakDuration, 60) {
                let idleEvent = BreakEvent(
                    scheduledAt: Date(), duration: breakDuration,
                    level: level(of: source), scheduleId: schedule?.id
                )
                if let schedule {
                    if var tracker = repetitionTrackers[schedule.id] {
                        tracker.recordBreak()
                        repetitionTrackers[schedule.id] = tracker
                    }
                    dailyBreakCounts[schedule.id, default: 0] += 1
                    cycleIndices[schedule.id, default: 0] += 1
                    escalationTiers[schedule.id] = 0
                }
                eventContinuation.yield(.breakCompleted(idleEvent))
                countCompletedBreak()
                afterBreak(source)
                return
            }
        }

        if let deferral = shouldDefer(context: context) {
            // The deferred slot is still pending, so a menu skip during the poll loop
            // must conclude it for this schedule.
            pendingBreakScheduleID = schedule?.id
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
                        if let schedule { self.cycleIndices[schedule.id, default: 0] += 1 }
                        self.clearPendingBreak()
                        self.afterBreak(source)
                        return
                    } else {
                        await self.triggerBreak(for: source, context: freshContext)
                        return
                    }
                }
            }
            return
        }

        if let schedule {
            dailyBreakCounts[schedule.id, default: 0] += 1
            cycleIndices[schedule.id, default: 0] += 1
        }
        presentBreak(for: source, context: context, canPostpone: true)
    }

    /// Shows a break without counting it. A postponed break returns through here, so the daily
    /// count and the cycle advance only once, in `triggerBreak`.
    private func presentBreak(for source: BreakSource, context: DetectionContext, canPostpone: Bool) {
        var effectiveLevel = level(of: source)
        if let reduction = shouldReduce(context: context) {
            effectiveLevel = reduction
        }

        let schedule = source.schedule
        let duration = breakDuration(for: source)
        let exercise = exercises.randomElement()
        // External breaks use the level's base tier and never move a schedule's escalation.
        let tier = schedule.map(currentTier(for:)) ?? 0
        let breakEvent = BreakEvent(
            scheduledAt: Date(), duration: duration,
            level: effectiveLevel, scheduleId: schedule?.id
        )
        let canPostpone = canPostpone && !(schedule == nil && pomodoroBreakPostponed)
        currentBreak = breakEvent
        currentSource = source
        activeBreakCanPostpone = canPostpone

        var chip: PomodoroChip?
        if case .external(let request) = source {
            chip = request.chip
            // The break phase runs from its overlay, not from the focus end: a deferral or a
            // postpone must not eat into it.
            if var session = pomodoro, session.phase.isBreak {
                session.phaseEnd = Date().addingTimeInterval(duration)
                pomodoro = session
                emitPomodoro()
            }
        }

        eventContinuation.yield(.breakStarted(breakEvent))
        locker.showOverlay(level: effectiveLevel, duration: duration,
                           exercise: exercise, preferences: preferences,
                           statistics: statistics, escalationTier: tier,
                           nextIntervalLabel: schedule.flatMap(nextIntervalLabel(for:)),
                           canPostpone: canPostpone, pomodoroChip: chip)
    }

    /// The cycle index was already advanced when this break triggered, so it points at the
    /// upcoming work block.
    private func nextIntervalLabel(for schedule: Schedule) -> String? {
        guard let cycle = schedule.intervalCycle, !cycle.isEmpty else { return nil }
        return cycle[cycleIndices[schedule.id, default: 0] % cycle.count].label
    }

    private func level(of source: BreakSource) -> DisciplineLevel {
        switch source {
        case .schedule(let schedule): schedule.disciplineLevel
        case .external(let request): request.level
        }
    }

    private func breakDuration(for source: BreakSource) -> TimeInterval {
        switch source {
        case .schedule(let schedule): currentBreakDuration(for: schedule)
        case .external(let request): BreakSafety.breakDuration(request.duration)
        }
    }

    private func currentBreakDuration(for schedule: Schedule) -> TimeInterval {
        if let tracker = repetitionTrackers[schedule.id] {
            return BreakSafety.breakDuration(tracker.currentDuration)
        }
        return BreakSafety.breakDuration(schedule.breakDuration)
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

    private func completeBreak(event: BreakEvent, source: BreakSource) {
        if let schedule = source.schedule {
            escalationTiers[schedule.id] = 0
            if var tracker = repetitionTrackers[schedule.id] {
                tracker.recordBreak()
                repetitionTrackers[schedule.id] = tracker
            }
        }
        locker.dismissOverlay()
        eventContinuation.yield(.breakCompleted(event))
        if preferences.soundAfterBreak { eventContinuation.yield(.breakCue(.ended)) }
        countCompletedBreak()
        currentBreak = nil
        currentSource = nil
        afterBreak(source)
    }

    private func countSkippedBreak() {
        updateStatistics {
            $0.breaksSkipped += 1
            $0.currentStreak = 0
        }
    }

    /// The one place a completed break is counted: Done, idle credit and time away all end here.
    private func countCompletedBreak() {
        updateStatistics {
            $0.breaksCompleted += 1
            $0.currentStreak += 1
        }
    }

    /// What follows a break that ended: a session moves to its next focus, otherwise the
    /// schedules arm their next break.
    private func afterBreak(_ source: BreakSource?, searchFrom: Date? = nil) {
        if source?.schedule == nil, pomodoro?.phase.isBreak == true {
            advancePomodoro()
        } else {
            scheduleNextBreak(searchFrom: searchFrom)
        }
    }

    // MARK: - Pomodoro

    private enum PomodoroTally { case focusEnded, finished, stopped }

    /// The one place a session's tallies are counted, through `updateStatistics` like every
    /// break, so the day's record gets them. Called before `pomodoro` moves on.
    private func recordPomodoroTally(_ tally: PomodoroTally, now: Date = Date()) {
        let focusRan = pomodoro?.focusElapsed(at: now) ?? 0
        updateStatistics { stats in
            var tallies = stats.pomodoroTallies ?? PomodoroTallies()
            switch tally {
            case .focusEnded:
                tallies.focusSeconds += focusRan
                tallies.rounds += 1
            case .finished: tallies.sessionsFinished += 1
            case .stopped: tallies.sessionsAbandoned += 1
            }
            stats.pomodoroTallies = tallies
        }
    }

    private func emitPomodoro() {
        eventContinuation.yield(.pomodoroChanged(pomodoro.map { PomodoroStatus(session: $0, level: pomodoroLevel) }))
    }

    private func pomodoroBreak(duration: TimeInterval) -> ExternalBreak {
        let chip = pomodoro.flatMap { PomodoroStatus(session: $0, level: pomodoroLevel).chip }
        return ExternalBreak(duration: duration, level: pomodoroLevel, chip: chip)
    }

    /// Arms the focus timer. Does nothing in a break phase, which the overlay, a deferral, a
    /// postpone or a return from sleep drives.
    private func armPomodoroFocus() {
        guard let session = pomodoro, case .focus = session.phase else { return }
        breakTimer?.cancel()
        clearPendingBreak()
        let end = session.phaseEnd
        eventContinuation.yield(.nextBreakScheduled(end))
        breakTimer = Task {
            let delay = end.timeIntervalSince(Date())
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await self.endPomodoroFocus()
        }
    }

    private func endPomodoroFocus() async {
        guard let session = pomodoro, case .focus = session.phase,
              let onBreak = session.next(at: Date()) else { return }
        recordPomodoroTally(.focusEnded)
        pomodoro = onBreak
        emitPomodoro()
        await openPomodoroBreak(duration: onBreak.duration(of: onBreak.phase))
    }

    /// Opens the session's break through the external entry, after a fresh context read.
    private func openPomodoroBreak(duration: TimeInterval) async {
        let request = pomodoroBreak(duration: duration)
        let context = await detector.currentContext()
        guard !Task.isCancelled, pomodoro?.phase.isBreak == true else { return }
        await triggerBreak(for: .external(request), context: context)
    }

    /// Applies time away (S84). A break the time covered counts once, here, with no overlay;
    /// only a break left partly owed opens, through the external entry.
    private func catchUpPomodoro(awayFrom: Date, to now: Date) {
        // A session does not outlive its day (S84): away past midnight ends it as a relaunch does.
        if let stale = pomodoro, !Calendar.current.isDate(awayFrom, inSameDayAs: now) {
            dropPomodoro(stale)
            return
        }
        guard let session = pomodoro?.bounded(now: now) else {
            if pomodoro != nil { endPomodoro(.stopped) }
            return
        }
        pomodoro = session
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        switch session.catchUp(awayFrom: awayFrom, to: now) {
        case .unchanged:
            guard session.phase.isBreak else {
                emitPomodoro()
                armPomodoroFocus()
                return
            }
            if let request = postponedExternal {
                startPostponeWait(for: .external(request))
            } else {
                let remaining = session.phaseEnd.timeIntervalSince(now)
                breakTimer = Task { await self.openPomodoroBreak(duration: remaining) }
            }
        case .creditedBreaks(_, let next):
            if case .focus = session.phase { recordPomodoroTally(.focusEnded, now: now) }
            postponedExternal = nil
            pomodoroBreakPostponed = false
            let credited = session.phase.isBreak ? session.phase : (session.next(at: now)?.phase ?? .longBreak)
            eventContinuation.yield(.breakCompleted(BreakEvent(
                scheduledAt: now, duration: session.duration(of: credited), level: pomodoroLevel, scheduleId: nil
            )))
            countCompletedBreak()
            if let next {
                pomodoro = next
                emitPomodoro()
                armPomodoroFocus()
            } else {
                endPomodoro(.finished)
            }
        case .openBreak(let remaining, let next):
            recordPomodoroTally(.focusEnded, now: now)
            pomodoro = next
            emitPomodoro()
            breakTimer = Task { await self.openPomodoroBreak(duration: remaining) }
        case .coverDelayed(let delayed):
            pomodoro = delayed
            emitPomodoro()
            armPomodoroFocus()
        }
    }

    /// After a session break: the next focus, or the end of the session after the long break.
    private func advancePomodoro() {
        guard let session = pomodoro else { return }
        pomodoroBreakPostponed = false
        if let next = session.next(at: Date()) {
            pomodoro = next
            emitPomodoro()
            armPomodoroFocus()
        } else {
            endPomodoro(.finished)
        }
    }

    /// Ends a session the app records as abandoned on its own day; nothing is tallied today.
    private func dropPomodoro(_ session: PomodoroSession) {
        breakTimer?.cancel()
        breakTimer = nil
        clearPendingBreak()
        postponedExternal = nil
        pomodoro = nil
        pomodoroBreakPostponed = false
        eventContinuation.yield(.pomodoroDropped(session))
        emitPomodoro()
        rearm()
    }

    /// A schedule break postponed before a session is replaced by the session's breaks.
    private func dropPostponedSchedule() {
        postponedSchedule = nil
        dormantPostponedScheduleID = nil
    }

    /// The schedules start a fresh interval from here, as after a wake (S88).
    private func endPomodoro(_ tally: PomodoroTally) {
        recordPomodoroTally(tally)
        pomodoro = nil
        pomodoroBreakPostponed = false
        emitPomodoro()
        rearm()
    }
}

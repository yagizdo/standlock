import Foundation
import StandLockCore
import Scheduling
import Detection
import Locking

@MainActor
public final class BreakCoordinator: BreakCoordinating {
    private let scheduler: any SchedulingEngine
    private let detector: any ContextDetecting
    private let locker: any LockPresenting

    private var activeSchedules: [Schedule] = []
    private var preferences: AppPreferences = AppPreferences()
    private var repetitionTrackers: [UUID: RepetitionTracker] = [:]
    private var breakTimer: Task<Void, Never>?
    private var isPaused: Bool = false
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

    public func start(with schedules: [Schedule], preferences: AppPreferences) {
        self.activeSchedules = schedules
        self.preferences = preferences
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

    public func handleSystemSleep() {
        breakTimer?.cancel()
        breakTimer = nil
        if locker.isShowing {
            locker.dismissOverlay()
            if var event = currentBreak {
                event.outcome = .skipped
                statistics.breaksSkipped += 1
                statistics.currentStreak = 0
                eventContinuation.yield(.breakSkipped(event))
                eventContinuation.yield(.statisticsUpdated(statistics))
            }
            currentBreak = nil
            currentSchedule = nil
        }
    }

    public func handleSystemWake() {
        scheduleNextBreak()
    }

    public func handleScreenLock() {
        breakTimer?.cancel()
        breakTimer = nil
        if locker.isShowing {
            locker.dismissOverlay()
            if var event = currentBreak {
                event.outcome = .skipped
                statistics.breaksSkipped += 1
                statistics.currentStreak = 0
                eventContinuation.yield(.breakSkipped(event))
                eventContinuation.yield(.statisticsUpdated(statistics))
            }
            currentBreak = nil
            currentSchedule = nil
        }
    }

    public func handleScreenUnlock() {
        scheduleNextBreak()
    }

    public func skipNextBreak() {
        breakTimer?.cancel()
        breakTimer = nil
        statistics.breaksSkipped += 1
        statistics.currentStreak = 0
        eventContinuation.yield(.statisticsUpdated(statistics))
        scheduleNextBreak()
    }

    public func skipActiveBreak() {
        guard var event = currentBreak else { return }
        event.outcome = .skipped
        if let scheduleID = currentBreak?.scheduleId {
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, 4)
        }
        locker.dismissOverlay()
        statistics.breaksSkipped += 1
        statistics.currentStreak = 0
        eventContinuation.yield(.breakSkipped(event))
        eventContinuation.yield(.statisticsUpdated(statistics))
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }

    public func escapeActiveBreak() {
        guard var event = currentBreak else { return }
        event.outcome = .escaped
        if let scheduleID = currentBreak?.scheduleId {
            escalationTiers[scheduleID, default: 0] = min(escalationTiers[scheduleID, default: 0] + 1, 4)
        }
        locker.dismissOverlay()
        statistics.breaksEscaped += 1
        statistics.weeklyEscapeCount += 1
        eventContinuation.yield(.breakEscaped(event))
        eventContinuation.yield(.statisticsUpdated(statistics))
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

    private func scheduleNextBreak() {
        breakTimer?.cancel()
        breakTimer = nil
        guard !isPaused else { return }

        var earliest: (date: Date, schedule: Schedule)?
        let now = Date()
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
        if preferences.idleDetectionEnabled {
            let breakDuration = currentBreakDuration(for: schedule)
            if context.idleDuration >= breakDuration {
                let idleEvent = BreakEvent(
                    scheduledAt: Date(), duration: breakDuration,
                    level: schedule.disciplineLevel, scheduleId: schedule.id,
                    outcome: .idleCounted
                )
                statistics.breaksCompleted += 1
                statistics.currentStreak += 1
                if var tracker = repetitionTrackers[schedule.id] {
                    tracker.recordBreak()
                    repetitionTrackers[schedule.id] = tracker
                }
                dailyBreakCounts[schedule.id, default: 0] += 1
                escalationTiers[schedule.id] = 0
                eventContinuation.yield(.breakCompleted(idleEvent))
                eventContinuation.yield(.statisticsUpdated(statistics))
                scheduleNextBreak()
                return
            }
        }

        if let deferral = shouldDefer(context: context) {
            statistics.breaksDeferred += 1
            eventContinuation.yield(.breakDeferred(deferral, nextAttempt: Date().addingTimeInterval(deferralPollingInterval)))
            eventContinuation.yield(.statisticsUpdated(statistics))
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
        statistics.breaksCompleted += 1
        statistics.currentStreak += 1
        if var tracker = repetitionTrackers[schedule.id] {
            tracker.recordBreak()
            repetitionTrackers[schedule.id] = tracker
        }
        eventContinuation.yield(.breakCompleted(completed))
        eventContinuation.yield(.statisticsUpdated(statistics))
        currentBreak = nil
        currentSchedule = nil
        scheduleNextBreak()
    }
}

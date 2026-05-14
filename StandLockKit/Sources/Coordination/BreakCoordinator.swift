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
    private var breakCountdownTimer: Task<Void, Never>?
    private var isPaused: Bool = false
    private var currentBreak: BreakEvent?
    private var currentSchedule: Schedule?
    private var statistics: BreakStatistics = BreakStatistics()
    private var dailyBreakCounts: [UUID: Int] = [:]
    public var exercises: [Exercise] = []

    private let eventContinuation: AsyncStream<CoordinatorEvent>.Continuation
    public nonisolated let events: AsyncStream<CoordinatorEvent>

    public init(scheduler: any SchedulingEngine, detector: any ContextDetecting,
                locker: any LockPresenting) {
        var continuation: AsyncStream<CoordinatorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
        self.scheduler = scheduler
        self.detector = detector
        self.locker = locker
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
        breakCountdownTimer?.cancel()
        breakTimer = nil
        breakCountdownTimer = nil
        if locker.isShowing { locker.dismissOverlay() }
        currentBreak = nil
        currentSchedule = nil
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

    public func skipNextBreak() {
        breakTimer?.cancel()
        breakTimer = nil
        statistics.breaksSkipped += 1
        statistics.currentStreak = 0
        eventContinuation.yield(.statisticsUpdated(statistics))
        scheduleNextBreak()
    }

    public func skipActiveBreak() {
        breakCountdownTimer?.cancel()
        breakCountdownTimer = nil
        guard var event = currentBreak else { return }
        event.outcome = .skipped
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
        breakCountdownTimer?.cancel()
        breakCountdownTimer = nil
        guard var event = currentBreak else { return }
        event.outcome = .escaped
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
        breakCountdownTimer?.cancel()
        breakCountdownTimer = nil
        guard let event = currentBreak, let schedule = currentSchedule else { return }
        completeBreak(event: event, schedule: schedule)
    }

    public func changeDisciplineLevel(_ level: DisciplineLevel) {
        for i in activeSchedules.indices {
            activeSchedules[i].disciplineLevel = level
        }
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
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await triggerBreak(for: target.schedule)
        }
    }

    private func triggerBreak(for schedule: Schedule) async {
        let context = await detector.currentContext()

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
                eventContinuation.yield(.breakCompleted(idleEvent))
                eventContinuation.yield(.statisticsUpdated(statistics))
                scheduleNextBreak()
                return
            }
        }

        if let deferral = shouldDefer(context: context) {
            statistics.breaksDeferred += 1
            let nextAttempt = Date().addingTimeInterval(60)
            eventContinuation.yield(.breakDeferred(deferral, nextAttempt: nextAttempt))
            eventContinuation.yield(.statisticsUpdated(statistics))
            breakTimer = Task {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await triggerBreak(for: schedule)
            }
            return
        }

        var effectiveLevel = schedule.disciplineLevel
        if let reduction = shouldReduce(context: context) {
            effectiveLevel = reduction
        }

        let duration = currentBreakDuration(for: schedule)
        let exercise = exercises.randomElement()
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
                           statistics: statistics)
        startBreakCountdown(event: breakEvent, duration: duration, schedule: schedule)
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

    private func shouldReduce(context: DetectionContext) -> DisciplineLevel? {
        if context.cameraActive && preferences.cameraDetection == .reduceToGentle { return .gentle }
        if context.microphoneActive && preferences.microphoneDetection == .reduceToGentle { return .gentle }
        if context.focusModeActive && preferences.focusModeDetection == .reduceToGentle { return .gentle }
        return nil
    }

    private func startBreakCountdown(event: BreakEvent, duration: TimeInterval, schedule: Schedule) {
        breakCountdownTimer = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            completeBreak(event: event, schedule: schedule)
        }
    }

    private func completeBreak(event: BreakEvent, schedule: Schedule) {
        var completed = event
        completed.outcome = .completed
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

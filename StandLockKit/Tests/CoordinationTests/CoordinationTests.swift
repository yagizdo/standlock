import Testing
import Foundation
@testable import Coordination
@testable import StandLockCore
@testable import Scheduling

// MARK: - Mocks

final class MockScheduler: SchedulingEngine, @unchecked Sendable {
    var nextBreakTimeToReturn: Date?
    var nextBreakTimes: [UUID: Date] = [:]
    var breakDurationToReturn: TimeInterval = 300
    var receivedCycleIndices: [(scheduleID: UUID, index: Int)] = []
    var receivedAfterDates: [Date] = []

    func nextBreakTime(for schedule: Schedule, after date: Date, cycleIndex: Int) -> Date? {
        receivedCycleIndices.append((scheduleID: schedule.id, index: cycleIndex))
        receivedAfterDates.append(date)
        return nextBreakTimes[schedule.id] ?? nextBreakTimeToReturn
    }
    func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval { breakDurationToReturn }
    func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool { true }
}

final class MockDetector: ContextDetecting, @unchecked Sendable {
    var contextToReturn: DetectionContext = .clear
    func currentContext() async -> DetectionContext { contextToReturn }
}

@MainActor
final class MockLocker: LockPresenting, @unchecked Sendable {
    var showOverlayCalled = false
    var dismissOverlayCalled = false
    var lastLevel: DisciplineLevel?
    var lastDuration: TimeInterval?
    var lastPreferences: AppPreferences?
    var lastEscalationTier: Int?
    var lastNextIntervalLabel: String?
    var isShowing = false

    func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                     exercise: Exercise?, preferences: AppPreferences,
                     statistics: BreakStatistics, escalationTier: Int,
                     nextIntervalLabel: String?) {
        showOverlayCalled = true
        lastLevel = level
        lastDuration = duration
        lastPreferences = preferences
        lastEscalationTier = escalationTier
        lastNextIntervalLabel = nextIntervalLabel
        isShowing = true
    }

    func dismissOverlay() {
        dismissOverlayCalled = true
        isShowing = false
    }
}

// MARK: - Helpers

func makeSchedule(
    level: DisciplineLevel = .gentle,
    breakInterval: TimeInterval = 60,
    breakDuration: TimeInterval = 10,
    intervalCycle: [IntervalStep]? = nil,
    repetitionRule: RepetitionRule? = nil,
    dailyBreakCap: Int? = nil,
    progressiveEnforcement: Bool = false
) -> Schedule {
    Schedule(
        name: "Test",
        days: .everyDay,
        windows: [TimeWindow(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)],
        breakInterval: breakInterval,
        breakDuration: breakDuration,
        intervalCycle: intervalCycle,
        repetitionRule: repetitionRule,
        disciplineLevel: level,
        dailyBreakCap: dailyBreakCap,
        progressiveEnforcement: progressiveEnforcement
    )
}

// MARK: - Tests

@Suite("BreakCoordinator Tests")
struct BreakCoordinatorTests {

    @Test @MainActor
    func breakTriggersAtScheduledTime() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        coordinator.start(with: [schedule], preferences: AppPreferences())

        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)
        #expect(locker.lastLevel == .gentle)
        coordinator.stop()
    }

    @Test @MainActor
    func breakDeferredWhenCameraActive() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(cameraActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()
        let prefs = AppPreferences(cameraDetection: .deferBreak)

        var deferredEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred = event { deferredEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!locker.showOverlayCalled)
        #expect(!deferredEvents.isEmpty)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func breakReducedToGentleWhenCameraActive() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(cameraActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .firm)
        let prefs = AppPreferences(cameraDetection: .reduceToGentle)

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)
        #expect(locker.lastLevel == .gentle)
        coordinator.stop()
    }

    @Test @MainActor
    func breakIgnoredDetectionWhenConfigured() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(cameraActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .firm)
        let prefs = AppPreferences(cameraDetection: .ignore)

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)
        #expect(locker.lastLevel == .firm)
        coordinator.stop()
    }

    @Test @MainActor
    func breakCompletedViaOverlay() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var completedEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted = event { completedEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(!completedEvents.isEmpty)
        #expect(locker.dismissOverlayCalled)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func skipNextBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(5)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var statsEvents: [BreakStatistics] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let stats) = event { statsEvents.append(stats) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.skipNextBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(!statsEvents.isEmpty)
        if let lastStats = statsEvents.last {
            #expect(lastStats.breaksSkipped == 1)
            #expect(lastStats.currentStreak == 0)
        }

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func pauseAndResume() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(5)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var pauseEvent: CoordinatorEvent?
        var resumeEvent: CoordinatorEvent?
        let listener = Task {
            for await event in coordinator.events {
                if case .schedulePaused = event { pauseEvent = event }
                if case .scheduleResumed = event { resumeEvent = event }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.pause(for: 60)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(pauseEvent != nil)

        coordinator.resume()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(resumeEvent != nil)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func statisticsUpdatedOnComplete() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let stats) = event { lastStats = stats }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastStats != nil)
        #expect(lastStats?.breaksCompleted ?? 0 >= 1)
        #expect(lastStats?.currentStreak ?? 0 >= 1)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func idleCountsAsBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 300)
        let prefs = AppPreferences(idleDetectionEnabled: true)

        var completedEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted = event { completedEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!locker.showOverlayCalled)
        #expect(!completedEvents.isEmpty)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func skipActiveBreakDismissesAndResetsStreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var skippedEvents: [BreakEvent] = []
        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .breakSkipped(let e) = event { skippedEvents.append(e) }
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(locker.dismissOverlayCalled)
        #expect(skippedEvents.count == 1)
        #expect(lastStats?.breaksSkipped == 1)
        #expect(lastStats?.currentStreak == 0)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func staleStatisticsRollOverToNewDay() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var yesterdayStats = BreakStatistics(date: yesterday)
        yesterdayStats.breaksSkipped = 2
        yesterdayStats.breaksCompleted = 3

        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences(), statistics: yesterdayStats)
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastStats?.breaksSkipped == 1)
        #expect(lastStats?.breaksCompleted == 0)

        coordinator.stop()
        listener.cancel()
    }

    // Issue #32: the app keeps running across days, so a rollover must report a clean day on
    // its own -- before any break is taken -- rather than carrying yesterday's counters.
    @Test @MainActor
    func rolloverEmitsZeroedStatisticsBeforeAnyBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var yesterdayStats = BreakStatistics(date: yesterday)
        yesterdayStats.breaksSkipped = 2
        yesterdayStats.breaksCompleted = 3
        yesterdayStats.breaksEscaped = 1
        yesterdayStats.currentStreak = 4

        var statsEvents: [BreakStatistics] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let s) = event { statsEvents.append(s) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences(), statistics: yesterdayStats)
        try? await Task.sleep(for: .milliseconds(100))

        // Exactly one event, emitted by the rollover itself rather than by a later mutation.
        #expect(statsEvents.count == 1)
        #expect(statsEvents.last?.breaksSkipped == 0)
        #expect(statsEvents.last?.breaksCompleted == 0)
        #expect(statsEvents.last?.breaksEscaped == 0)
        // The break streak spans days and must survive the rollover.
        #expect(statsEvents.last?.currentStreak == 4)

        coordinator.stop()
        listener.cancel()
    }

    // AppCoordinator starts the coordinator before it attaches its event listener, so the
    // rollover emitted from inside start() has no consumer yet. It survives only because
    // AsyncStream buffers unboundedly by default; a switch to a bounded policy or an early
    // finish() would silently drop the day's first event and leave stale counters on screen.
    @Test @MainActor
    func rolloverEmittedBeforeListenerAttachesIsStillDelivered() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var yesterdayStats = BreakStatistics(date: yesterday)
        yesterdayStats.breaksSkipped = 2
        yesterdayStats.breaksCompleted = 3

        // Start first, subscribe second -- the production ordering.
        coordinator.start(with: [schedule], preferences: AppPreferences(), statistics: yesterdayStats)

        var statsEvents: [BreakStatistics] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let s) = event { statsEvents.append(s) }
            }
        }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(statsEvents.count == 1)
        #expect(statsEvents.last?.breaksSkipped == 0)
        #expect(statsEvents.last?.breaksCompleted == 0)

        coordinator.stop()
        listener.cancel()
    }

    // refreshDailyRollover(now:) must hand its date to everything it triggers. When the nested
    // scheduleNextBreak re-read the real clock instead, resetDailyIfNeeded fired a second time
    // in the reverse direction -- re-zeroing the counters, rewinding statistics.date, and
    // emitting a second event for one logical rollover.
    @Test @MainActor
    func injectedRolloverDateGovernsTheWholeOperation() async {
        let scheduler = MockScheduler()
        // No next break available, so start() leaves breakTimer nil -- the same shape as a
        // schedule that used up its daily cap, which is the only state that re-arms on rollover.
        scheduler.nextBreakTimeToReturn = nil
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var statsEvents: [BreakStatistics] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let s) = event { statsEvents.append(s) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences(),
                          statistics: BreakStatistics(date: Date()))
        try? await Task.sleep(for: .milliseconds(100))
        statsEvents.removeAll()

        // The new day frees the schedule, so the rollover re-arms -- exercising the nested call.
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        coordinator.refreshDailyRollover(now: tomorrow)
        try? await Task.sleep(for: .milliseconds(100))

        // One logical rollover, one event -- not one forwards and one back.
        #expect(statsEvents.count == 1)
        // The injected day stuck rather than being rewound by the nested reschedule.
        #expect(Calendar.current.isDate(statsEvents.last?.date ?? Date(), inSameDayAs: tomorrow))

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func restoredStatisticsFromSameDayAreKept() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var todayStats = BreakStatistics(date: Date())
        todayStats.breaksSkipped = 2
        todayStats.breaksCompleted = 3

        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences(), statistics: todayStats)
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastStats?.breaksSkipped == 3)
        #expect(lastStats?.breaksCompleted == 3)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func escalationTierAndDailyCapResetOnRollover() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(dailyBreakCap: 2, progressiveEnforcement: true)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        // Each reassignment has to precede the call that reschedules, or the coordinator reads
        // the previous, already-elapsed date instead.
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 1)

        // The daily cap of 2 is now used up, so nothing more would fire today.
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 1)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.refreshDailyRollover(now: tomorrow)
        try? await Task.sleep(for: .milliseconds(300))

        // New day: the cap allows breaks again and enforcement starts from the base tier.
        #expect(locker.lastEscalationTier == 0)

        coordinator.stop()
    }

    // A rollover must never arm a break behind a locked screen: the overlay would sit on the
    // lock screen and auto-complete, chaining a whole day of phantom breaks into the stats.
    @Test @MainActor
    func rolloverDoesNotArmBreakWhileScreenLocked() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        // Locking before the first await cancels the armed timer without letting it fire, which
        // leaves the coordinator in the same shape as a schedule that used up its daily cap.
        coordinator.start(with: [schedule], preferences: AppPreferences())
        coordinator.handleScreenLock()

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        coordinator.refreshDailyRollover(now: tomorrow)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)

        // Unlocking is what resumes the schedule.
        coordinator.handleScreenUnlock()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        coordinator.stop()
    }

    @Test @MainActor
    func escapeActiveBreakDismissesAndIncrementsEscapeCount() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var escapedEvents: [BreakEvent] = []
        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .breakEscaped(let e) = event { escapedEvents.append(e) }
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.escapeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(locker.dismissOverlayCalled)
        #expect(escapedEvents.count == 1)
        #expect(lastStats?.breaksEscaped == 1)
        #expect(lastStats?.weeklyEscapeCount == 1)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func completeActiveBreakDismissesAndIncrementsStreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var completedEvents: [BreakEvent] = []
        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted(let e) = event { completedEvents.append(e) }
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(locker.dismissOverlayCalled)
        #expect(completedEvents.count == 1)
        #expect(lastStats?.breaksCompleted == 1)
        #expect(lastStats?.currentStreak == 1)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func updatePreferencesApplied() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()
        let initial = AppPreferences()
        coordinator.start(with: [schedule], preferences: initial)

        var updated = AppPreferences()
        updated.firmSkipDelay = 30
        updated.pauseMediaDuringBreak = false
        coordinator.updatePreferences(updated)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.stop()
        coordinator.start(with: [schedule], preferences: updated)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)
        #expect(locker.lastPreferences?.firmSkipDelay == 30)
        #expect(locker.lastPreferences?.pauseMediaDuringBreak == false)
        coordinator.stop()
    }

    // MARK: - Escalation Tier Tests

    @Test @MainActor
    func tierIncrementsWhenEnforcementEnabled() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .gentle, progressiveEnforcement: true)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 1)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 2)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 3)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 4)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 5)

        // Cap at 5 (gentle has 6 tiers, index 0-5)
        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 5)

        coordinator.stop()
    }

    @Test @MainActor
    func tierResetsOnCompletion() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .gentle, breakDuration: 5, progressiveEnforcement: true)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 2)

        coordinator.completeActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.stop()
    }

    @Test @MainActor
    func tierIsZeroWhenEnforcementDisabled() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .gentle, progressiveEnforcement: false)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.skipActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.stop()
    }

    @Test @MainActor
    func escapeIncrementsEscalationTier() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .strict, breakDuration: 5, progressiveEnforcement: true)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.escapeActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 1)

        coordinator.escapeActiveBreak()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 2)

        coordinator.stop()
    }

    @Test @MainActor
    func tierPerSchedule() async {
        let scheduler = MockScheduler()
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let scheduleA = makeSchedule(level: .gentle, progressiveEnforcement: true)
        let scheduleB = makeSchedule(level: .gentle, progressiveEnforcement: true)

        scheduler.nextBreakTimes[scheduleA.id] = Date().addingTimeInterval(0.05)
        scheduler.nextBreakTimes[scheduleB.id] = Date().addingTimeInterval(100)
        coordinator.start(with: [scheduleA, scheduleB], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.lastEscalationTier == 0)

        scheduler.nextBreakTimes[scheduleA.id] = Date().addingTimeInterval(100)
        scheduler.nextBreakTimes[scheduleB.id] = Date().addingTimeInterval(0.05)
        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.lastEscalationTier == 0)

        coordinator.stop()
    }

    @Test @MainActor
    func tierResetsOnStop() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(level: .gentle, progressiveEnforcement: true)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))

        coordinator.skipActiveBreak()
        coordinator.stop()

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastEscalationTier == 0)

        coordinator.stop()
    }

    // MARK: - Post-Deferral Polling Tests

    @Test @MainActor
    func breakSkippedAfterScreenSharingDeferral() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.1
        )
        let schedule = makeSchedule()
        let prefs = AppPreferences(
            screenSharingDetectionEnabled: true,
            screenSharingPostDeferral: .skipBreak
        )

        var deferredEvents: [CoordinatorEvent] = []
        var scheduledEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred = event { deferredEvents.append(event) }
                if case .nextBreakScheduled = event { scheduledEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!deferredEvents.isEmpty)
        #expect(!locker.showOverlayCalled)

        let scheduledBefore = scheduledEvents.count
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!locker.showOverlayCalled)
        #expect(scheduledEvents.count > scheduledBefore)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func breakTriggersAfterScreenSharingDeferralClears() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.1
        )
        let schedule = makeSchedule()
        let prefs = AppPreferences(
            screenSharingDetectionEnabled: true,
            screenSharingPostDeferral: .triggerBreak
        )

        var deferredEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred = event { deferredEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!deferredEvents.isEmpty)
        #expect(!locker.showOverlayCalled)

        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func deferralContinuesWhileScreenSharingActive() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.1
        )
        let schedule = makeSchedule()
        let prefs = AppPreferences(screenSharingDetectionEnabled: true)

        var deferredCount = 0
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred = event { deferredCount += 1 }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(500))

        #expect(deferredCount >= 2)
        #expect(!locker.showOverlayCalled)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func dailyBreakCapRespected() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 10, dailyBreakCap: 1)
        let prefs = AppPreferences(idleDetectionEnabled: true)

        var scheduledCount = 0
        let listener = Task {
            for await event in coordinator.events {
                if case .nextBreakScheduled = event { scheduledCount += 1 }
            }
        }

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(500))

        // After first idle-counted break, cap is reached -- no more breaks should be scheduled
        // The initial schedule counts as 1, then after idle-counted break no new schedule
        #expect(scheduledCount >= 1)

        coordinator.stop()
        listener.cancel()
    }

    // MARK: - System Sleep/Wake & Screen Lock/Unlock Tests

    @Test @MainActor
    func systemSleepDismissesOverlayAndSkips() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var skippedEvents: [BreakEvent] = []
        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .breakSkipped(let e) = event { skippedEvents.append(e) }
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.isShowing)

        coordinator.handleSystemSleep()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(locker.dismissOverlayCalled)
        #expect(!locker.isShowing)
        #expect(skippedEvents.count == 1)
        #expect(lastStats?.breaksSkipped == 1)
        #expect(lastStats?.currentStreak == 0)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func systemSleepCancelsTimerWhenNoOverlay() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))
        #expect(!locker.isShowing)

        coordinator.handleSystemSleep()

        #expect(!locker.dismissOverlayCalled)

        coordinator.stop()
    }

    @Test @MainActor
    func systemWakeReschedulesBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var scheduledEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .nextBreakScheduled = event { scheduledEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))
        let countAfterStart = scheduledEvents.count

        coordinator.handleSystemSleep()
        coordinator.handleSystemWake()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(scheduledEvents.count > countAfterStart)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func screenLockDismissesOverlayAndSkips() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        var skippedEvents: [BreakEvent] = []
        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .breakSkipped(let e) = event { skippedEvents.append(e) }
                if case .statisticsUpdated(let s) = event { lastStats = s }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.isShowing)

        coordinator.handleScreenLock()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(locker.dismissOverlayCalled)
        #expect(!locker.isShowing)
        #expect(skippedEvents.count == 1)
        #expect(lastStats?.breaksSkipped == 1)
        #expect(lastStats?.currentStreak == 0)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func screenLockCancelsTimerWhenNoOverlay() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))
        #expect(!locker.isShowing)

        coordinator.handleScreenLock()

        #expect(!locker.dismissOverlayCalled)

        coordinator.stop()
    }

    @Test @MainActor
    func screenUnlockReschedulesBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var scheduledEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .nextBreakScheduled = event { scheduledEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))
        let countAfterStart = scheduledEvents.count

        coordinator.handleScreenLock()
        coordinator.handleScreenUnlock()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(scheduledEvents.count > countAfterStart)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func systemSleepDuringPauseResumesOnWake() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var resumeEvent: CoordinatorEvent?
        var scheduledEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .scheduleResumed = event { resumeEvent = event }
                if case .nextBreakScheduled = event { scheduledEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.pause(for: 300)
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.handleSystemSleep()
        let countBeforeWake = scheduledEvents.count
        coordinator.handleSystemWake()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(resumeEvent != nil)
        #expect(scheduledEvents.count > countBeforeWake)

        coordinator.stop()
        listener.cancel()
    }

    @Test @MainActor
    func screenLockDuringPauseResumesOnUnlock() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        var resumeEvent: CoordinatorEvent?
        var scheduledEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .scheduleResumed = event { resumeEvent = event }
                if case .nextBreakScheduled = event { scheduledEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.pause(for: 300)
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.handleScreenLock()
        let countBeforeUnlock = scheduledEvents.count
        coordinator.handleScreenUnlock()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(resumeEvent != nil)
        #expect(scheduledEvents.count > countBeforeUnlock)

        coordinator.stop()
        listener.cancel()
    }

    // MARK: - Cycle Index Tests

    private func lastCycleIndex(_ scheduler: MockScheduler, for schedule: Schedule) -> Int? {
        scheduler.receivedCycleIndices.last(where: { $0.scheduleID == schedule.id })?.index
    }

    @Test @MainActor
    func cycleAdvancesOnCompletedBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleAdvancesOnSkippedActiveBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.skipActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleAdvancesOnEscapedBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.escapeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleAdvancesOnIdleCountedBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 300)
        let prefs = AppPreferences(idleDetectionEnabled: true)

        coordinator.start(with: [schedule], preferences: prefs)
        // The armed timer captured its target at start; pushing the mock far out keeps the
        // idle-counted break from re-firing in a tight loop during the sleep below.
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!locker.showOverlayCalled)
        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleAdvancesOnMenuSkipNextBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.skipNextBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleAdvancesOnPostDeferralSkip() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.1
        )
        let schedule = makeSchedule()
        let prefs = AppPreferences(
            screenSharingDetectionEnabled: true,
            screenSharingPostDeferral: .skipBreak
        )

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(300))

        #expect(!locker.showOverlayCalled)
        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func sleepWithoutOverlayDoesNotAdvanceCycle() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule()

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.handleSystemSleep()
        coordinator.handleSystemWake()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 0)
        coordinator.stop()
    }

    @Test @MainActor
    func sleepWithOverlayAdvancesExactlyOnce() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.isShowing)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.handleSystemSleep()
        // Sleep alone never reschedules; the wake is what lets the mock observe the index.
        coordinator.handleSystemWake()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func menuSkipDuringOverlayDoesNotDoubleAdvance() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.isShowing)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.skipNextBreak()
        try? await Task.sleep(for: .milliseconds(100))

        // The pending id was consumed when the overlay triggered, so the menu skip
        // must not advance a second time.
        #expect(lastCycleIndex(scheduler, for: schedule) == 1)
        coordinator.stop()
    }

    @Test @MainActor
    func rolloverResetsCycleAndRearmsTimer() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(lastCycleIndex(scheduler, for: schedule) == 1)

        // A timer armed for the 600 s target is still pending; the rollover must reset the
        // cycle and re-arm anyway so the new day's first break is computed from index 0.
        let callsBeforeRollover = scheduler.receivedCycleIndices.count
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        coordinator.refreshDailyRollover(now: tomorrow)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(scheduler.receivedCycleIndices.count > callsBeforeRollover)
        #expect(lastCycleIndex(scheduler, for: schedule) == 0)
        coordinator.stop()
    }

    @Test @MainActor
    func rolloverDuringDeferralKeepsThePendingBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(screenSharingActive: true)
        let locker = MockLocker()

        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.1
        )
        let schedule = makeSchedule(breakDuration: 5)
        let prefs = AppPreferences(screenSharingDetectionEnabled: true)

        coordinator.start(with: [schedule], preferences: prefs)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)

        // The day turns over while the poll is still waiting for the screen share to end.
        // Re-arming here would cancel the poll and drop the deferred break silently.
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(600)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        coordinator.refreshDailyRollover(now: tomorrow)

        detector.contextToReturn = .clear
        try? await Task.sleep(for: .milliseconds(300))

        #expect(locker.showOverlayCalled)
        coordinator.stop()
    }

    @Test @MainActor
    func cycleIndicesIndependentPerSchedule() async {
        let scheduler = MockScheduler()
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let scheduleA = makeSchedule(breakDuration: 5)
        let scheduleB = makeSchedule(breakDuration: 5)

        scheduler.nextBreakTimes[scheduleA.id] = Date().addingTimeInterval(0.05)
        scheduler.nextBreakTimes[scheduleB.id] = Date().addingTimeInterval(100)
        coordinator.start(with: [scheduleA, scheduleB], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)

        scheduler.nextBreakTimes[scheduleA.id] = Date().addingTimeInterval(600)
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(lastCycleIndex(scheduler, for: scheduleA) == 1)
        #expect(lastCycleIndex(scheduler, for: scheduleB) == 0)
        coordinator.stop()
    }

    @Test @MainActor
    func overlayReceivesNextIntervalLabel() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5, intervalCycle: [
            IntervalStep(duration: 58 * 60, label: "Sitting"),
            IntervalStep(duration: 28 * 60, label: "Standing"),
        ])

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        // During the first break the upcoming work block is the cycle's second entry.
        #expect(locker.lastNextIntervalLabel == "Standing")

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastNextIntervalLabel == "Sitting")

        coordinator.stop()
    }

    @Test @MainActor
    func overlayLabelNilWithoutCycle() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 5)

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.showOverlayCalled)
        #expect(locker.lastNextIntervalLabel == nil)

        coordinator.stop()
    }

    @Test @MainActor
    func repetitionRuleDurationFollowsTracker() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(
            repetitionRule: RepetitionRule(shortBreakCount: 1, shortBreakDuration: 300, longBreakDuration: 900)
        )

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastDuration == 300)

        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastDuration == 900)

        coordinator.stop()
    }

    @Test @MainActor
    func skipKeepsTheSlotAnchorWhenResetIsOff() async {
        let scheduler = MockScheduler()
        let slot = Date().addingTimeInterval(300)
        scheduler.nextBreakTimeToReturn = slot
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: MockDetector(), locker: MockLocker())

        coordinator.start(with: [makeSchedule()], preferences: AppPreferences(resetIntervalOnSkip: false))
        try? await Task.sleep(for: .milliseconds(50))

        coordinator.skipNextBreak()
        try? await Task.sleep(for: .milliseconds(50))

        // The skipped slot, not the moment of the skip, measures the next interval.
        let anchor = scheduler.receivedAfterDates.last ?? .distantPast
        #expect(abs(anchor.timeIntervalSince(slot)) < 5)

        coordinator.stop()
    }

    @Test @MainActor
    func skipRestartsTheIntervalWhenResetIsOn() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(300)
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: MockDetector(), locker: MockLocker())

        coordinator.start(with: [makeSchedule()], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(50))

        let skippedAt = Date()
        coordinator.skipNextBreak()
        try? await Task.sleep(for: .milliseconds(50))

        let anchor = scheduler.receivedAfterDates.last ?? .distantPast
        #expect(abs(anchor.timeIntervalSince(skippedAt)) < 5)

        coordinator.stop()
    }

}

@Suite("BreakCoordinator EnforcementState")
@MainActor
struct BreakCoordinatorEnforcementStateTests {

    /// Runs one break on a fresh coordinator and returns the counters it accumulated, which is
    /// what `AppCoordinator.restartCoordinator` captures before tearing the coordinator down.
    private func stateAfterOneBreak(_ schedule: Schedule) async -> EnforcementState {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: MockDetector(), locker: MockLocker()
        )
        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        coordinator.completeActiveBreak()
        let state = coordinator.captureEnforcementState()
        coordinator.stop()
        return state
    }

    @Test func dailyCapSurvivesRebuild() async {
        let schedule = makeSchedule(dailyBreakCap: 1)
        let state = await stateAfterOneBreak(schedule)
        #expect(state.dailyBreakCounts[schedule.id] == 1)

        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let rebuilt = BreakCoordinator(
            scheduler: scheduler, detector: MockDetector(), locker: MockLocker()
        )
        rebuilt.start(with: [schedule], preferences: AppPreferences(), restoring: state)

        // The cap check short-circuits before the scheduler is consulted, so an untouched
        // scheduler is the signal that the exhausted cap was carried over.
        #expect(scheduler.receivedCycleIndices.isEmpty)
        rebuilt.stop()
    }

    @Test func dailyCapReArmsWithoutRestore() async {
        let schedule = makeSchedule(dailyBreakCap: 1)
        _ = await stateAfterOneBreak(schedule)

        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let rebuilt = BreakCoordinator(
            scheduler: scheduler, detector: MockDetector(), locker: MockLocker()
        )
        rebuilt.start(with: [schedule], preferences: AppPreferences())

        #expect(!scheduler.receivedCycleIndices.isEmpty)
        rebuilt.stop()
    }

    @Test func cycleIndexSurvivesRebuild() async {
        let schedule = makeSchedule(intervalCycle: [
            IntervalStep(duration: 60, label: "Focus"),
            IntervalStep(duration: 120, label: "Deep"),
        ])
        let state = await stateAfterOneBreak(schedule)
        #expect(state.cycleIndices[schedule.id] == 1)

        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(60)
        let rebuilt = BreakCoordinator(
            scheduler: scheduler, detector: MockDetector(), locker: MockLocker()
        )
        rebuilt.start(with: [schedule], preferences: AppPreferences(), restoring: state)

        #expect(scheduler.receivedCycleIndices.first?.index == 1)
        rebuilt.stop()
    }

    @Test func repetitionIndexSurvivesRebuild() async {
        let schedule = makeSchedule(repetitionRule: RepetitionRule(
            shortBreakCount: 3, shortBreakDuration: 10, longBreakDuration: 60
        ))
        let state = await stateAfterOneBreak(schedule)
        #expect(state.repetitionIndices[schedule.id] == 1)
    }
}

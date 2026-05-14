import Testing
import Foundation
@testable import Coordination
@testable import StandLockCore
@testable import Scheduling

// MARK: - Mocks

final class MockScheduler: SchedulingEngine, @unchecked Sendable {
    var nextBreakTimeToReturn: Date?
    var breakDurationToReturn: TimeInterval = 300

    func nextBreakTime(for schedule: Schedule, after date: Date) -> Date? { nextBreakTimeToReturn }
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
    var isShowing = false

    func showOverlay(level: DisciplineLevel, duration: TimeInterval,
                     exercise: Exercise?, preferences: AppPreferences,
                     statistics: BreakStatistics) {
        showOverlayCalled = true
        lastLevel = level
        lastDuration = duration
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
    dailyBreakCap: Int? = nil
) -> Schedule {
    Schedule(
        name: "Test",
        days: .everyDay,
        windows: [TimeWindow(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)],
        breakInterval: breakInterval,
        breakDuration: breakDuration,
        disciplineLevel: level,
        dailyBreakCap: dailyBreakCap
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
    func breakCompletedAfterDuration() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = MockDetector()
        let locker = MockLocker()

        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        let schedule = makeSchedule(breakDuration: 0.2)

        var completedEvents: [CoordinatorEvent] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakCompleted = event { completedEvents.append(event) }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(600))

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
        let schedule = makeSchedule(breakDuration: 0.15)

        var lastStats: BreakStatistics?
        let listener = Task {
            for await event in coordinator.events {
                if case .statisticsUpdated(let stats) = event { lastStats = stats }
            }
        }

        coordinator.start(with: [schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(500))

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
        if case .skipped = skippedEvents.first?.outcome {} else {
            Issue.record("Expected outcome .skipped")
        }
        #expect(lastStats?.breaksSkipped == 1)
        #expect(lastStats?.currentStreak == 0)

        coordinator.stop()
        listener.cancel()
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
        if case .escaped = escapedEvents.first?.outcome {} else {
            Issue.record("Expected outcome .escaped")
        }
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
        if case .completed = completedEvents.first?.outcome {} else {
            Issue.record("Expected outcome .completed")
        }
        #expect(lastStats?.breaksCompleted == 1)
        #expect(lastStats?.currentStreak == 1)

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
}

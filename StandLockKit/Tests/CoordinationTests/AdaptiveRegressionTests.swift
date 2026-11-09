import Foundation
import Testing
@testable import Coordination
import StandLockCore

@Suite("Adaptive regression tests")
@MainActor
struct AdaptiveRegressionTests {
    @Test func unlockedInactivityDoesNotCompleteBreak() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.01)
        let detector = MockDetector()
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: detector, locker: locker)
        coordinator.start(with: [makeSchedule()], preferences: AppPreferences())
        #expect(await waitUntil { locker.isShowing })
        coordinator.stop()
    }

    @Test func lockingAnActiveBreakDoesNotRecordASkip() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.01)
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: MockDetector(), locker: locker)
        var skipped = false
        let listener = Task {
            for await event in coordinator.events {
                if case .breakSkipped = event { skipped = true }
            }
        }
        coordinator.start(with: [makeSchedule()], preferences: AppPreferences())
        #expect(await waitUntil { locker.isShowing })
        coordinator.handleScreenLock()
        await Task.yield()
        #expect(!skipped)
        coordinator.stop()
        listener.cancel()
    }
}

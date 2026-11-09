import Testing
import Foundation
@testable import Coordination
@testable import StandLockCore

/// Collects what the coordinator reports, for checks after the fact.
@MainActor
final class EventLog {
    private(set) var events: [CoordinatorEvent] = []
    private var task: Task<Void, Never>?

    init(_ coordinator: BreakCoordinator) {
        task = Task { [weak self] in
            for await event in coordinator.events { self?.events.append(event) }
        }
    }

    deinit { task?.cancel() }

    var stats: BreakStatistics? {
        events.reversed().lazy.compactMap { if case .statisticsUpdated(let s) = $0 { s } else { nil } }.first
    }

    var completed: Int { stats?.breaksCompleted ?? 0 }
    var skipped: Int { stats?.breaksSkipped ?? 0 }

    var statuses: [PomodoroStatus?] {
        events.compactMap { if case .pomodoroChanged(let s) = $0 { .some(s) } else { nil } }
    }

    var nextBreaks: [Date] {
        events.compactMap { if case .nextBreakScheduled(let d) = $0 { d } else { nil } }
    }
}

@MainActor
private func makeCoordinator(
    schedules: [Schedule] = [],
    preferences: AppPreferences = AppPreferences(postponeReturnDelay: 0.1, idleDetectionEnabled: false),
    scheduler: MockScheduler = MockScheduler()
) -> (BreakCoordinator, MockDetector, MockLocker, EventLog) {
    let detector = MockDetector()
    let locker = MockLocker()
    let coordinator = BreakCoordinator(
        scheduler: scheduler, detector: detector, locker: locker, deferralPollingInterval: 0.05
    )
    let log = EventLog(coordinator)
    coordinator.start(with: schedules, preferences: preferences)
    return (coordinator, detector, locker, log)
}

private let chip = PomodoroChip(round: 2, rounds: 4, isLong: false)

@Suite("BreakCoordinator external breaks")
@MainActor
struct ExternalBreakTests {

    @Test
    func externalBreakShowsOverlayWithChip() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 120, level: .firm, chip: chip))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastPomodoroChip == chip)
        #expect(locker.lastLevel == .firm)
        #expect(locker.lastDuration == TimeInterval(120))
        #expect(locker.lastEscalationTier == 0)
        #expect(locker.lastNextIntervalLabel == nil)
    }

    @Test
    func externalBreakDurationIsBounded() async {
        let (coordinator, _, locker, _) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 366 * 86_400, level: .strict, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        #expect(locker.lastDuration == BreakSafety.maximumBreakDuration)
    }

    @Test
    func externalBreakDoneCountsOnce() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        coordinator.completeActiveBreak()
        coordinator.completeActiveBreak()
        #expect(await waitUntil { log.completed == 1 })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.completed == 1)
        #expect(!locker.isShowing)
    }

    @Test
    func externalBreakSkipCountsSkip() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { locker.isShowing })
        coordinator.skipActiveBreak()
        #expect(await waitUntil { log.skipped == 1 })
        #expect(log.completed == 0)
    }

    @Test
    func externalBreakPostponeReturnsWithoutRecount() async {
        let (coordinator, _, locker, log) = makeCoordinator()
        defer { coordinator.stop() }
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: chip))
        #expect(await waitUntil { locker.isShowing })
        coordinator.postponeActiveBreak()
        #expect(!locker.isShowing)
        #expect(await waitUntil { locker.showCount == 2 })
        #expect(locker.lastCanPostpone == false)
        #expect(locker.lastPomodoroChip == chip)
        coordinator.completeActiveBreak()
        #expect(await waitUntil { log.completed == 1 })
        #expect(log.skipped == 0)
        #expect(log.stats?.breaksDeferred == 1)
    }

    @Test
    func externalBreakIdleCreditCountsOnceAndShowsNoOverlay() async {
        let (coordinator, detector, locker, log) = makeCoordinator(preferences: AppPreferences(idleDetectionEnabled: true))
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(idleDuration: 600)
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        #expect(await waitUntil { log.completed == 1 })
        coordinator.completeActiveBreak()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(log.completed == 1)
        #expect(!locker.showOverlayCalled)
    }

    @Test
    func externalBreakDefersDuringDetection() async {
        let (coordinator, detector, locker, _) = makeCoordinator(
            preferences: AppPreferences(cameraDetection: .deferBreak, idleDetectionEnabled: false)
        )
        defer { coordinator.stop() }
        detector.contextToReturn = DetectionContext(cameraActive: true)
        coordinator.startExternalBreak(ExternalBreak(duration: 60, level: .gentle, chip: nil))
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!locker.showOverlayCalled)
        detector.contextToReturn = .clear
        #expect(await waitUntil { locker.isShowing })
    }
}

import SwiftUI
import Coordination
import StandLockCore
import Scheduling
import Detection

@Observable
@MainActor
final class AppCoordinator {
    var nextBreakTime: Date?
    var isBreakActive: Bool = false
    var currentBreakRemaining: TimeInterval = 0
    var currentLevel: DisciplineLevel = .gentle
    var todayStats: BreakStatistics = BreakStatistics()
    var isPaused: Bool = false
    var pausedUntil: Date?
    var schedules: [Schedule] = []
    var preferences: AppPreferences = AppPreferences()
    var hasCompletedOnboarding: Bool = false

    private var coordinator: BreakCoordinator?
    private let overlayController = OverlayWindowController()
    private var eventListenerTask: Task<Void, Never>?

    init() {
        loadData()
        if !schedules.isEmpty {
            startCoordinator()
        }
    }

    // MARK: - Persistence

    private func loadData() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if let data = UserDefaults.standard.data(forKey: "schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            schedules = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "statistics"),
           let decoded = try? JSONDecoder().decode(BreakStatistics.self, from: data) {
            todayStats = decoded
            todayStats.resetWeeklyIfNeeded(currentDate: Date())
        }
    }

    func saveSchedules() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        UserDefaults.standard.set(data, forKey: "schedules")
    }

    func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: "preferences")
    }

    func saveStatistics() {
        guard let data = try? JSONEncoder().encode(todayStats) else { return }
        UserDefaults.standard.set(data, forKey: "statistics")
    }

    // MARK: - Coordinator Lifecycle

    private func startCoordinator() {
        let scheduler = ScheduleEvaluator()
        let detector = CompositeDetector(
            calendar: CalendarDetector(lookAheadMinutes: preferences.calendarLookAheadMinutes)
        )
        let breakCoordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: overlayController
        )
        self.coordinator = breakCoordinator
        breakCoordinator.start(with: schedules.filter(\.isEnabled), preferences: preferences)

        eventListenerTask = Task {
            for await event in breakCoordinator.events {
                handleEvent(event)
            }
        }
    }

    private func stopCoordinator() {
        eventListenerTask?.cancel()
        eventListenerTask = nil
        coordinator?.stop()
        coordinator = nil
    }

    private func restartCoordinator() {
        stopCoordinator()
        if !schedules.filter(\.isEnabled).isEmpty {
            startCoordinator()
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: CoordinatorEvent) {
        switch event {
        case .nextBreakScheduled(let date):
            nextBreakTime = date

        case .breakStarted(let e):
            isBreakActive = true
            currentBreakRemaining = e.duration
            currentLevel = e.level

        case .breakCompleted, .breakSkipped, .breakEscaped:
            isBreakActive = false
            currentBreakRemaining = 0

        case .breakDeferred:
            break

        case .schedulePaused(let until):
            isPaused = true
            pausedUntil = until

        case .scheduleResumed:
            isPaused = false
            pausedUntil = nil

        case .statisticsUpdated(let stats):
            todayStats = stats
            saveStatistics()
        }
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
        saveSchedules()
        restartCoordinator()
    }

    func updateSchedule(_ schedule: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
            restartCoordinator()
        }
    }

    func deleteSchedule(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
        restartCoordinator()
    }

    // MARK: - Quick Actions

    func skipNextBreak() {
        coordinator?.skipNextBreak()
    }

    func pauseSchedule(for duration: TimeInterval) {
        coordinator?.pause(for: duration)
    }

    func resumeSchedule() {
        coordinator?.resume()
    }

    func changeDisciplineLevel(_ level: DisciplineLevel) {
        coordinator?.changeDisciplineLevel(level)
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

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
    private var loadedExercises: [Exercise] = []

    init() {
        loadExercises()
        loadData()
        if !schedules.isEmpty {
            startCoordinator()
        }
    }

    private func loadExercises() {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else { return }
        loadedExercises = decoded
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
        breakCoordinator.exercises = loadedExercises

        overlayController.onSkip = { [weak breakCoordinator] in
            breakCoordinator?.skipActiveBreak()
        }
        overlayController.onComplete = { [weak breakCoordinator] in
            breakCoordinator?.completeActiveBreak()
        }
        overlayController.onEscape = { [weak breakCoordinator] in
            breakCoordinator?.escapeActiveBreak()
        }

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
        overlayController.onSkip = nil
        overlayController.onComplete = nil
        overlayController.onEscape = nil
    }

    private func restartCoordinator() {
        stopCoordinator()
        isPaused = false
        pausedUntil = nil
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
        isPaused = false
        pausedUntil = nil
        if let coordinator {
            coordinator.resume()
        } else if !schedules.filter(\.isEnabled).isEmpty {
            startCoordinator()
        }
    }

    func changeDisciplineLevel(_ level: DisciplineLevel) {
        coordinator?.changeDisciplineLevel(level)
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func createDefaultSchedule() {
        let defaultSchedule = Schedule(
            name: "Work Hours",
            days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 45 * 60,
            breakDuration: 5 * 60,
            disciplineLevel: .gentle
        )
        addSchedule(defaultSchedule)
    }
}

import Foundation
import Testing
@testable import StandLockCore

@Suite("Schedule Model Tests")
struct ScheduleModelTests {

    // MARK: - TimeWindow

    @Test func timeWindowContains() {
        let window = TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        #expect(window.contains(hour: 10, minute: 30))
        #expect(window.contains(hour: 9, minute: 0))
        #expect(!window.contains(hour: 8, minute: 59))
        #expect(!window.contains(hour: 17, minute: 0)) // exclusive end
        #expect(!window.contains(hour: 20, minute: 0))
    }

    // MARK: - DaySelection

    @Test func daySelectionActiveDays() {
        let weekdays = DaySelection.weekdays.activeDays
        #expect(weekdays.count == 5)
        #expect(weekdays.contains(.monday))
        #expect(weekdays.contains(.friday))
        #expect(!weekdays.contains(.saturday))
        #expect(!weekdays.contains(.sunday))

        let weekends = DaySelection.weekends.activeDays
        #expect(weekends.count == 2)
        #expect(weekends.contains(.saturday))
        #expect(weekends.contains(.sunday))

        let everyDay = DaySelection.everyDay.activeDays
        #expect(everyDay.count == 7)

        let custom = DaySelection.custom([.monday, .wednesday, .friday]).activeDays
        #expect(custom.count == 3)
        #expect(!custom.contains(.tuesday))
    }

    // MARK: - JSON Round-Trips

    @Test func scheduleJsonRoundTrip() throws {
        let schedule = Schedule(
            name: "Work Hours", isEnabled: true,
            days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 2400, breakDuration: 600,
            repetitionRule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 600, longBreakDuration: 1800),
            disciplineLevel: .firm,
            dailyBreakCap: 10
        )
        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(Schedule.self, from: data)
        #expect(decoded == schedule)
        #expect(decoded.name == "Work Hours")
        #expect(decoded.disciplineLevel == .firm)
        #expect(decoded.repetitionRule?.shortBreakCount == 3)
        #expect(decoded.dailyBreakCap == 10)
    }

    @Test func repetitionRuleEncoding() throws {
        let rule = RepetitionRule(shortBreakCount: 4, shortBreakDuration: 300, longBreakDuration: 900)
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(RepetitionRule.self, from: data)
        #expect(decoded == rule)
        #expect(decoded.shortBreakCount == 4)
        #expect(decoded.longBreakDuration == 900)
    }

    // MARK: - DetectionContext

    @Test func detectionContextShouldDefer() {
        let cameraActive = DetectionContext(cameraActive: true)
        #expect(cameraActive.shouldDefer)
        #expect(cameraActive.deferralReason == .cameraActive)

        let allClear = DetectionContext.clear
        #expect(!allClear.shouldDefer)
        #expect(allClear.deferralReason == nil)

        // Focus mode alone does NOT trigger shouldDefer
        let focusOnly = DetectionContext(focusModeActive: true)
        #expect(!focusOnly.shouldDefer)
        #expect(focusOnly.deferralReason == .focusMode)

        let micActive = DetectionContext(microphoneActive: true)
        #expect(micActive.shouldDefer)
        #expect(micActive.deferralReason == .microphoneActive)
    }

    // MARK: - BreakStatistics

    @Test func breakStatisticsCompletionRate() {
        var stats = BreakStatistics()
        stats.breaksCompleted = 3
        stats.breaksSkipped = 1
        #expect(stats.totalBreaks == 4)
        #expect(stats.completionRate == 0.75)

        let emptyStats = BreakStatistics()
        #expect(emptyStats.completionRate == 0)
    }

    @Test func breakStatisticsWeeklyReset() {
        var stats = BreakStatistics(date: Date())
        stats.weeklyEscapeCount = 5

        // Same week: should NOT reset
        stats.resetWeeklyIfNeeded(currentDate: Date())
        #expect(stats.weeklyEscapeCount == 5)

        // Next week: should reset
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        stats.resetWeeklyIfNeeded(currentDate: nextWeek)
        #expect(stats.weeklyEscapeCount == 0)
    }

    // MARK: - AppPreferences

    @Test func appPreferencesJsonRoundTrip() throws {
        let prefs = AppPreferences(
            firmSkipDelay: 15,
            firmEscapePhrase: "Let me work",
            firmDailySkipLimit: 3,
            strictEscapeHoldDuration: 8,
            cameraDetection: .reduceToGentle,
            microphoneDetection: .ignore,
            calendarDetectionEnabled: false,
            calendarLookAheadMinutes: 10,
            screenSharingDetectionEnabled: false,
            focusModeDetection: .ignore,
            idleDetectionEnabled: false,
            resetIntervalOnSkip: false
        )
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded == prefs)
        #expect(decoded.firmSkipDelay == 15)
        #expect(decoded.cameraDetection == .reduceToGentle)
        #expect(decoded.microphoneDetection == .ignore)
        #expect(!decoded.calendarDetectionEnabled)
        #expect(!decoded.resetIntervalOnSkip)
    }
}

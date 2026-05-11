import Foundation
import Testing
@testable import Scheduling
@testable import StandLockCore

// MARK: - Helpers

private func makeDate(year: Int = 2026, month: Int = 5, day: Int, hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = year; components.month = month; components.day = day
    components.hour = hour; components.minute = minute; components.second = 0
    components.timeZone = Calendar.current.timeZone
    return Calendar.current.date(from: components)!
}

private func makeSchedule(
    days: DaySelection = .weekdays,
    windows: [TimeWindow] = [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
    breakInterval: TimeInterval = 2400,
    breakDuration: TimeInterval = 600,
    repetitionRule: RepetitionRule? = nil,
    disciplineLevel: DisciplineLevel = .gentle,
    dailyBreakCap: Int? = nil
) -> Schedule {
    Schedule(
        name: "Test", days: days, windows: windows,
        breakInterval: breakInterval, breakDuration: breakDuration,
        repetitionRule: repetitionRule, disciplineLevel: disciplineLevel,
        dailyBreakCap: dailyBreakCap
    )
}

// MARK: - ScheduleEvaluator Tests

@Suite("ScheduleEvaluator Tests")
struct ScheduleEvaluatorTests {
    let evaluator = ScheduleEvaluator()

    // 2026-05-11 is Monday, 2026-05-12 is Tuesday

    @Test func isWithinActiveWindow_weekdayAt10am() {
        let monday10am = makeDate(day: 11, hour: 10)
        let schedule = makeSchedule()
        #expect(evaluator.isWithinActiveWindow(schedule, at: monday10am))
    }

    @Test func isWithinActiveWindow_weekdayOnSaturday() {
        let saturday = makeDate(day: 16, hour: 10) // 2026-05-16 is Saturday
        let schedule = makeSchedule()
        #expect(!evaluator.isWithinActiveWindow(schedule, at: saturday))
    }

    @Test func isWithinActiveWindow_outsideTimeWindow() {
        let monday20 = makeDate(day: 12, hour: 20)
        let schedule = makeSchedule()
        #expect(!evaluator.isWithinActiveWindow(schedule, at: monday20))
    }

    @Test func isWithinActiveWindow_multipleWindows() {
        let schedule = makeSchedule(windows: [
            TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0),
            TimeWindow(startHour: 14, startMinute: 0, endHour: 18, endMinute: 0),
        ])
        let monday13 = makeDate(day: 12, hour: 13) // gap
        let monday15 = makeDate(day: 12, hour: 15) // second window
        #expect(!evaluator.isWithinActiveWindow(schedule, at: monday13))
        #expect(evaluator.isWithinActiveWindow(schedule, at: monday15))
    }

    @Test func isWithinActiveWindow_customDays() {
        let schedule = makeSchedule(days: .custom([.monday, .wednesday, .friday]))
        let tuesday = makeDate(day: 12, hour: 10) // 2026-05-12 is Tuesday
        let wednesday = makeDate(day: 13, hour: 10) // 2026-05-13 is Wednesday
        #expect(!evaluator.isWithinActiveWindow(schedule, at: tuesday))
        #expect(evaluator.isWithinActiveWindow(schedule, at: wednesday))
    }

    @Test func nextBreakTime_simpleInterval() {
        let monday9am = makeDate(day: 12, hour: 9)
        let schedule = makeSchedule(breakInterval: 2400) // 40 min
        let next = evaluator.nextBreakTime(for: schedule, after: monday9am)
        #expect(next != nil)
        let diff = next!.timeIntervalSince(monday9am)
        #expect(diff == 2400)
    }

    @Test func nextBreakTime_multipleBreaks() {
        let monday9_40 = makeDate(day: 12, hour: 9, minute: 40)
        let schedule = makeSchedule(breakInterval: 2400)
        let next = evaluator.nextBreakTime(for: schedule, after: monday9_40)
        #expect(next != nil)
        let expected = makeDate(day: 12, hour: 10, minute: 20)
        #expect(abs(next!.timeIntervalSince(expected)) < 1)
    }

    @Test func nextBreakTime_endOfWindow() {
        let monday16_50 = makeDate(day: 12, hour: 16, minute: 50)
        let schedule = makeSchedule(breakInterval: 2400) // 40 min would go past 17:00
        let next = evaluator.nextBreakTime(for: schedule, after: monday16_50)
        #expect(next != nil)
        // Should be next day's window start + interval
        let expectedBase = makeDate(day: 13, hour: 9, minute: 0) // Tuesday 09:00
        let expected = expectedBase.addingTimeInterval(2400)
        #expect(abs(next!.timeIntervalSince(expected)) < 1)
    }

    @Test func nextBreakTime_weekendScheduleOnFriday() {
        let friday17 = makeDate(day: 15, hour: 17, minute: 30) // 2026-05-15 Friday, after window
        let schedule = makeSchedule(days: .weekdays)
        let next = evaluator.nextBreakTime(for: schedule, after: friday17)
        #expect(next != nil)
        // Should be Monday's window
        let mondayBase = makeDate(day: 18, hour: 9, minute: 0) // 2026-05-18 Monday
        let expected = mondayBase.addingTimeInterval(2400)
        #expect(abs(next!.timeIntervalSince(expected)) < 1)
    }

    @Test func nextBreakTime_noActiveSchedule() {
        let schedule = makeSchedule(days: .custom([]))
        let result = evaluator.nextBreakTime(for: schedule, after: Date())
        #expect(result == nil)
    }

    @Test func breakDuration_noRepetitionRule() {
        let schedule = makeSchedule(breakDuration: 600)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 0) == 600)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 5) == 600)
    }

    @Test func breakDuration_withRepetitionRule() {
        let schedule = makeSchedule(
            repetitionRule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 600, longBreakDuration: 1800)
        )
        // Cycle: short(0), short(1), short(2), long(3), short(4), short(5), short(6), long(7)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 0) == 600)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 1) == 600)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 2) == 600)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 3) == 1800)
        #expect(evaluator.breakDuration(for: schedule, breakIndex: 4) == 600)
    }
}

// MARK: - RepetitionTracker Tests

@Suite("RepetitionTracker Tests")
struct RepetitionTrackerTests {

    @Test func cycleProgression() {
        var tracker = RepetitionTracker(rule: RepetitionRule(
            shortBreakCount: 3, shortBreakDuration: 600, longBreakDuration: 1800
        ))
        #expect(tracker.currentBreakIndex == 0)
        #expect(!tracker.isLongBreak)

        tracker.recordBreak() // 0 → 1
        #expect(tracker.currentBreakIndex == 1)
        tracker.recordBreak() // 1 → 2
        tracker.recordBreak() // 2 → 3 (now isLongBreak)
        #expect(tracker.isLongBreak)

        tracker.recordBreak() // long break resets → 0
        #expect(tracker.currentBreakIndex == 0)
        #expect(!tracker.isLongBreak)
    }

    @Test func durations() {
        var tracker = RepetitionTracker(rule: RepetitionRule(
            shortBreakCount: 2, shortBreakDuration: 300, longBreakDuration: 900
        ))
        #expect(tracker.currentDuration == 300)
        tracker.recordBreak()
        #expect(tracker.currentDuration == 300)
        tracker.recordBreak() // index 2 == shortBreakCount → long
        #expect(tracker.currentDuration == 900)
    }

    @Test func reset() {
        var tracker = RepetitionTracker(rule: RepetitionRule(
            shortBreakCount: 3, shortBreakDuration: 600, longBreakDuration: 1800
        ))
        tracker.recordBreak()
        tracker.recordBreak()
        #expect(tracker.currentBreakIndex == 2)
        tracker.reset()
        #expect(tracker.currentBreakIndex == 0)
    }
}

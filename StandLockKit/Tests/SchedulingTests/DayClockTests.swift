import Foundation
import Testing
@testable import Scheduling
import StandLockCore

@Suite("DayClock Tests")
struct DayClockTests {
    private func schedule(windows: [TimeWindow], days: DaySelection = .weekdays) -> Schedule {
        Schedule(name: "Work", days: days, windows: windows, breakInterval: 55 * 60, breakDuration: 5 * 60,
                 intervalCycle: [IntervalStep(duration: 55 * 60), IntervalStep(duration: 60 * 60)])
    }

    @Test func alternatingDayMatchesTheDisplayedSchedule() {
        let stored = schedule(windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)])
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!
        let clock = DayClock(schedule: stored, preview: DayPreview.make(for: stored, from: monday))
        #expect(clock.segments.filter { $0.kind == .shortBreak }.map(\.start) == [35700, 39600, 43200, 47100, 50700, 54600, 58200])
        #expect(clock.workDuration == 26700)
        #expect(clock.breakDuration == 2100)
        #expect(clock.segments.last?.end == 61200)
    }

    @Test func overnightWindowsOccupyBothSidesOfMidnight() {
        let stored = schedule(windows: [TimeWindow(startHour: 22, startMinute: 0, endHour: 2, endMinute: 0)])
        let clock = DayClock(schedule: stored, preview: DayPreview(items: []))
        #expect(clock.segments == [.init(kind: .work, start: 0, end: 7200), .init(kind: .work, start: 79200, end: 86400)])
        #expect(clock.workDuration == 14400)
    }

    @Test func overlappingWindowsAreCountedOnceAndGapsStayEmpty() {
        let stored = schedule(windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0), TimeWindow(startHour: 10, startMinute: 0, endHour: 11, endMinute: 0), TimeWindow(startHour: 13, startMinute: 0, endHour: 14, endMinute: 0)])
        let clock = DayClock(schedule: stored, preview: DayPreview(items: []))
        #expect(clock.segments == [.init(kind: .work, start: 32400, end: 43200), .init(kind: .work, start: 46800, end: 50400)])
        #expect(clock.workDuration == 14400)
    }

    @Test func overnightPreviewFollowsSelectedCalendarDays() {
        let stored = schedule(windows: [TimeWindow(startHour: 22, startMinute: 0, endHour: 2, endMinute: 0)], days: .custom([.monday]))
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 0))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 1))!
        let preview = DayPreview.make(for: stored, from: monday)
        #expect(preview.items.map { $0.hour * 60 + $0.minute } == [55, 1380])
        #expect(!ScheduleEvaluator().isWithinActiveWindow(stored, at: tuesday))
        let clock = DayClock(schedule: stored, preview: preview)
        #expect(clock.workDuration == 13800)
        #expect(clock.segments.first?.start == 0)
        #expect(clock.segments.last?.end == 86400)
    }

    @Test func aBreakBeyondTheWindowStillAppearsButStopsAtMidnight() {
        let stored = schedule(windows: [TimeWindow(startHour: 23, startMinute: 0, endHour: 23, endMinute: 58)])
        let clock = DayClock(schedule: stored, preview: DayPreview(items: [.init(hour: 23, minute: 55, duration: 600)]))
        #expect(clock.segments == [.init(kind: .work, start: 82800, end: 86100), .init(kind: .shortBreak, start: 86100, end: 86400)])
        #expect(clock.breakDuration == 300)
    }

    @Test func longBreaksUseTheRulePosition() {
        var stored = schedule(windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)])
        stored.repetitionRule = RepetitionRule(shortBreakCount: 3, shortBreakDuration: 120, longBreakDuration: 900)
        let preview = DayPreview(items: [.init(hour: 10, minute: 0, duration: 120), .init(hour: 11, minute: 0, duration: 120), .init(hour: 12, minute: 0, duration: 120), .init(hour: 13, minute: 0, duration: 900)])
        let clock = DayClock(schedule: stored, preview: preview)
        #expect(clock.segments.filter { $0.kind == .longBreak } == [.init(kind: .longBreak, start: 46800, end: 47700)])
        #expect(clock.breakDuration == 1260)
    }

    @Test func fractionalMinuteBreakPositionsKeepTheirSeconds() {
        let stored = schedule(windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)])
        let clock = DayClock(schedule: stored, preview: DayPreview(items: [.init(hour: 9, minute: 20, second: 30, duration: 20)]))
        #expect(clock.segments.filter { $0.kind == .shortBreak } == [.init(kind: .shortBreak, start: 33630, end: 33650)])
        #expect(clock.workDuration == 3580)
    }

    @Test func emptyDaysHaveNoWorkOrBreaks() {
        let stored = schedule(windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)], days: .custom([]))
        #expect(DayClock(schedule: stored, preview: DayPreview(items: [])).segments.isEmpty)
    }

    @Test func morningAndNightHaveDistinctClockPositions() {
        let morning = DayClock.Segment(kind: .work, start: 32400, end: 36000)
        let night = DayClock.Segment(kind: .work, start: 75600, end: 79200)
        #expect(morning.startFraction == 0.375)
        #expect(night.startFraction == 0.875)
    }
}

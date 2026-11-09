import Foundation
import Testing
@testable import Scheduling
@testable import StandLockCore

/// Times are written by hand: a test comparing the preview with the evaluator would prove nothing.
@Suite("DayPreview Tests")
struct DayPreviewTests {

    /// Monday, 4 May 2026.
    private let monday = date(day: 4)
    private let workday = TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

    private static func date(day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = day; components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private func schedule(
        days: DaySelection = .weekdays,
        windows: [TimeWindow],
        interval: TimeInterval,
        duration: TimeInterval,
        cycle: [IntervalStep]? = nil,
        rule: RepetitionRule? = nil
    ) -> Schedule {
        Schedule(
            name: "Test", days: days, windows: windows,
            breakInterval: interval, breakDuration: duration,
            intervalCycle: cycle, repetitionRule: rule
        )
    }

    private func times(_ preview: DayPreview) -> [String] {
        preview.items.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
    }

    @Test func simpleDay() {
        let preview = DayPreview.make(
            for: schedule(windows: [workday], interval: 40 * 60, duration: 5 * 60), from: monday
        )
        #expect(times(preview) == [
            "09:40", "10:25", "11:10", "11:55", "12:40", "13:25", "14:10", "14:55", "15:40", "16:25",
        ])
        #expect(preview.items.allSatisfy { $0.duration == TimeInterval(300) })
    }

    @Test func intervalCycle() {
        let preview = DayPreview.make(
            for: schedule(
                windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0)],
                interval: 25 * 60, duration: 5 * 60,
                cycle: [IntervalStep(duration: 25 * 60), IntervalStep(duration: 10 * 60)]
            ),
            from: monday
        )
        #expect(times(preview) == ["09:25", "09:40", "10:10", "10:25", "10:55", "11:10", "11:40", "11:55"])
    }

    @Test func twoWindows() {
        let preview = DayPreview.make(
            for: schedule(
                windows: [
                    TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0),
                    TimeWindow(startHour: 13, startMinute: 0, endHour: 17, endMinute: 0),
                ],
                interval: 60 * 60, duration: 5 * 60
            ),
            from: monday
        )
        #expect(times(preview) == ["10:00", "11:05", "14:00", "15:05", "16:10"])
    }

    @Test func repetitionDurations() {
        let preview = DayPreview.make(
            for: schedule(
                windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 14, endMinute: 0)],
                interval: 60 * 60, duration: 5 * 60,
                rule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 120, longBreakDuration: 900)
            ),
            from: monday
        )
        #expect(times(preview) == ["10:00", "11:02", "12:04", "13:06"])
        #expect(preview.items.map(\.duration) == [120, 120, 120, 900].map(TimeInterval.init))
        #expect(preview.shortestBreak == TimeInterval(120))
        #expect(preview.longestBreak == TimeInterval(900))
    }

    /// From outside a window the evaluator returns window start plus interval with no window check,
    /// so this is what the coordinator really does.
    @Test func shortWindowKeepsRealBehaviour() {
        let preview = DayPreview.make(
            for: schedule(
                windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 9, endMinute: 30)],
                interval: 40 * 60, duration: 5 * 60
            ),
            from: monday
        )
        #expect(times(preview) == ["09:40"])
    }

    @Test func inactiveDayUsesNextActiveDay() {
        let saturday = Self.date(day: 2)
        let preview = DayPreview.make(
            for: schedule(windows: [workday], interval: 40 * 60, duration: 5 * 60), from: saturday
        )
        #expect(times(preview).first == "09:40")
        #expect(preview.items.count == 10)
    }

    @Test func noDaysGivesEmpty() {
        let preview = DayPreview.make(
            for: schedule(days: .custom([]), windows: [workday], interval: 40 * 60, duration: 5 * 60),
            from: monday
        )
        #expect(preview.items.isEmpty)
        #expect(preview.shortestBreak == nil)
        #expect(preview.longestBreak == nil)
    }

    @Test func fractionalMinuteBreaksKeepSecondsInTheirStartTimes() {
        let preview = DayPreview.make(for: schedule(
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)],
            interval: 1200, duration: 20
        ), from: monday)
        #expect(preview.items.map(\.second) == [0, 20])
    }

    @Test func groupsSplitAtNoonAndSix() {
        let preview = DayPreview(items: [
            DayPreview.Item(hour: 11, minute: 59, duration: 60),
            DayPreview.Item(hour: 12, minute: 0, duration: 60),
            DayPreview.Item(hour: 17, minute: 59, duration: 60),
            DayPreview.Item(hour: 18, minute: 0, duration: 60),
        ])
        #expect(preview.morning.map(\.hour) == [11])
        #expect(preview.afternoon.map(\.hour) == [12, 17])
        #expect(preview.evening.map(\.hour) == [18])
    }

    /// On the day clocks go back, a window opening in the repeated hour resolves to its first
    /// occurrence, which can be behind the walk. Following it never reaches the end of the day.
    @Test func aTimeBehindTheWalkEndsIt() {
        let engine = RewindingEngine(first: monday)
        let preview = DayPreview.make(
            for: schedule(windows: [workday], interval: 60, duration: 6), from: monday, evaluator: engine
        )
        #expect(preview.items.count == 1)
    }

    /// 60 s plus 66 s steps inside a window closing at 23:59:00.
    @Test func densestScheduleStops() {
        let preview = DayPreview.make(
            for: schedule(
                days: .everyDay,
                windows: [TimeWindow(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)],
                interval: 60, duration: 6
            ),
            from: monday
        )
        #expect(preview.items.count == 1308)
    }
}

/// One real time, then always an hour behind the caller. Gives up after a while, so a walk that
/// follows it fails the test instead of hanging the run.
private final class RewindingEngine: SchedulingEngine, @unchecked Sendable {
    private let first: Date
    private var calls = 0

    init(first: Date) {
        self.first = first
    }

    func nextBreakTime(for schedule: Schedule, after date: Date, cycleIndex: Int) -> Date? {
        calls += 1
        if calls == 1 { return first }
        return calls < 100 ? date.addingTimeInterval(-3600) : nil
    }

    func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval { 6 }
    func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool { true }
}

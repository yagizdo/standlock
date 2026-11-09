import Foundation
import StandLockCore

/// The break times of one day, walked through the real evaluator so the two cannot drift apart.
public struct DayPreview: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public let hour: Int
        public let minute: Int
        public let second: Int
        public let duration: TimeInterval

        public init(hour: Int, minute: Int, second: Int = 0, duration: TimeInterval) {
            self.hour = hour
            self.minute = minute
            self.second = second
            self.duration = duration
        }
    }

    public let items: [Item]

    public var morning: [Item] { items.filter { $0.hour < 12 } }
    public var afternoon: [Item] { items.filter { (12..<18).contains($0.hour) } }
    public var evening: [Item] { items.filter { $0.hour >= 18 } }
    public var shortestBreak: TimeInterval? { items.map(\.duration).min() }
    public var longestBreak: TimeInterval? { items.map(\.duration).max() }

    /// Previews `date`, or the next active day after it. The walk starts at the start of the day,
    /// not the window start: that is how the coordinator meets a window it is outside of.
    public static func make(
        for schedule: Schedule, from date: Date, evaluator: any SchedulingEngine = ScheduleEvaluator()
    ) -> DayPreview {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let activeDay = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .first { day in
                Weekday(rawValue: calendar.component(.weekday, from: day))
                    .map(schedule.days.activeDays.contains) ?? false
            }
        guard let activeDay, let dayEnd = calendar.date(byAdding: .day, value: 1, to: activeDay) else {
            return DayPreview(items: [])
        }

        var items: [Item] = []
        var cursor = activeDay
        var index = 0
        // `next > cursor`: on the day clocks go back the evaluator can answer with a time behind
        // the walk, and following it would hang the Settings window.
        while let next = evaluator.nextBreakTime(for: schedule, after: cursor, cycleIndex: index),
              next > cursor, next < dayEnd {
            let duration = evaluator.breakDuration(for: schedule, breakIndex: index)
            let time = calendar.dateComponents([.hour, .minute, .second], from: next)
            items.append(Item(hour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, duration: duration))
            cursor = next.addingTimeInterval(duration)
            index += 1
        }
        return DayPreview(items: items)
    }
}

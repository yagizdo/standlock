import Foundation
import StandLockCore

public struct ScheduleEvaluator: SchedulingEngine, Sendable {
    public init() {}

    public func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool {
        let calendar = Calendar.current
        let weekdayComponent = calendar.component(.weekday, from: date)
        guard let weekday = Weekday(rawValue: weekdayComponent),
              schedule.days.activeDays.contains(weekday) else {
            return false
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return schedule.windows.contains { $0.contains(hour: hour, minute: minute) }
    }

    public func nextBreakTime(for schedule: Schedule, after date: Date) -> Date? {
        let calendar = Calendar.current

        if isWithinActiveWindow(schedule, at: date) {
            let candidate = date.addingTimeInterval(schedule.breakInterval)
            if isWithinActiveWindow(schedule, at: candidate) {
                return candidate
            }
            if let nextWindow = nextWindowStart(for: schedule, after: date, calendar: calendar) {
                return nextWindow.addingTimeInterval(schedule.breakInterval)
            }
        }

        if let nextWindow = nextWindowStart(for: schedule, after: date, calendar: calendar) {
            return nextWindow.addingTimeInterval(schedule.breakInterval)
        }

        return nil
    }

    public func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval {
        guard let rule = schedule.repetitionRule else {
            return schedule.breakDuration
        }
        let cycleLength = rule.shortBreakCount + 1
        let positionInCycle = breakIndex % cycleLength
        return positionInCycle == rule.shortBreakCount
            ? rule.longBreakDuration
            : rule.shortBreakDuration
    }

    private func nextWindowStart(for schedule: Schedule, after date: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        for dayOffset in 0...7 {
            guard let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else {
                continue
            }
            let weekdayComponent = calendar.component(.weekday, from: candidateDate)
            guard let weekday = Weekday(rawValue: weekdayComponent),
                  schedule.days.activeDays.contains(weekday) else {
                continue
            }

            let sortedWindows = schedule.windows.sorted {
                ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute)
            }

            for window in sortedWindows {
                let windowStartMinutes = window.startHour * 60 + window.startMinute
                if dayOffset == 0 && windowStartMinutes <= currentMinutes {
                    continue
                }
                var components = calendar.dateComponents([.year, .month, .day], from: candidateDate)
                components.hour = window.startHour
                components.minute = window.startMinute
                components.second = 0
                if let windowStart = calendar.date(from: components) {
                    return windowStart
                }
            }
        }
        return nil
    }
}

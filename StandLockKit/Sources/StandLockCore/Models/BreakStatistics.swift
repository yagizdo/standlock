import Foundation

public struct BreakStatistics: Codable, Sendable {
    public var date: Date
    public var breaksCompleted: Int
    public var breaksSkipped: Int
    public var breaksEscaped: Int
    public var breaksDeferred: Int
    public var currentStreak: Int
    public var weeklyEscapeCount: Int
    public var weekStartDate: Date

    public init(date: Date = Date()) {
        self.date = date
        breaksCompleted = 0; breaksSkipped = 0; breaksEscaped = 0
        breaksDeferred = 0; currentStreak = 0; weeklyEscapeCount = 0
        weekStartDate = Calendar.current.date(from: Calendar.current.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: date))!
    }

    public var totalBreaks: Int { breaksCompleted + breaksSkipped + breaksEscaped }

    public var completionRate: Double {
        guard totalBreaks > 0 else { return 0 }
        return Double(breaksCompleted) / Double(totalBreaks)
    }

    /// Clears the per-day counters when `currentDate` falls on a different calendar day
    /// than the one these statistics were recorded for. Streak and weekly counters span
    /// multiple days and are left untouched.
    /// Unlike `resetWeeklyIfNeeded` this triggers in both directions: a clock correction or a
    /// timezone change that moves the date backwards must still recover, otherwise a single
    /// future-stamped date would freeze the counters until that day arrives.
    @discardableResult
    public mutating func resetDailyIfNeeded(currentDate: Date) -> Bool {
        guard !Calendar.current.isDate(date, inSameDayAs: currentDate) else { return false }
        date = currentDate
        breaksCompleted = 0
        breaksSkipped = 0
        breaksEscaped = 0
        breaksDeferred = 0
        return true
    }

    public mutating func resetWeeklyIfNeeded(currentDate: Date) {
        let currentWeekStart = Calendar.current.date(from: Calendar.current.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: currentDate))!
        if currentWeekStart > weekStartDate {
            weeklyEscapeCount = 0
            weekStartDate = currentWeekStart
        }
    }
}

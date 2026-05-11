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

    public mutating func resetWeeklyIfNeeded(currentDate: Date) {
        let currentWeekStart = Calendar.current.date(from: Calendar.current.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: currentDate))!
        if currentWeekStart > weekStartDate {
            weeklyEscapeCount = 0
            weekStartDate = currentWeekStart
        }
    }
}

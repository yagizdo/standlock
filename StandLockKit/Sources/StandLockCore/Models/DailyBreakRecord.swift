import Foundation

public struct DailyBreakRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String
    public var breaksCompleted: Int
    public var breaksSkipped: Int
    public var breaksEscaped: Int
    public var totalBreakDuration: TimeInterval
    public var hadActiveSchedule: Bool

    public init(
        dateKey: String,
        breaksCompleted: Int = 0,
        breaksSkipped: Int = 0,
        breaksEscaped: Int = 0,
        totalBreakDuration: TimeInterval = 0,
        hadActiveSchedule: Bool = true
    ) {
        self.dateKey = dateKey
        self.breaksCompleted = breaksCompleted
        self.breaksSkipped = breaksSkipped
        self.breaksEscaped = breaksEscaped
        self.totalBreakDuration = totalBreakDuration
        self.hadActiveSchedule = hadActiveSchedule
    }

    public var totalBreaks: Int { breaksCompleted + breaksSkipped + breaksEscaped }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public static func dateKey(from date: Date) -> String {
        keyFormatter.string(from: date)
    }

    public static func date(from dateKey: String) -> Date? {
        keyFormatter.date(from: dateKey)
    }
}

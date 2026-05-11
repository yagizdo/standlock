import Foundation

public struct Schedule: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var days: DaySelection
    public var windows: [TimeWindow]
    public var breakInterval: TimeInterval
    public var breakDuration: TimeInterval
    public var repetitionRule: RepetitionRule?
    public var disciplineLevel: DisciplineLevel
    public var dailyBreakCap: Int?

    public init(
        id: UUID = UUID(), name: String, isEnabled: Bool = true,
        days: DaySelection, windows: [TimeWindow],
        breakInterval: TimeInterval, breakDuration: TimeInterval,
        repetitionRule: RepetitionRule? = nil,
        disciplineLevel: DisciplineLevel = .gentle,
        dailyBreakCap: Int? = nil
    ) {
        self.id = id; self.name = name; self.isEnabled = isEnabled
        self.days = days; self.windows = windows
        self.breakInterval = breakInterval; self.breakDuration = breakDuration
        self.repetitionRule = repetitionRule
        self.disciplineLevel = disciplineLevel; self.dailyBreakCap = dailyBreakCap
    }
}

public enum DaySelection: Codable, Sendable, Equatable {
    case everyDay
    case weekdays
    case weekends
    case custom(Set<Weekday>)

    public var activeDays: Set<Weekday> {
        switch self {
        case .everyDay: Set(Weekday.allCases)
        case .weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]
        case .weekends: [.saturday, .sunday]
        case .custom(let days): days
        }
    }
}

public enum Weekday: Int, Codable, Sendable, CaseIterable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TimeWindow: Codable, Sendable, Equatable {
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour; self.startMinute = startMinute
        self.endHour = endHour; self.endMinute = endMinute
    }

    public func contains(hour: Int, minute: Int) -> Bool {
        let time = hour * 60 + minute
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return time >= start && time < end
    }
}

public struct RepetitionRule: Codable, Sendable, Equatable {
    public var shortBreakCount: Int
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval

    public init(shortBreakCount: Int, shortBreakDuration: TimeInterval, longBreakDuration: TimeInterval) {
        self.shortBreakCount = shortBreakCount
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
    }
}

import Foundation

public struct Schedule: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var days: DaySelection
    public var windows: [TimeWindow]
    public var breakInterval: TimeInterval
    public var breakDuration: TimeInterval
    public var intervalCycle: [IntervalStep]?
    public var repetitionRule: RepetitionRule?
    public var disciplineLevel: DisciplineLevel
    public var dailyBreakCap: Int?
    public var progressiveEnforcement: Bool

    public init(
        id: UUID = UUID(), name: String, isEnabled: Bool = true,
        days: DaySelection, windows: [TimeWindow],
        breakInterval: TimeInterval, breakDuration: TimeInterval,
        intervalCycle: [IntervalStep]? = nil,
        repetitionRule: RepetitionRule? = nil,
        disciplineLevel: DisciplineLevel = .gentle,
        dailyBreakCap: Int? = nil,
        progressiveEnforcement: Bool = false
    ) {
        self.id = id; self.name = name; self.isEnabled = isEnabled
        self.days = days; self.windows = windows
        self.breakInterval = breakInterval; self.breakDuration = breakDuration
        self.intervalCycle = intervalCycle
        self.repetitionRule = repetitionRule
        self.disciplineLevel = disciplineLevel; self.dailyBreakCap = dailyBreakCap
        self.progressiveEnforcement = progressiveEnforcement
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, days, windows
        case breakInterval, breakDuration, intervalCycle, repetitionRule
        case disciplineLevel, dailyBreakCap, progressiveEnforcement
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        days = try c.decode(DaySelection.self, forKey: .days)
        windows = try c.decode([TimeWindow].self, forKey: .windows)
        breakInterval = try c.decode(TimeInterval.self, forKey: .breakInterval)
        breakDuration = try c.decode(TimeInterval.self, forKey: .breakDuration)
        intervalCycle = try c.decodeIfPresent([IntervalStep].self, forKey: .intervalCycle)
        repetitionRule = try c.decodeIfPresent(RepetitionRule.self, forKey: .repetitionRule)
        disciplineLevel = try c.decodeIfPresent(DisciplineLevel.self, forKey: .disciplineLevel) ?? .gentle
        dailyBreakCap = try c.decodeIfPresent(Int.self, forKey: .dailyBreakCap)
        progressiveEnforcement = try c.decodeIfPresent(Bool.self, forKey: .progressiveEnforcement) ?? false
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

    public var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }
}

public struct TimeWindow: Codable, Sendable, Equatable, Identifiable {
    /// Not persisted. It only has to stay stable for as long as a form is on screen, so SwiftUI
    /// can track rows across insertions and deletions instead of addressing them by index.
    public let id = UUID()
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int

    private enum CodingKeys: String, CodingKey {
        case startHour, startMinute, endHour, endMinute
    }

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour; self.startMinute = startMinute
        self.endHour = endHour; self.endMinute = endMinute
    }

    /// Identity is per-session only, so equality stays on the values a window actually stores.
    public static func == (lhs: TimeWindow, rhs: TimeWindow) -> Bool {
        lhs.startHour == rhs.startHour && lhs.startMinute == rhs.startMinute
            && lhs.endHour == rhs.endHour && lhs.endMinute == rhs.endMinute
    }

    public func contains(hour: Int, minute: Int) -> Bool {
        let time = hour * 60 + minute
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        if start <= end {
            return time >= start && time < end
        }
        return time >= start || time < end
    }
}

public struct IntervalStep: Codable, Sendable, Equatable {
    public var duration: TimeInterval
    public var label: String?

    public init(duration: TimeInterval, label: String? = nil) {
        self.duration = duration
        self.label = label
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

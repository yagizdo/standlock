import Foundation

/// The lengths of a Pomodoro session, set on the Settings > Pomodoro page.
public struct PomodoroConfiguration: Codable, Sendable, Equatable {
    public var focus: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    public var rounds: Int

    public static let standard = PomodoroConfiguration(focus: 25 * 60, shortBreak: 5 * 60, longBreak: 15 * 60, rounds: 4)

    /// The form's ranges, in minutes. Import refuses a file outside them: a zero-length
    /// phase would loop.
    public static let focusRange = 1...180
    public static let breakRange = 1...60
    public static let roundsRange = 1...12

    public init(focus: TimeInterval, shortBreak: TimeInterval, longBreak: TimeInterval, rounds: Int) {
        self.focus = focus
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.rounds = rounds
    }

    public var isWithinBounds: Bool {
        func minutes(_ value: TimeInterval, in range: ClosedRange<Int>) -> Bool {
            value.isFinite && value >= TimeInterval(range.lowerBound * 60) && value <= TimeInterval(range.upperBound * 60)
        }
        return minutes(focus, in: Self.focusRange)
            && minutes(shortBreak, in: Self.breakRange)
            && minutes(longBreak, in: Self.breakRange)
            && Self.roundsRange.contains(rounds)
    }

    private enum CodingKeys: String, CodingKey {
        case focus, shortBreak, longBreak, rounds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let standard = Self.standard
        focus = try c.decodeIfPresent(TimeInterval.self, forKey: .focus) ?? standard.focus
        shortBreak = try c.decodeIfPresent(TimeInterval.self, forKey: .shortBreak) ?? standard.shortBreak
        longBreak = try c.decodeIfPresent(TimeInterval.self, forKey: .longBreak) ?? standard.longBreak
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? standard.rounds
    }
}

import Foundation

/// The lengths of a Pomodoro session, set on the Settings > Pomodoro page.
public struct PomodoroConfiguration: Codable, Sendable, Equatable {
    public var focus: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    public var rounds: Int
    public var cover: PomodoroCover

    public static let standard = PomodoroConfiguration(focus: 25 * 60, shortBreak: 5 * 60, longBreak: 15 * 60, rounds: 4)

    /// The form's ranges, in minutes. Import refuses a file outside them: a zero-length
    /// phase would loop.
    public static let focusRange = 1...180
    public static let breakRange = 1...60
    public static let roundsRange = 1...12

    /// A covered focus is an overlay, so it keeps the break ceiling (`BreakSafety.maximumBreakDuration`).
    public static func focusRange(for cover: PomodoroCover) -> ClosedRange<Int> {
        cover == .focus ? breakRange : focusRange
    }

    public init(focus: TimeInterval, shortBreak: TimeInterval, longBreak: TimeInterval, rounds: Int, cover: PomodoroCover = .breaks) {
        self.focus = focus
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.rounds = rounds
        self.cover = cover
    }

    /// Sets the mode and pulls the focus length into that mode's range.
    public mutating func setCover(_ cover: PomodoroCover) {
        self.cover = cover
        let range = Self.focusRange(for: cover)
        focus = min(max(focus, TimeInterval(range.lowerBound * 60)), TimeInterval(range.upperBound * 60))
    }

    public var isWithinBounds: Bool {
        func minutes(_ value: TimeInterval, in range: ClosedRange<Int>) -> Bool {
            value.isFinite && value >= TimeInterval(range.lowerBound * 60) && value <= TimeInterval(range.upperBound * 60)
        }
        return minutes(focus, in: Self.focusRange(for: cover))
            && minutes(shortBreak, in: Self.breakRange)
            && minutes(longBreak, in: Self.breakRange)
            && Self.roundsRange.contains(rounds)
    }

    private enum CodingKeys: String, CodingKey {
        case focus, shortBreak, longBreak, rounds, cover
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let standard = Self.standard
        focus = try c.decodeIfPresent(TimeInterval.self, forKey: .focus) ?? standard.focus
        shortBreak = try c.decodeIfPresent(TimeInterval.self, forKey: .shortBreak) ?? standard.shortBreak
        longBreak = try c.decodeIfPresent(TimeInterval.self, forKey: .longBreak) ?? standard.longBreak
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? standard.rounds
        // An older file has no key and a newer build's mode is unknown here: both mean today's mode.
        cover = (try? c.decodeIfPresent(PomodoroCover.self, forKey: .cover)) ?? .breaks
    }
}

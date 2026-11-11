import Foundation

/// Two enabled schedules that run at the same time do not share the time: every break re-arms
/// both from now, so the shorter interval always wins and the longer one never fires. Only one
/// of a pair that overlaps may be on.
extension Schedule {
    /// A shared weekday and a shared minute on it. Mirrors `ScheduleEvaluator`, which reads a
    /// time against its own date's weekday: a 22:00-02:00 window covers 00:00-02:00 and
    /// 22:00-24:00 of each of its days, and never the morning of the day after.
    public func overlaps(_ other: Schedule) -> Bool {
        guard !days.activeDays.isDisjoint(with: other.days.activeDays) else { return false }
        let mine = windows.flatMap(\.minuteRanges)
        let theirs = other.windows.flatMap(\.minuteRanges)
        return mine.contains { range in theirs.contains(where: range.overlaps) }
    }
}

extension TimeWindow {
    /// The minutes of a day `contains` answers true for.
    var minuteRanges: [Range<Int>] {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        if start == end { return [] }
        if start < end { return [start..<end] }
        // Clamped so a stored value no form writes cannot build a range that traps.
        return [start..<Swift.max(start, 24 * 60), 0..<Swift.max(0, end)]
    }
}

extension Array where Element == Schedule {
    /// The enabled schedules, other than `schedule` itself, that turning it on would turn off.
    public func overlapping(_ schedule: Schedule) -> [Schedule] {
        filter { $0.id != schedule.id && $0.isEnabled && $0.overlaps(schedule) }
    }

    /// Turns off every enabled schedule that overlaps one kept before it, keeping the order.
    /// `winner`, the schedule just turned on or saved, is kept first; without one the earliest
    /// enabled schedule stays.
    public func turningOffOverlaps(keeping winner: UUID? = nil) -> [Schedule] {
        var result = self
        var kept: [Schedule] = []
        let order = indices.sorted { lhs, rhs in
            (self[lhs].id == winner ? 0 : 1, lhs) < (self[rhs].id == winner ? 0 : 1, rhs)
        }
        for index in order where result[index].isEnabled {
            if kept.contains(where: result[index].overlaps) {
                result[index].isEnabled = false
            } else {
                kept.append(result[index])
            }
        }
        return result
    }
}

/// The note on a schedule's Settings page: which enabled schedules the page's action would
/// turn off, and which action that is.
public enum ScheduleOverlapNote: Equatable, Sendable {
    case adding([Schedule])
    case turningOn([Schedule])
    case saving([Schedule])

    /// - Parameters:
    ///   - stored: the schedule as stored, nil for one not added yet.
    ///   - draft: the form's values as Save would store them.
    public init?(schedules: [Schedule], stored: Schedule?, draft: Schedule, isDirty: Bool) {
        guard let stored else {
            self = .adding(schedules.overlapping(draft))
            if turnedOff.isEmpty { return nil }
            return
        }
        if !stored.isEnabled {
            // The switch turns on the stored hours, not the draft's.
            self = .turningOn(schedules.overlapping(stored))
        } else if isDirty {
            self = .saving(schedules.overlapping(draft))
        } else {
            return nil
        }
        if turnedOff.isEmpty { return nil }
    }

    public var turnedOff: [Schedule] {
        switch self {
        case .adding(let hit), .turningOn(let hit), .saving(let hit): hit
        }
    }
}

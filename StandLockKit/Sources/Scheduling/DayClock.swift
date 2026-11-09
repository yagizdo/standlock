import Foundation
import StandLockCore

/// Wall-time segments for a 24-hour clock, using the real schedule preview's break times.
public struct DayClock: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case work, shortBreak, longBreak }

    public struct Segment: Equatable, Sendable {
        public let kind: Kind
        public let start: TimeInterval
        public let end: TimeInterval
        public var startFraction: Double { start / 86400 }
        public var endFraction: Double { end / 86400 }
        public var duration: TimeInterval { end - start }
    }

    public let segments: [Segment]
    public var workDuration: TimeInterval { segments.filter { $0.kind == .work }.reduce(0) { $0 + $1.duration } }
    public var breakDuration: TimeInterval { segments.filter { $0.kind != .work }.reduce(0) { $0 + $1.duration } }

    public func duration(for kind: Kind) -> TimeInterval {
        segments.filter { $0.kind == kind }.reduce(0) { $0 + $1.duration }
    }

    public init(schedule: Schedule, preview: DayPreview) {
        guard !schedule.days.activeDays.isEmpty else {
            segments = []
            return
        }
        let active = Self.merged(schedule.windows.flatMap { window -> [Range<TimeInterval>] in
            let start = TimeInterval(window.startHour * 3600 + window.startMinute * 60)
            let end = TimeInterval(window.endHour * 3600 + window.endMinute * 60)
            if start < end { return [start..<end] }
            if start > end { return [0..<end, start..<86400] }
            return []
        })
        let breaks = preview.items.enumerated().compactMap { index, item -> Segment? in
            guard item.duration.isFinite, item.duration > 0 else { return nil }
            let start = TimeInterval(item.hour * 3600 + item.minute * 60 + item.second)
            let lower = max(0, start)
            let upper = min(86400, start + item.duration)
            guard lower < upper else { return nil }
            var kind = Kind.shortBreak
            if let rule = schedule.repetitionRule,
               rule.shortBreakCount >= 0, rule.shortBreakCount < preview.items.count,
               index % (rule.shortBreakCount + 1) == rule.shortBreakCount {
                kind = .longBreak
            }
            return Segment(kind: kind, start: lower, end: upper)
        }
        let excluded = Self.merged(breaks.map { $0.start..<$0.end })
        var work: [Segment] = []
        for window in active {
            var cursor = window.lowerBound
            for pause in excluded where pause.upperBound > cursor && pause.lowerBound < window.upperBound {
                if pause.lowerBound > cursor {
                    work.append(Segment(kind: .work, start: cursor, end: min(pause.lowerBound, window.upperBound)))
                }
                cursor = min(window.upperBound, max(cursor, pause.upperBound))
            }
            if cursor < window.upperBound {
                work.append(Segment(kind: .work, start: cursor, end: window.upperBound))
            }
        }
        segments = (work + breaks).sorted { $0.start < $1.start }
    }

    private static func merged(_ ranges: [Range<TimeInterval>]) -> [Range<TimeInterval>] {
        var result: [Range<TimeInterval>] = []
        for range in ranges.filter({ !$0.isEmpty }).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}

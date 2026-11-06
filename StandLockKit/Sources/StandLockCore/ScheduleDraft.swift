import Foundation

/// Session-only row identity, same non-persisted-id pattern as `TimeWindow.id`.
public struct IntervalRow: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var minutes: Int
    public var label: String

    public init(minutes: Int, label: String = "") {
        self.minutes = minutes
        self.label = label
    }

    public static func == (lhs: IntervalRow, rhs: IntervalRow) -> Bool {
        lhs.minutes == rhs.minutes && lhs.label == rhs.label
    }
}

/// The values of the schedule form, held apart from the stored schedule until Save.
public struct ScheduleDraft: Equatable, Sendable {
    public static let intervalRange = 1...180
    public static let breakRange = 0.1...60.0
    public static let shortBreakRange = 0.1...30.0

    public var name = ""
    public var days = DaySelection.weekdays.activeDays
    public var windows = [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)]
    public var intervalRows = [IntervalRow(minutes: 40)]
    public var breakDurationMinutes: Double = 10
    public var useRepetition = false
    public var shortBreakCount = 3
    public var shortBreakMinutes: Double = 10
    public var longBreakMinutes = 30
    public var disciplineLevel = DisciplineLevel.gentle
    public var progressiveEnforcement = false

    public init(schedule: Schedule?) {
        guard let schedule else { return }
        name = schedule.name
        windows = schedule.windows
        if let cycle = schedule.intervalCycle, !cycle.isEmpty {
            intervalRows = cycle.map { IntervalRow(minutes: Int($0.duration / 60), label: $0.label ?? "") }
        } else {
            intervalRows = [IntervalRow(minutes: Int(schedule.breakInterval / 60))]
        }
        breakDurationMinutes = schedule.breakDuration / 60
        disciplineLevel = schedule.disciplineLevel
        progressiveEnforcement = schedule.progressiveEnforcement

        days = schedule.days.activeDays

        if let rule = schedule.repetitionRule {
            useRepetition = true
            shortBreakCount = rule.shortBreakCount
            shortBreakMinutes = rule.shortBreakDuration / 60
            longBreakMinutes = Int(rule.longBreakDuration / 60)
        }
    }

    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var canSave: Bool {
        hasName && !days.isEmpty
    }

    public func canSubmit(from baseline: ScheduleDraft) -> Bool {
        canSave && hasChanges(from: baseline)
    }

    /// `existing` supplies what the form does not edit, so pass the latest stored schedule: the
    /// enable toggle can change it while a draft is open. Ranges are held here too: Return can save
    /// before a field's own clamp has run.
    public func build(existing: Schedule?) -> Schedule {
        let repetitionRule: RepetitionRule? = useRepetition
            ? RepetitionRule(
                shortBreakCount: shortBreakCount,
                shortBreakDuration: (Self.clamped(shortBreakMinutes, to: Self.shortBreakRange) * 60).rounded(),
                longBreakDuration: TimeInterval(longBreakMinutes * 60)
            )
            : nil

        let steps = intervalRows.map { row -> IntervalStep in
            let trimmed = row.label.trimmingCharacters(in: .whitespaces)
            return IntervalStep(duration: TimeInterval(Self.clamped(row.minutes, to: Self.intervalRange) * 60),
                                label: trimmed.isEmpty ? nil : trimmed)
        }
        // A single row is the canonical single-interval schedule; `breakInterval` always
        // mirrors the first entry so old readers see a sane single interval. The label field
        // is hidden at one row, so a label left over from a deleted row must not persist --
        // it would be invisible, unclearable, and still drive the break screen.
        let intervalCycle: [IntervalStep]? = steps.count == 1 ? nil : steps

        return Schedule(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            isEnabled: existing?.isEnabled ?? true,
            days: daySelection(existing: existing),
            windows: windows,
            breakInterval: steps[0].duration,
            breakDuration: (Self.clamped(breakDurationMinutes, to: Self.breakRange) * 60).rounded(),
            intervalCycle: intervalCycle,
            repetitionRule: repetitionRule,
            disciplineLevel: disciplineLevel,
            dailyBreakCap: existing?.dailyBreakCap,
            progressiveEnforcement: progressiveEnforcement
        )
    }

    /// An unedited day set keeps its stored case: `.custom(Mon-Fri)` is not equal to `.weekdays`.
    private func daySelection(existing: Schedule?) -> DaySelection {
        if let existing, existing.days.activeDays == days { return existing.days }
        return switch days {
        case DaySelection.everyDay.activeDays: .everyDay
        case DaySelection.weekdays.activeDays: .weekdays
        case DaySelection.weekends.activeDays: .weekends
        default: .custom(days)
        }
    }

    public static func clamped<Value: Comparable>(_ value: Value, to range: ClosedRange<Value>) -> Value {
        max(range.lowerBound, min(range.upperBound, value))
    }

    /// Compares what would be saved, not the fields: a stored value the form rounds, or a field
    /// hidden by another setting, is not an edit.
    public func hasChanges(from baseline: ScheduleDraft) -> Bool {
        let reference = baseline.build(existing: nil)
        return build(existing: reference) != reference
    }
}

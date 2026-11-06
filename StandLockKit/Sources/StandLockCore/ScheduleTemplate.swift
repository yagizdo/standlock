import Foundation

/// Starting points for a new schedule. Conventions, not proven intervals: the app makes no health
/// claim about them.
public enum ScheduleTemplate: CaseIterable, Sendable {
    case twentyTwentyTwenty, pomodoro, fiftyTwoSeventeen

    /// Proper names, the same in every language.
    public var title: String {
        switch self {
        case .twentyTwentyTwenty: "20-20-20"
        case .pomodoro: "Pomodoro"
        case .fiftyTwoSeventeen: "52/17"
        }
    }

    private var rhythm: (intervalMinutes: Int, breakMinutes: Double) {
        switch self {
        case .twentyTwentyTwenty: (20, 20.0 / 60)
        case .pomodoro: (25, 5)
        case .fiftyTwoSeventeen: (52, 17)
        }
    }

    /// Sets the rhythm only: days, hours and discipline are the user's, and so is a typed name.
    /// Another template's title is not typed, so trying a second one renames the schedule too.
    public func apply(to draft: inout ScheduleDraft) {
        draft.intervalRows = [IntervalRow(minutes: rhythm.intervalMinutes)]
        draft.breakDurationMinutes = rhythm.breakMinutes
        draft.useRepetition = false
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty || Self.allCases.contains(where: { $0.title == name }) {
            draft.name = title
        }
    }
}

import Foundation

/// The screens of the first-launch onboarding, in the order they show.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome, schedule, scene, menuBar

    public var next: OnboardingStep? { Self(rawValue: rawValue + 1) }
    public var previous: OnboardingStep? { Self(rawValue: rawValue - 1) }
}

/// The rhythms offered for the first schedule: the app's default, then the templates.
public enum OnboardingRhythm: CaseIterable, Sendable {
    case standard, pomodoro, fiftyTwoSeventeen, twentyTwentyTwenty

    var template: ScheduleTemplate? {
        switch self {
        case .standard: nil
        case .pomodoro: .pomodoro
        case .fiftyTwoSeventeen: .fiftyTwoSeventeen
        case .twentyTwentyTwenty: .twentyTwentyTwenty
        }
    }
}

/// What the user picked during onboarding. Nothing is stored until Done.
public struct OnboardingChoices: Equatable, Sendable {
    public var rhythm: OnboardingRhythm = .standard
    public var level: DisciplineLevel = .gentle
    public var createsSchedule = true
    public var scene: MenuScene
    public var launchAtLogin = false

    public init(scene: MenuScene) {
        self.scene = scene
    }

    /// Weekdays 09:00-17:00 with the chosen rhythm and level, or nil after Set Up Later.
    /// `name` is passed in already localized.
    public func schedule(named name: String) -> Schedule? {
        guard createsSchedule else { return nil }
        var draft = ScheduleDraft(schedule: nil)
        if let template = rhythm.template {
            template.apply(to: &draft)
        } else {
            draft.intervalRows = [IntervalRow(minutes: 45)]
            draft.breakDurationMinutes = 5
        }
        draft.disciplineLevel = level
        // Last: `apply` renames a blank draft to the template title.
        draft.name = name
        return draft.build(existing: nil)
    }

    public func asksForStrictPermission(strictAvailable: Bool) -> Bool {
        createsSchedule && level == .strict && !strictAvailable
    }
}

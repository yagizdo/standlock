import SwiftUI
import StandLockCore

/// The first schedule's rhythm and level. Nothing is stored until Done.
struct OnboardingScheduleStep: View {
    @Binding var choices: OnboardingChoices

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.sectionSpacing) {
            OnboardingHeading("Your first schedule", "Weekdays, 09:00 to 17:00. You can change any of it later in Settings.")

            SettingsSection("Rhythm") {
                rhythmRow(.standard, Text("Every 45 minutes, a 5 minute break"), detail: nil)
                SettingsRowDivider()
                rhythmRow(.pomodoro, Text(verbatim: ScheduleTemplate.pomodoro.title), detail: "Every 25 minutes, a 5 minute break")
                SettingsRowDivider()
                rhythmRow(.fiftyTwoSeventeen, Text(verbatim: ScheduleTemplate.fiftyTwoSeventeen.title), detail: "Every 52 minutes, a 17 minute break")
                SettingsRowDivider()
                rhythmRow(.twentyTwentyTwenty, Text(verbatim: ScheduleTemplate.twentyTwentyTwenty.title), detail: "Every 20 minutes, 20 seconds away from the screen")
            }

            SettingsSection("How you get out of a break") {
                levelRow(.gentle, symbol: "hand.raised", detail: "Click Skip.")
                SettingsRowDivider()
                levelRow(.firm, symbol: "timer", detail: "Wait, then type a phrase.")
                SettingsRowDivider()
                levelRow(.strict, symbol: "lock.shield", detail: "Keyboard and mouse are blocked. Hold Control, Option and Command to leave. Needs permission in System Settings.")
            }
        }
    }

    private func rhythmRow(_ rhythm: OnboardingRhythm, _ title: Text, detail: LocalizedStringKey?) -> some View {
        OnboardingChoiceRow(
            title: title,
            detail: detail,
            isRecommended: rhythm == .standard,
            isSelected: choices.rhythm == rhythm
        ) {
            choices.rhythm = rhythm
        }
    }

    private func levelRow(_ level: DisciplineLevel, symbol: String, detail: LocalizedStringKey) -> some View {
        OnboardingChoiceRow(
            title: Text(LocalizedStringKey(level.displayName)),
            detail: detail,
            symbol: symbol,
            tone: level,
            isSelected: choices.level == level
        ) {
            choices.level = level
        }
    }
}

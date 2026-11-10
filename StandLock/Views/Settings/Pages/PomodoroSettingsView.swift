import SwiftUI
import StandLockCore

struct PomodoroSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsPageLayout("Pomodoro") {
            SettingsSection(note: "Start a session from the menu bar. Changes apply to the next session.") {
                minutesRow("Focus length", symbol: "timer", value: \.focus, in: PomodoroConfiguration.focusRange)
                SettingsRowDivider()
                minutesRow("Short break", symbol: "cup.and.saucer", value: \.shortBreak, in: PomodoroConfiguration.breakRange)
                SettingsRowDivider()
                minutesRow("Long break", symbol: "moon.zzz", value: \.longBreak, in: PomodoroConfiguration.breakRange)
                SettingsRowDivider()
                SettingsRow("Rounds", symbol: "repeat") {
                    stepper("Rounds", value: $coordinator.preferences.pomodoro.rounds, in: PomodoroConfiguration.roundsRange) {
                        Text(verbatim: "\($0)")
                    }
                }
            }
        }
    }

    /// Stored in seconds, edited in whole minutes.
    private func minutesRow(
        _ title: LocalizedStringKey,
        symbol: String,
        value: WritableKeyPath<PomodoroConfiguration, TimeInterval>,
        in range: ClosedRange<Int>
    ) -> some View {
        let minutes = Binding<Int>(
            get: { Int(coordinator.preferences.pomodoro[keyPath: value] / 60) },
            set: { coordinator.preferences.pomodoro[keyPath: value] = TimeInterval($0 * 60) }
        )
        return SettingsRow(title, symbol: symbol) {
            stepper(title, value: minutes, in: range) { Text("\($0) min") }
        }
    }

    /// The value sits beside the stepper, as on the other pages.
    private func stepper(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        label: @escaping (Int) -> Text
    ) -> some View {
        HStack(spacing: SettingsTokens.rowSpacing) {
            label(value.wrappedValue)
                .monospacedDigit()
                .accessibilityHidden(true)
            Stepper(title, value: value, in: range)
                .labelsHidden()
                .accessibilityValue(label(value.wrappedValue))
        }
    }
}

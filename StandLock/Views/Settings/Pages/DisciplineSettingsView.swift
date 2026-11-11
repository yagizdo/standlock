import SwiftUI

struct DisciplineSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsPageLayout("Discipline") {
            SettingsSection(
                "Daily skip limits",
                note: "Strict has no Skip button. To end a break early, hold Control, Option and Command together; the break screen shows for how long."
            ) {
                skipLimitRow(
                    "Gentle",
                    symbol: "hand.raised",
                    stepperLabel: "Gentle Daily Skip Limit",
                    value: $coordinator.preferences.gentleDailySkipLimit
                )

                SettingsRowDivider()

                skipLimitRow(
                    "Firm",
                    symbol: "timer",
                    stepperLabel: "Firm Daily Skip Limit",
                    value: $coordinator.preferences.firmDailySkipLimit
                )
            }

            SettingsSection {
                SettingsToggleRow(
                    "Skipping a break does not buy extra work time",
                    symbol: "forward.end",
                    description: "When on, skipping a break does not move the next one. For example, with a break every 55 minutes, if you skip the 10:00 break, the next one still comes at 10:55. When off, the 55 minutes start again from when you skip: skip at 10:04 and the next break comes at 10:59.",
                    isOn: skipKeepsTheSlot
                )
            }
        }
    }

    /// Inverted: on is the stricter choice, and the stored default stays `true`.
    private var skipKeepsTheSlot: Binding<Bool> {
        Binding(
            get: { !coordinator.preferences.resetIntervalOnSkip },
            set: { coordinator.preferences.resetIntervalOnSkip = !$0 }
        )
    }

    /// The number sits beside the stepper because Show help can hide the description.
    private func skipLimitRow(
        _ title: LocalizedStringKey,
        symbol: String,
        stepperLabel: LocalizedStringKey,
        value: Binding<Int>
    ) -> some View {
        SettingsRow(title, symbol: symbol, description: "You can skip \(value.wrappedValue) breaks a day. After that the Skip button is gone until tomorrow, and only the emergency exit is left: hold Control, Option and Command for 30 seconds.") {
            HStack(spacing: SettingsTokens.rowSpacing) {
                Text(verbatim: "\(value.wrappedValue)")
                    .monospacedDigit()
                    .accessibilityHidden(true)
                Stepper(stepperLabel, value: value, in: 1...20)
                    .labelsHidden()
                    .accessibilityValue(Text(verbatim: "\(value.wrappedValue)"))
            }
        }
    }
}

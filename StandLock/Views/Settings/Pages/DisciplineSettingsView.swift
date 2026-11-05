import SwiftUI

struct DisciplineSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        SettingsPageLayout("Discipline") {
            SettingsSection(
                "Daily skip limits",
                note: "Strict has no skip limit; only the emergency escape combo ends a break early."
            ) {
                skipLimitRow(
                    "Gentle",
                    stepperLabel: "Gentle Daily Skip Limit",
                    value: $coordinator.preferences.gentleDailySkipLimit
                )

                Divider()

                skipLimitRow(
                    "Firm",
                    stepperLabel: "Firm Daily Skip Limit",
                    value: $coordinator.preferences.firmDailySkipLimit
                )
            }
        }
    }

    /// The number sits beside the stepper because Show help can hide the description.
    private func skipLimitRow(
        _ title: LocalizedStringKey,
        stepperLabel: LocalizedStringKey,
        value: Binding<Int>
    ) -> some View {
        SettingsRow(title, description: "\(value.wrappedValue) skips per day before breaks stop being dismissible") {
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

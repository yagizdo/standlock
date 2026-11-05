import SwiftUI
import StandLockCore

struct MenuBarSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore

    /// Fixed sample input, so the preview follows the toggle while paused or with no schedule.
    private var previewTimer: String? {
        formatMenuBarTimer(
            secondsRemaining: 12 * 60,
            showFullTimer: coordinator.preferences.showFullWorkTimer,
            countdownMinutes: coordinator.preferences.menuBarCountdownMinutes,
            isBreakActive: false,
            isPaused: false,
            hasScheduledBreak: true,
            minuteSuffix: languageStore.string("m")
        )
    }

    var body: some View {
        SettingsPageLayout("Menu Bar") {
            SettingsSection("Preview") {
                HStack(spacing: SettingsTokens.stripItemSpacing) {
                    Image(nsImage: MenuBarIcon.make(progress: 0.5))
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                    if let previewTimer {
                        Text(previewTimer)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(SettingsTokens.stripInsets)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: SettingsTokens.stripRadius))
                .padding(SettingsTokens.rowInsets)
            }

            SettingsSection("Timer") {
                SettingsToggleRow(
                    "Show Full Work Timer",
                    description: "Always display remaining time next to the icon",
                    isOn: $coordinator.preferences.showFullWorkTimer
                )

                if !coordinator.preferences.showFullWorkTimer {
                    Divider()
                    SettingsRow("Countdown Start", description: "Show timer in the last minutes before break") {
                        Picker("Countdown Start", selection: $coordinator.preferences.menuBarCountdownMinutes) {
                            Text("1 min").tag(1)
                            Text("2 min").tag(2)
                            Text("3 min").tag(3)
                            Text("5 min").tag(5)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
        }
    }
}

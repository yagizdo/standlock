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
            minuteSuffix: languageStore.string("m"),
            hourSuffix: languageStore.string("h")
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

            SettingsSection("Scene", note: "The picture at the top of the menu bar panel") {
                MenuScenePicker(selection: $coordinator.preferences.menuScene)
            }

            SettingsSection("Timer") {
                SettingsToggleRow(
                    "Show Full Work Timer",
                    symbol: "timer",
                    description: "Shows the time left until the next break next to the menu bar icon all the time. When off, it shows only in the last minutes.",
                    isOn: $coordinator.preferences.showFullWorkTimer
                )

                if !coordinator.preferences.showFullWorkTimer {
                    SettingsRowDivider()
                    SettingsRow("Countdown Start", symbol: "arrow.turn.down.right", description: "How many minutes before a break the time left starts showing next to the icon.") {
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

import SwiftUI
import StandLockCore

/// Where a user looks after a break would not close or StandLock acted oddly. The status rows and
/// the way out of each level are instructions and states, so Show help never hides them.
struct TroubleshootingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var isConfirmingStrictOff = false

    /// Asked on every body: pending turns to past while the page stays open, and the coordinator
    /// publishes at least every 10 s.
    private var uncleanExit: UncleanExitStatus? {
        UncleanExitStatus.make(
            reopenedAt: UserDefaults.standard.object(forKey: AppCoordinator.lastUncleanExitKey) as? Date,
            // Unknown launch date: claim no pending break rather than a guard this run may not hold.
            launchedAt: NSRunningApplication.current.launchDate ?? .distantFuture, now: Date()
        )
    }

    var body: some View {
        SettingsPageLayout("Troubleshooting") {
            if let uncleanExit {
                SettingsSection("Last launch") {
                    TroubleshootingRow(
                        "The last break did not finish", symbol: "exclamationmark.triangle", isWarning: true,
                        text: uncleanExitText(uncleanExit)
                    )
                }
            }

            SettingsSection("Right now") {
                TroubleshootingStatusRow(coordinator: coordinator)
                StrictInactiveRow(schedules: coordinator.schedules, navigation: coordinator.settingsNavigation)
            }

            SettingsSection("If a break won't close", note: "You can't open Settings while a break is on screen.") {
                TroubleshootingRow("Gentle", symbol: "forward", text: Text(
                    "Click Skip this break. With Progressive Enforcement on, later breaks may first ask you to wait, play a short game or type a sentence."
                ))
                SettingsRowDivider()
                TroubleshootingRow("Firm", symbol: "keyboard", text: Text(
                    "Wait for the countdown, then type the sentence shown on the break screen. With Progressive Enforcement on, some breaks ask for a short game instead."
                ))
                SettingsRowDivider()
                TroubleshootingRow("Strict", symbol: "command", text: Text(
                    "Hold Control, Option and Command until the countdown ends. The break screen shows how long."
                ))
                SettingsRowDivider()
                TroubleshootingRow("Daily skip limit reached", symbol: "exclamationmark.octagon", text: Text(
                    "In Gentle and Firm, hold Control, Option and Command for 30 seconds."
                ))
                SettingsRowDivider()
                TroubleshootingRow("If nothing else works", symbol: "power", text: Text(
                    "Hold the power button until the Mac turns off. When StandLock opens again, the first break comes after 15 minutes, and you can skip it."
                ))
                if coordinator.schedules.containsStrict {
                    SettingsRowDivider()
                    TroubleshootingRow("Turn Off Strict", symbol: "arrow.down.circle",
                                       text: Text("Every schedule that uses Strict switches to Firm.")) {
                        Button("Turn Off Strict") { isConfirmingStrictOff = true }
                    }
                }
            }

            ResetSection()
        }
        // A sheet on the window, never `runModal`: a break can start under a modal.
        .alert(Text("Turn Off Strict?"), isPresented: $isConfirmingStrictOff) {
            Button("Turn Off Strict") { coordinator.lowerStrictToFirm() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every schedule that uses Strict switches to Firm.")
        }
    }

    private func uncleanExitText(_ status: UncleanExitStatus) -> Text {
        let reopened = Text(status.reopenedAt, style: .time)
        if status.isFirstBreakPending {
            let notBefore = Text(status.firstBreakNotBefore, style: .time)
            return Text("StandLock reopened at \(reopened) after closing during a break. Your next break comes at \(notBefore) or later, and you can skip it.")
        }
        let day = Text(status.reopenedAt, style: .date)
        return Text("StandLock reopened on \(day), \(reopened) after closing during a break. The first break after that could be skipped.")
    }
}

import SwiftUI
import StandLockCore

/// A leaf, so the checker's 2 s publishes stop here. Shown while a Strict schedule runs as Firm.
struct StrictInactiveRow: View {
    @EnvironmentObject private var checker: PermissionChecker

    let schedules: [Schedule]
    let navigation: SettingsNavigation

    var body: some View {
        if schedules.contains(where: checker.strictIsInactive) {
            SettingsRowDivider()
            TroubleshootingRow(
                "Strict is running as Firm", symbol: "lock.shield", isWarning: true,
                text: Text("Strict needs Accessibility and Input Monitoring. Until both are on, Strict breaks work like Firm.")
            ) {
                Button("Open Permissions") { navigation.select(.permissions) }
            }
        }
    }
}

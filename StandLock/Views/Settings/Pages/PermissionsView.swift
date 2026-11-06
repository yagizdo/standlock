import SwiftUI
import StandLockCore

struct PermissionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var checker: PermissionChecker

    var body: some View {
        SettingsPageLayout("Permissions") {
            if coordinator.schedules.contains(where: scheduleUsesStrict) {
                SettingsSection("Needed by your schedules") {
                    if !checker.strictModeAvailable {
                        strictWarning
                        Divider()
                    }
                    accessibilityRow
                    Divider()
                    inputMonitoringRow
                }
                SettingsSection("Optional") {
                    calendarRow
                }
            } else {
                SettingsSection("Optional", note: "StandLock works without any of them.") {
                    accessibilityRow
                    Divider()
                    inputMonitoringRow
                    Divider()
                    calendarRow
                }
            }
        }
    }

    private var strictWarning: some View {
        Label("Strict inactive, running as Firm", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(SettingsTokens.rowInsets)
            .help(LocalizedStringKey(checker.strictModeBlockedReason ?? ""))
    }

    private var accessibilityRow: some View {
        PermissionRow(
            title: "Accessibility",
            description: "Enables Strict mode to fully block keyboard and mouse input.",
            permission: .accessibility,
            status: checker.accessibilityStatus,
            grant: { checker.requestAccessibility() }
        )
    }

    private var inputMonitoringRow: some View {
        PermissionRow(
            title: "Input Monitoring",
            description: "Enables the escape key combo that ends a Strict break.",
            permission: .inputMonitoring,
            status: checker.inputMonitoringStatus,
            grant: { checker.requestInputMonitoring() }
        )
    }

    private var calendarRow: some View {
        PermissionRow(
            title: "Calendar Access",
            description: "Defer breaks during calendar events.",
            permission: .calendar,
            status: checker.calendarPermissionStatus,
            grant: { checker.requestCalendar() }
        )
    }
}

/// The status mark sits outside the description: Show help hides that, and a status is not help.
struct PermissionRow: View {
    @EnvironmentObject private var checker: PermissionChecker

    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let permission: PermissionType
    let status: PermissionStatus
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: mark.symbol)
                .foregroundStyle(mark.color)
                .frame(width: SettingsTokens.statusMarkWidth)
                .padding(.leading, SettingsTokens.rowInsets.leading)
                .accessibilityLabel(Text(mark.label))

            SettingsRow(title, symbol: "lock.shield", description: description) {
                actionButton
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .granted:
            EmptyView()
        case .notGranted:
            Button("Grant", action: grant)
        case .denied:
            Button("Open Settings") { checker.openSystemSettings(for: permission) }
        case .needsRestart:
            Button("Restart") { checker.relaunchApp() }
        }
    }

    private var mark: (symbol: String, color: Color, label: LocalizedStringKey) {
        switch status {
        case .granted: ("checkmark.circle.fill", .green, "Granted")
        case .notGranted: ("exclamationmark.circle", .orange, "Not granted")
        case .denied: ("xmark.circle.fill", .red, "Denied")
        case .needsRestart: ("arrow.clockwise.circle.fill", .orange, "Restart needed")
        }
    }
}

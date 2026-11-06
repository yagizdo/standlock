import SwiftUI
import StandLockCore

struct PermissionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var checker: PermissionChecker

    var body: some View {
        SettingsPageLayout("Permissions") {
            if coordinator.schedules.contains(where: scheduleUsesStrict) {
                group("Needed by your schedules") {
                    if !checker.strictModeAvailable {
                        SettingsSection { strictWarning }
                    }
                    accessibilityCard
                    inputMonitoringCard
                }
                group("Optional") {
                    calendarCard
                }
            } else {
                group("Optional", note: "StandLock works without any of them.") {
                    accessibilityCard
                    inputMonitoringCard
                    calendarCard
                }
            }
        }
    }

    /// `SettingsSection`'s heading and note over separate cards instead of one.
    private func group<Content: View>(
        _ title: LocalizedStringKey,
        note: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SettingsTokens.sectionTitleSpacing) {
            Text(title)
                .font(SettingsTokens.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SettingsTokens.sectionTitleInset)

            VStack(spacing: SettingsTokens.permissionCardSpacing) {
                content()
            }

            if let note {
                SettingsDescription(note)
                    .padding(.horizontal, SettingsTokens.sectionTitleInset)
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

    // `figure.stand`, not `accessibility`: that symbol needs macOS 14.
    private var accessibilityCard: some View {
        PermissionCard(
            title: "Accessibility",
            symbol: "figure.stand",
            reason: "Strict breaks block your keyboard and mouse. macOS allows that only with this permission.",
            withoutIt: "Without it: Strict runs as Firm.",
            privacy: "Used only during a Strict break.",
            permission: .accessibility,
            status: checker.accessibilityStatus,
            grant: { checker.requestAccessibility() }
        )
    }

    private var inputMonitoringCard: some View {
        PermissionCard(
            title: "Input Monitoring",
            symbol: "keyboard",
            reason: "Lets StandLock notice when you hold Control, Option and Command to end a Strict break early.",
            withoutIt: "Without it: Strict runs as Firm.",
            privacy: "What you type is never read or saved.",
            permission: .inputMonitoring,
            status: checker.inputMonitoringStatus,
            grant: { checker.requestInputMonitoring() }
        )
    }

    private var calendarCard: some View {
        PermissionCard(
            title: "Calendar Access",
            symbol: "calendar",
            reason: "Lets StandLock keep breaks out of your meetings.",
            withoutIt: "Without it: breaks ignore your calendar.",
            privacy: "Reads event times only, never titles.",
            permission: .calendar,
            status: checker.calendarPermissionStatus,
            grant: { checker.requestCalendar() }
        )
    }
}

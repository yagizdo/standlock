import SwiftUI

struct PermissionsView: View {
    @StateObject private var checker = PermissionChecker()

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Input Monitoring",
                    description: "Detect keyboard activity for idle detection and escape combo. You'll need to enable it in System Settings.",
                    systemImage: "keyboard",
                    status: checker.inputMonitoringStatus,
                    settingsURLs: PermissionType.inputMonitoring.settingsURLs,
                    action: { checker.requestInputMonitoring() },
                    restartAction: { checker.relaunchApp() }
                )
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grant permissions that match your usage.")
                        .textCase(nil)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    Text("Recommended")
                }
            }

            Section("Optional") {
                PermissionRow(
                    title: "Accessibility",
                    description: "Enables Strict mode to fully block keyboard and mouse input. Requires manual toggle in System Settings.",
                    systemImage: "hand.raised.circle",
                    status: checker.accessibilityStatus,
                    settingsURLs: PermissionType.accessibility.settingsURLs,
                    action: { checker.requestAccessibility() },
                    restartAction: { checker.relaunchApp() }
                )

                PermissionRow(
                    title: "Calendar Access",
                    description: "Read your calendar to defer breaks during meetings.",
                    systemImage: "calendar",
                    status: checker.calendarPermissionStatus,
                    settingsURLs: PermissionType.calendar.settingsURLs,
                    action: { checker.requestCalendar() },
                    restartAction: { checker.relaunchApp() }
                )
            }
        }
        .formStyle(.grouped)
        .task { await checker.pollContinuously() }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    let status: PermissionStatus
    let settingsURLs: [URL]
    let action: () -> Void
    var restartAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.medium))
                    statusBadge
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status == .needsRestart {
                Button("Restart") {
                    restartAction?()
                }
                .controlSize(.small)
            } else if status != .granted {
                Button(status == .denied ? "Open Settings" : "Grant") {
                    if status == .denied {
                        openSystemSettings()
                    } else {
                        action()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .notGranted:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.yellow)
                .font(.caption)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .needsRestart:
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: .green
        case .notGranted: .secondary
        case .denied: .red
        case .needsRestart: .orange
        }
    }

    private func openSystemSettings() {
        for url in settingsURLs {
            if NSWorkspace.shared.open(url) { return }
        }
    }
}

import SwiftUI

struct PermissionsView: View {
    @State private var checker = PermissionChecker()

    var body: some View {
        Form {
            Section {
                Text("StandLock needs certain permissions to function properly. Grant the ones that match your usage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Recommended") {
                PermissionRow(
                    title: "Input Monitoring",
                    description: "Detect keyboard activity for idle detection and escape combo. You'll need to enable it in System Settings.",
                    systemImage: "keyboard",
                    status: checker.inputMonitoringGranted ? .granted : .notGranted,
                    action: {
                        checker.requestInputMonitoring()
                    }
                )
            }

            Section("Optional") {
                PermissionRow(
                    title: "Accessibility",
                    description: "Enables Strict mode to fully block keyboard and mouse input. Requires manual toggle in System Settings.",
                    systemImage: "hand.raised.circle",
                    status: checker.accessibilityGranted ? .granted : .notGranted,
                    action: {
                        checker.requestAccessibility()
                    }
                )

                PermissionRow(
                    title: "Calendar Access",
                    description: "Read your calendar to defer breaks during meetings.",
                    systemImage: "calendar",
                    status: checker.calendarPermissionStatus,
                    action: {
                        checker.requestCalendar()
                    }
                )
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checker.startPolling()
        }
        .onDisappear {
            checker.stopPolling()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    let status: PermissionStatus
    let action: () -> Void

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

            if status != .granted {
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
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: .green
        case .notGranted: .secondary
        case .denied: .red
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}

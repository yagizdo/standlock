import SwiftUI

struct PermissionsStepView: View {
    @State private var checker = PermissionChecker()
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("StandLock works best with these permissions. You can grant them now or later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                permissionCard(
                    icon: "keyboard",
                    name: "Input Monitoring",
                    description: "Detect keyboard activity for idle detection and escape combo.",
                    status: checker.inputMonitoringGranted ? .granted : .notGranted,
                    action: { checker.requestInputMonitoring() }
                )

                permissionCard(
                    icon: "figure.stand",
                    name: "Accessibility",
                    description: "Enables Strict mode to fully block input during breaks.",
                    status: checker.accessibilityGranted ? .granted : .notGranted,
                    action: { checker.requestAccessibility() }
                )

                permissionCard(
                    icon: "calendar",
                    name: "Calendar Access",
                    description: "Defer breaks during calendar events.",
                    status: checker.calendarPermissionStatus,
                    isOptional: true,
                    action: { checker.requestCalendar() }
                )
            }
            .padding(.horizontal)

            Spacer()

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await checker.pollContinuously() }
    }

    private func permissionCard(
        icon: String,
        name: String,
        description: String,
        status: PermissionStatus,
        isOptional: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(statusColor(for: status))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body.weight(.medium))
                    statusBadge(for: status, isOptional: isOptional)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status != .granted {
                Button("Grant") { action() }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statusBadge(for status: PermissionStatus, isOptional: Bool) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .notGranted:
            if isOptional {
                Image(systemName: "circle")
                    .foregroundStyle(.blue)
                    .font(.caption)
            } else {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private func statusColor(for status: PermissionStatus) -> Color {
        switch status {
        case .granted: .green
        case .notGranted: .secondary
        case .denied: .red
        }
    }
}

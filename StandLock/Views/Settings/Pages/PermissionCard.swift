import SwiftUI
import StandLockCore

/// One permission: why it is asked for, what happens without it, and what it never touches.
/// That text explains a security prompt, it is not help: it stays outside `SettingsDescription`.
struct PermissionCard: View {
    @EnvironmentObject private var checker: PermissionChecker

    let title: LocalizedStringKey
    let symbol: String
    let reason: LocalizedStringKey
    let withoutIt: LocalizedStringKey
    let privacy: LocalizedStringKey
    let permission: PermissionType
    let status: PermissionStatus
    let grant: () -> Void

    var body: some View {
        SettingsSection {
            HStack(alignment: .top, spacing: SettingsTokens.rowSpacing) {
                SettingsIconChip(symbol: symbol, tone: nil, size: SettingsTokens.permissionChipSize)

                VStack(alignment: .leading, spacing: SettingsTokens.listItemSpacing) {
                    HStack(spacing: SettingsTokens.blockSpacing) {
                        Text(title)
                            .fontWeight(.semibold)
                        statusPill
                        Spacer()
                        actionButton
                            .controlSize(.small)
                    }

                    Text(reason)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: SettingsTokens.permissionNoteSpacing) {
                        note(withoutIt, symbol: "minus.circle")
                        note(privacy, symbol: "lock")
                    }
                }
            }
            .padding(SettingsTokens.previewInsets)
        }
    }

    private var statusPill: some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            Image(systemName: mark.symbol)
                .accessibilityHidden(true)
            Text(mark.label)
        }
        .font(SettingsTokens.pillFont)
        .foregroundStyle(mark.color)
        .padding(SettingsTokens.pillInsets)
        .background(mark.color.opacity(0.14), in: Capsule())
    }

    private func note(_ text: LocalizedStringKey, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsTokens.listItemSpacing) {
            Image(systemName: symbol)
                .frame(width: SettingsTokens.permissionNoteIconWidth)
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(SettingsTokens.descriptionFont)
        .foregroundStyle(.secondary)
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
        case .granted: ("checkmark", .green, "Granted")
        case .notGranted: ("exclamationmark", .orange, "Not granted")
        case .denied: ("xmark", .red, "Denied")
        case .needsRestart: ("arrow.clockwise", .orange, "Restart needed")
        }
    }
}

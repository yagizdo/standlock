import SwiftUI
@preconcurrency import Sparkle

struct AboutView: View {
    @EnvironmentObject private var updateObserver: UpdateObserver

    let updater: SPUUpdater

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private static let appIcon: NSImage = {
        let icon = NSApp.applicationIconImage ?? NSImage()
        icon.size = NSSize(width: 256, height: 256)
        return icon
    }()

    var body: some View {
        SettingsPageLayout("About") {
            SettingsSection {
                identity
            }

            SettingsSection("Updates") {
                UpdaterSettingsView(updater: updater)
                SettingsRowDivider()
                SettingsRow("Version \(version)", symbol: "number") {
                    CheckForUpdatesView(updater: updater, observer: updateObserver)
                        .controlSize(.small)
                }
                Divider()
                UpdateStatusRow(updater: updater)
            }

            SettingsSection("Links") {
                linkRow("GitHub", url: "https://github.com/yagizdo/StandLock")
                SettingsRowDivider()
                linkRow("Website", url: "https://standlock.app")
                SettingsRowDivider()
                linkRow("Twitter", url: "https://x.com/yagizdo")
            }

            Text("© 2026 Yılmaz Yağız Dokumacı. MIT License.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }

    /// The version here is identity, not help: it stays outside `SettingsDescription`.
    private var identity: some View {
        VStack(spacing: SettingsTokens.identitySpacing) {
            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: SettingsTokens.identityIconSize, height: SettingsTokens.identityIconSize)
                .clipShape(.rect(cornerRadius: SettingsTokens.identityIconRadius))
                .accessibilityHidden(true)

            Text("StandLock")
                .font(SettingsTokens.pageTitleFont)

            Text("Version \(version) (Build \(build))")
                .font(SettingsTokens.descriptionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SettingsTokens.identityInset)
    }

    private func linkRow(_ title: LocalizedStringKey, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            SettingsRow(title, symbol: "link") {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

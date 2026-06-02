import SwiftUI
@preconcurrency import Sparkle

struct AboutView: View {
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
        VStack(spacing: 16) {
            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 18))

            Text("StandLock")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(version) (Build \(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                UpdaterSettingsView(updater: updater)
                CheckForUpdatesView(updater: updater)
            }
            .padding(.horizontal, 40)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                aboutLink("GitHub", icon: "curlybraces", url: "https://github.com/yagizdo/StandLock")
                aboutLink("Website", icon: "globe", url: "https://standlock.app")
                aboutLink("Twitter", icon: "at", url: "https://x.com/yagizdo")
            }

            Text("© 2026 Yılmaz Yağız Dokumacı. MIT License.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func aboutLink(_ title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: icon)
                .font(.footnote)
        }
    }
}

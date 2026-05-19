import SwiftUI
@preconcurrency import Sparkle

struct AboutView: View {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 18))

            Text("StandLock")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(version) (Build \(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                UpdaterSettingsView(updater: appDelegate.updaterController.updater)
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Made by Yağız")
                    .font(.callout)
                Link("GitHub", destination: URL(string: "https://github.com/yagizdo/StandLock")!)
                    .font(.callout)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

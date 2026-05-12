import SwiftUI
import Combine
@preconcurrency import Sparkle

struct AboutView: View {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var canCheckForUpdates = false
    @AppStorage("updateChannel") private var updateChannel = "stable"

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
                if let updater = appDelegate.updaterController?.updater {
                    Toggle("Automatic Updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }

                HStack {
                    Text("Update Channel")
                    Spacer()
                    Picker("", selection: $updateChannel) {
                        Text("Stable").tag("stable")
                        Text("Beta").tag("beta")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Text(updateChannel == "beta"
                     ? "Receive early access builds that may contain bugs."
                     : "Receive only stable, tested releases.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Check for Updates…") {
                    appDelegate.updaterController?.checkForUpdates(nil)
                }
                .disabled(!canCheckForUpdates)
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
        .onReceive(
            appDelegate.updaterController?.updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()
            ?? Just(false).eraseToAnyPublisher()
        ) { value in
            canCheckForUpdates = value
        }
    }
}

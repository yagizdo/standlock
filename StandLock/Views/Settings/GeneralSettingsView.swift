import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @State private var launchAtStartup = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $launchAtStartup) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Startup")
                            Text("Open StandLock when you log in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "laptopcomputer")
                    }
                }
                .onChange(of: launchAtStartup) { newValue in
                    guard !isUpdating else { return }
                    setLaunchAtStartup(newValue)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtStartup(_ enabled: Bool) {
        isUpdating = true
        defer { isUpdating = false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            launchAtStartup = !enabled
            errorMessage = "Failed to update login item: \(error.localizedDescription)"
        }
    }
}

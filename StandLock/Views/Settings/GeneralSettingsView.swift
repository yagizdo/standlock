import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @State private var launchAtStartup = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Startup", isOn: $launchAtStartup)
                    .onChange(of: launchAtStartup) { _, newValue in
                        guard !isUpdating else { return }
                        setLaunchAtStartup(newValue)
                    }

                Text("Automatically open StandLock when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

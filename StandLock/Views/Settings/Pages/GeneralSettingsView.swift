import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var launchAtStartup = LaunchAtLogin.isEnabled
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        SettingsPageLayout("General") {
            SettingsSection("Startup") {
                SettingsToggleRow(
                    "Launch at Startup",
                    symbol: "power",
                    description: "Open StandLock when you log in",
                    isOn: $launchAtStartup
                )
                .onChange(of: launchAtStartup) { newValue in
                    guard !isUpdating else { return }
                    setLaunchAtStartup(newValue)
                }

                if let errorMessage {
                    Divider()
                    Text("Failed to update login item: \(errorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(SettingsTokens.rowInsets)
                }
            }

            SettingsSection("Language and appearance") {
                SettingsRow("Language", symbol: "globe", description: "System follows your Mac's language") {
                    Picker("Language", selection: Binding(
                        get: { languageStore.selection },
                        set: { languageStore.select($0) }
                    )) {
                        Text("System").tag(String?.none)
                        ForEach(languageStore.available, id: \.self) { code in
                            Text(languageStore.displayName(for: code)).tag(Optional(code))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                SettingsRowDivider()

                SettingsRow("Appearance", symbol: "circle.lefthalf.filled", description: "System follows your Mac's appearance") {
                    Picker("Appearance", selection: Binding(
                        get: { themeStore.selection },
                        set: { themeStore.select($0) }
                    )) {
                        Text("System").tag(String?.none)
                        // Built from the store's list, so a theme added later needs no
                        // change here.
                        ForEach(themeStore.available) { theme in
                            Text(LocalizedStringKey(theme.nameKey)).tag(Optional(theme.id))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsFileSection()

            ResetSection()
        }
    }

    private func setLaunchAtStartup(_ enabled: Bool) {
        isUpdating = true
        defer { isUpdating = false }
        do {
            try LaunchAtLogin.set(enabled)
            errorMessage = nil
        } catch {
            launchAtStartup = !enabled
            errorMessage = error.localizedDescription
        }
    }
}

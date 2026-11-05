import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var launchAtStartup = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        SettingsPageLayout("General") {
            SettingsSection("Startup") {
                SettingsToggleRow(
                    "Launch at Startup",
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
                SettingsRow("Language", description: "System follows your Mac's language") {
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

                Divider()

                SettingsRow("Appearance", description: "System follows your Mac's appearance") {
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

            SettingsSection("Break Screen") {
                BreakScreenSettingsSection()
                    .padding(SettingsTokens.rowInsets)
            }

            SettingsSection("Menu Bar Display") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $coordinator.preferences.showFullWorkTimer) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Full Work Timer")
                                Text("Always display remaining time next to the icon")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "timer")
                        }
                    }
                    .onChange(of: coordinator.preferences.showFullWorkTimer) { _ in
                        coordinator.savePreferences()
                    }

                    if !coordinator.preferences.showFullWorkTimer {
                        Picker(selection: $coordinator.preferences.menuBarCountdownMinutes) {
                            Text("1 min").tag(1)
                            Text("2 min").tag(2)
                            Text("3 min").tag(3)
                            Text("5 min").tag(5)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Countdown Start")
                                    Text("Show timer in the last minutes before break")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "clock.badge.checkmark")
                            }
                        }
                        .onChange(of: coordinator.preferences.menuBarCountdownMinutes) { _ in
                            coordinator.savePreferences()
                        }
                    }
                }
                .padding(SettingsTokens.rowInsets)
            }

            SettingsSection("Discipline") {
                VStack(alignment: .leading, spacing: 10) {
                    skipLimitStepper(
                        title: "Gentle Daily Skip Limit",
                        icon: "hand.raised",
                        value: $coordinator.preferences.gentleDailySkipLimit
                    )

                    skipLimitStepper(
                        title: "Firm Daily Skip Limit",
                        icon: "timer",
                        value: $coordinator.preferences.firmDailySkipLimit
                    )

                    Label {
                        Text("Strict has no skip limit; only the emergency escape combo ends a break early.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                }
                .padding(SettingsTokens.rowInsets)
            }
        }
    }

    private func skipLimitStepper(title: LocalizedStringKey, icon: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...20) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text("\(value.wrappedValue) skips per day before breaks stop being dismissible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
            }
        }
        .onChange(of: value.wrappedValue) { _ in
            coordinator.savePreferences()
        }
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
            errorMessage = error.localizedDescription
        }
    }
}

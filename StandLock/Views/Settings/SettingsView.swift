import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(AppCoordinator.SettingsTab.general)

            ScheduleEditorView()
                .tabItem { Label("Schedules", systemImage: "calendar.badge.clock") }
                .tag(AppCoordinator.SettingsTab.schedules)

            DetectionSettingsView()
                .tabItem { Label("Detection", systemImage: "eye") }
                .tag(AppCoordinator.SettingsTab.detection)

            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(AppCoordinator.SettingsTab.permissions)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(AppCoordinator.SettingsTab.about)
        }
        .frame(width: 520, height: 480)
    }
}

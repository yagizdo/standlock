import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ScheduleEditorView()
                .tabItem { Label("Schedules", systemImage: "calendar.badge.clock") }

            DetectionSettingsView()
                .tabItem { Label("Detection", systemImage: "eye") }

            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 480)
    }
}

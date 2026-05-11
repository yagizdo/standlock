import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ScheduleEditorView()
                .tabItem { Label("Schedules", systemImage: "calendar.badge.clock") }

            DetectionSettingsView()
                .tabItem { Label("Detection", systemImage: "eye") }

            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 460)
    }
}

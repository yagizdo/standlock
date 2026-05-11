import SwiftUI

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("StandLock", systemImage: "lock.circle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("StandLock")
                    .font(.headline)
                Text("No schedules configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Button("Quit StandLock") {
                    NSApp.terminate(nil)
                }
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}

import SwiftUI
import StandLockCore

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var appCoordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("StandLock", systemImage: "lock.circle") {
            MenuBarView()
                .environment(appCoordinator)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Settings placeholder")
                .frame(width: 520, height: 420)
                .environment(appCoordinator)
        }
    }
}

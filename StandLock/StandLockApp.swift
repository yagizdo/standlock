import SwiftUI
import StandLockCore

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appCoordinator)
        } label: {
            Image(nsImage: MenuBarIcon.make(progress: appCoordinator.breakProgress))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appCoordinator)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }
    }
}

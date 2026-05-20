import SwiftUI
import StandLockCore

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var appCoordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appCoordinator)
        } label: {
            Image(nsImage: MenuBarIcon.make(progress: appCoordinator.breakProgress))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appCoordinator)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }
    }
}

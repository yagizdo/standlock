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
                .environmentObject(appCoordinator.permissionChecker)
                .environmentObject(appDelegate.updateObserver)
        } label: {
            Image(nsImage: MenuBarIcon.make(progress: appCoordinator.breakProgress))
            if let timerText = appCoordinator.menuBarTimerText {
                Text(timerText)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(selectedTab: $appCoordinator.selectedSettingsTab, updater: appDelegate.updaterController.updater)
                .environmentObject(appCoordinator)
                .environmentObject(appCoordinator.permissionChecker)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }
    }
}

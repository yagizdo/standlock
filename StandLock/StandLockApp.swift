import SwiftUI
import StandLockCore

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            LocalizedRoot(store: appCoordinator.languageStore) {
                MenuBarView()
                    .environmentObject(appCoordinator)
                    .environmentObject(appCoordinator.permissionChecker)
                    .environmentObject(appDelegate.updateObserver)
            }
        } label: {
            Image(nsImage: MenuBarIcon.make(progress: appCoordinator.breakProgress))
            if let timerText = appCoordinator.menuBarTimerText {
                Text(timerText)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            LocalizedRoot(store: appCoordinator.languageStore) {
                SettingsView(selectedTab: $appCoordinator.selectedSettingsTab, updater: appDelegate.updaterController.updater)
                    .environmentObject(appCoordinator)
                    .environmentObject(appCoordinator.permissionChecker)
                    .environmentObject(appCoordinator.themeStore)
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }
    }
}

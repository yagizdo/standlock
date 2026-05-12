import SwiftUI
import StandLockCore

@main
struct StandLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var appCoordinator = AppCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("StandLock", systemImage: "lock.circle") {
            MenuBarView()
                .environment(appCoordinator)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appCoordinator)
        }

        Window("Welcome to StandLock", id: "onboarding") {
            OnboardingView()
                .environment(appCoordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 520)
        .windowResizability(.contentSize)
    }
}

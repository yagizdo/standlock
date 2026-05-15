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
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate()
                }
                .onDisappear {
                    let hasVisibleWindows = NSApp.windows.contains { window in
                        window.isVisible && !(window is NSPanel)
                    }
                    if !hasVisibleWindows {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }

        Window("Welcome to StandLock", id: "onboarding") {
            OnboardingView()
                .environment(appCoordinator)
                .onAppear { NSApp.activate() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 520)
        .windowResizability(.contentSize)
    }
}

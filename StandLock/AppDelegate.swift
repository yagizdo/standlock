import AppKit
import StandLockCore
@preconcurrency import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updateObserver = UpdateObserver()
    let updaterController: SPUStandardUpdaterController

    override init() {
        let homebrewPrefix = HomebrewInstall.prefix(appBundleURL: Bundle.main.bundleURL)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: homebrewPrefix == nil,
            updaterDelegate: updateObserver,
            userDriverDelegate: nil
        )
        super.init()
        if let homebrewPrefix { startHomebrewUpdates(prefix: homebrewPrefix) }
    }

    private func startHomebrewUpdates(prefix: URL) {
        let updater = updaterController.updater
        // Off in Info.plist, and with it most Homebrew copies would never see an update.
        if UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") == nil {
            updater.automaticallyChecksForUpdates = true
        }
        let homebrew = HomebrewUpdater(
            prefix: prefix,
            observer: updateObserver,
            automaticChecks: { updater.automaticallyChecksForUpdates },
            canRestart: { PermissionChecker.canRelaunchNow }
        )
        updateObserver.homebrew = homebrew
        homebrew.start()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Opening the running app again is the way back when the system hides the menu bar icon.
    /// False: the default would do nothing useful for an app with no regular window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .standLockReopen, object: nil)
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if PermissionChecker.isRelaunching { return .terminateNow }
        let hasActiveOverlay = sender.windows.contains { $0 is BreakOverlayWindow && $0.isVisible }
        if hasActiveOverlay { return .terminateCancel }
        for window in sender.windows {
            if let delegate = window.delegate as? SettingsWindowDelegate, !delegate.navigation.shouldQuit(window) {
                return .terminateCancel
            }
        }
        return .terminateNow
    }
}

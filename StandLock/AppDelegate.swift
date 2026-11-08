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
            canRestart: { [unowned self] in canRestartNow }
        )
        updateObserver.homebrew = homebrew
        homebrew.start()
    }

    /// What `applicationShouldTerminate` would refuse, asked without its side effects:
    /// `shouldQuit` queues a quit of its own. `isRelaunching` skips those checks, and a quit
    /// refused under a sheet would leave that flag set for every later quit.
    private var canRestartNow: Bool {
        !NSApp.windows.contains { window in
            if window is BreakOverlayWindow { return window.isVisible }
            guard let delegate = window.delegate as? SettingsWindowDelegate else { return false }
            return window.attachedSheet != nil || delegate.navigation.unsavedEdits?() == true
        }
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

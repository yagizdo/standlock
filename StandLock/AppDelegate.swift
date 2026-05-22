import AppKit
@preconcurrency import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    let updateObserver = UpdateObserver()
    let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updateObserver,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if PermissionChecker.isRelaunching { return .terminateNow }
        let hasActiveOverlay = sender.windows.contains { $0 is BreakOverlayWindow && $0.isVisible }
        return hasActiveOverlay ? .terminateCancel : .terminateNow
    }
}
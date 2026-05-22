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
}
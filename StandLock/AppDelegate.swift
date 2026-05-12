import AppKit
@preconcurrency import Sparkle

final class SparkleDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let channel = UserDefaults.standard.string(forKey: "updateChannel") ?? "stable"
        return channel == "beta" ? Set(["beta"]) : Set()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sparkleDelegate: SparkleDelegate?
    private(set) var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let delegate = SparkleDelegate()
        sparkleDelegate = delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
    }
}

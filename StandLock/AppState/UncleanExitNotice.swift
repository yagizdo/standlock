import AppKit
import StandLockCore

/// Shown once at the launch that found the last run died with a break on screen. A break that
/// opens while it is still up closes it (`OverlayWindowController.showOverlay`).
@MainActor
enum UncleanExitNotice {
    static func show(languageStore: LanguageStore) {
        let minutes = Int(UncleanExit.grace / 60)
        let alert = NSAlert()
        alert.messageText = languageStore.string("The last break did not finish")
        alert.informativeText = languageStore.string(
            "This can happen after a crash or after holding the power button. Your next break comes in \(minutes) minutes, and you can skip it.\n\nSettings are in the StandLock menu bar icon. If a break ever won't close, hold the power button to turn off the Mac."
        )
        alert.addButton(withTitle: languageStore.string("OK"))
        // A menu bar app is inactive at launch; the alert would open behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

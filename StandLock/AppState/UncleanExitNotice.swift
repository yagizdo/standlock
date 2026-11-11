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
            "StandLock closed while a break was on screen, for example after a crash or after the Mac was turned off with the power button. The next break comes in \(minutes) minutes and has a Skip button, so you have time to check your settings. Settings are under the StandLock icon in the menu bar. If a break ever cannot be closed, holding the power button turns the Mac off, and StandLock gives you this time again."
        )
        alert.addButton(withTitle: languageStore.string("OK"))
        // A menu bar app is inactive at launch; the alert would open behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

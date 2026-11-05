import AppKit
import Combine
import SwiftUI
import StandLockCore

/// What is waiting on the unsaved edits prompt.
enum PendingLeave {
    case page(SettingsPage)
    case closeWindow
    case quit
}

/// The selected Settings page and the only path that opens the Settings window.
@MainActor
final class SettingsNavigation: ObservableObject {
    static let windowID = "settings"

    @Published private(set) var page: SettingsPage = .general
    @Published private(set) var pendingLeave: PendingLeave?
    /// Set by the schedule page and asked at the moment of a selection. A flag kept by `onChange`
    /// would be a turn late: a measured edit followed by a row change on one turn went through.
    var unsavedEdits: (() -> Bool)?
    private weak var closingWindow: NSWindow?
    /// Fires on every open. The scene keeps the closed window, so its views never reappear.
    let opened = PassthroughSubject<Void, Never>()

    /// Opens Settings on `page`, or on the last page when `page` is nil.
    func open(_ page: SettingsPage?, using openWindow: OpenWindowAction) {
        // Settings would open beneath the overlay and take key from it. The overlay is not
        // always key: the skip confirmation alert holds key while it is up.
        if NSApp.windows.contains(where: { $0 is BreakOverlayWindow && $0.isVisible }) { return }

        // The MenuBarExtra panel stays up when another window opens, and SwiftUI gives
        // no handle on it. It is the key window while the click happens, so it is
        // grabbed here and hidden once Settings has been asked to open.
        let keyWindow = NSApp.keyWindow

        if let page { select(page) }
        openWindow(id: Self.windowID)
        // Deprecated in the header, but plain `activate()` did not make the window key.
        NSApp.activate(ignoringOtherApps: true)
        opened.send()
        dismissMenuBarPanel(keyWindow)
    }

    /// Moves to `page`, unless that would lose unsaved edits: then the schedule page asks first.
    func select(_ page: SettingsPage) {
        switch self.page.leaving(to: page, hasUnsavedEdits: unsavedEdits?() == true) {
        case .stay: break
        case .go: leave(to: page)
        case .ask:
            // The sidebar `List` has already moved its row. A publish on this turn leaves it
            // there; one on the next turn brings it back.
            DispatchQueue.main.async { self.pendingLeave = .page(page) }
        }
    }

    /// Moves to `page` with the draft dealt with, so nothing asks.
    func leave(to page: SettingsPage) {
        pendingLeave = nil
        guard page != self.page else { return }
        unsavedEdits = nil
        self.page = page
    }

    func cancelPending() {
        pendingLeave = nil
    }

    /// Returns whether `window` may close now. If not, the schedule page asks first.
    func shouldClose(_ window: NSWindow) -> Bool {
        guard unsavedEdits?() == true else { return true }
        closingWindow = window
        pendingLeave = .closeWindow
        return false
    }

    /// Returns whether the app may quit now. If not, `window` comes forward and the schedule page
    /// asks first. Quit often comes from the menu bar panel, with Settings behind other apps.
    func shouldQuit(_ window: NSWindow) -> Bool {
        guard unsavedEdits?() == true else { return true }
        let keyWindow = NSApp.keyWindow
        pendingLeave = .quit
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarPanel(keyWindow)
        return false
    }

    /// Carries out what was waiting, once the prompt has dealt with the draft.
    func finish(_ leave: PendingLeave) {
        switch leave {
        case .page(let page):
            self.leave(to: page)
        case .closeWindow:
            pendingLeave = nil
            // Not `close()`, and not on this turn: a window refuses to close under its sheet,
            // and the alert is still attached here.
            let window = closingWindow
            DispatchQueue.main.async { window?.performClose(nil) }
        case .quit:
            pendingLeave = nil
            // A later turn for the same reason: quitting is refused under a sheet too.
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// A deleted schedule has no draft left to protect, so this does not ask.
    func reconcile(scheduleIDs: [UUID]) {
        let resolved = page.resolved(scheduleIDs: scheduleIDs)
        if resolved != page { leave(to: resolved) }
    }

    /// Hides the MenuBarExtra panel captured before Settings was opened.
    ///
    /// `orderOut` rather than `close`: the panel hosts SwiftUI through an NSHostingView,
    /// and closing one of those deadlocks the main thread or frees it out from under the
    /// hosting view. The check names the panel instead of excluding Settings, because the
    /// captured window can be Settings itself when it was already key, or a sheet or the
    /// color panel, and none of those may be hidden.
    private func dismissMenuBarPanel(_ window: NSWindow?) {
        guard let window, window.className.contains("MenuBarExtraWindow") else { return }
        window.orderOut(nil)
    }
}

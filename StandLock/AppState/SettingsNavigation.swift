import AppKit
import SwiftUI
import StandLockCore

/// The selected Settings page and the only path that opens the Settings window.
@MainActor
final class SettingsNavigation: ObservableObject {
    static let windowID = "settings"

    @Published var page: SettingsPage = .general

    /// Opens Settings on `page`, or on the last page when `page` is nil.
    func open(_ page: SettingsPage?, using openWindow: OpenWindowAction) {
        // Settings would open beneath the overlay and take key from it. The overlay is not
        // always key: the skip confirmation alert holds key while it is up.
        if NSApp.windows.contains(where: { $0 is BreakOverlayWindow && $0.isVisible }) { return }

        // The MenuBarExtra panel stays up when another window opens, and SwiftUI gives
        // no handle on it. It is the key window while the click happens, so it is
        // grabbed here and hidden once Settings has been asked to open.
        let keyWindow = NSApp.keyWindow

        if let page { self.page = page }
        openWindow(id: Self.windowID)
        // Deprecated in the header, but plain `activate()` did not make the window key.
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarPanel(keyWindow)
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

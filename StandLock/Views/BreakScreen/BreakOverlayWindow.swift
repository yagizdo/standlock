import AppKit
import SwiftUI

final class BreakOverlayWindow: NSWindow {
    convenience init(screen: NSScreen, palette: BreakPalette, theme: AppTheme) {
        self.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = true
        // The controller assigns exactly this immediately after construction. Leaving
        // a white default here is what flashed a white frame before a dark overlay drew.
        backgroundColor = NSColor(palette.paper)
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        appearance = NSAppearance(named: theme.appearance)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentRect(forFrameRect: frame)
        contentView = hostingView
    }
}

import AppKit
import SwiftUI

final class BreakOverlayWindow: NSWindow {
    convenience init(screen: NSScreen, palette: BreakPalette, appearance: NSAppearance.Name) {
        self.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        // Leaving a white default here is what flashed a white frame before a dark
        // overlay drew.
        backgroundColor = NSColor(palette.paper)
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        self.appearance = NSAppearance(named: appearance)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentRect(forFrameRect: frame)
        contentView = hostingView
    }
}

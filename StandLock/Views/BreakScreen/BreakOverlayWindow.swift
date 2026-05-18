import AppKit
import SwiftUI

final class BreakOverlayWindow: NSWindow {
    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .white
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        appearance = NSAppearance(named: .aqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentRect(forFrameRect: frame)
        contentView = hostingView
    }
}

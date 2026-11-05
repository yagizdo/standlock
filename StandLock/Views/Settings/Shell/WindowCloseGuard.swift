import AppKit
import SwiftUI

/// Gives the schedule page a say before the window closes. SwiftUI has no modifier for this below
/// macOS 15, and none that can ask. The scene keeps the window: this only refuses a close.
struct WindowCloseGuard: NSViewRepresentable {
    let navigation: SettingsNavigation

    func makeNSView(context: Context) -> WindowWatcher {
        WindowWatcher(navigation: navigation)
    }

    func updateNSView(_ view: WindowWatcher, context: Context) {}
}

final class WindowWatcher: NSView {
    private let closeDelegate: SettingsWindowDelegate

    init(navigation: SettingsNavigation) {
        closeDelegate = SettingsWindowDelegate(navigation: navigation)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, window.delegate !== closeDelegate else { return }
        closeDelegate.scene = window.delegate
        window.delegate = closeDelegate
    }
}

/// Stands in front of SwiftUI's window delegate and hands it everything else.
final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    let navigation: SettingsNavigation
    weak var scene: NSWindowDelegate?

    init(navigation: SettingsNavigation) {
        self.navigation = navigation
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let allowed = navigation.shouldClose(sender)
        return allowed && scene?.windowShouldClose?(sender) ?? allowed
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || scene?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        scene
    }
}

import AppKit
import ApplicationServices

/// Reports whether macOS shows its Control Center privacy indicator. The indicator
/// appears while an app uses the camera, uses the microphone, or captures the screen,
/// and it does not say which of the three is happening -- Control Center draws all
/// three through a single `audiovideo` menu extra. Callers rule out the camera and the
/// microphone, which are detected directly, to isolate screen capture.
///
/// macOS publishes no API for "another app is capturing the screen": ScreenCaptureKit
/// lists what *can* be captured rather than what is being captured, `CGDisplayIsCaptured`
/// was removed after 10.9, and no process is spawned when a meeting app starts sharing.
/// Reading the indicator through the accessibility API is the one signal that works
/// without asking for Screen Recording access.
public struct PrivacyIndicatorDetector: Sendable {
    private static let controlCenterBundleID = "com.apple.controlcenter"
    private static let audioVideoMenuExtraID = "com.apple.menuextra.audiovideo"

    private let menuExtraIdentifiers: @Sendable () -> [String]

    public init() {
        menuExtraIdentifiers = Self.controlCenterMenuExtraIdentifiers
    }

    init(menuExtraIdentifiers: @escaping @Sendable () -> [String]) {
        self.menuExtraIdentifiers = menuExtraIdentifiers
    }

    /// Without accessibility access the menu extras cannot be read and the indicator
    /// reads as hidden, so the caller sees no screen capture rather than a false one.
    public func isPrivacyIndicatorVisible() -> Bool {
        menuExtraIdentifiers().contains(Self.audioVideoMenuExtraID)
    }

    private static func controlCenterMenuExtraIdentifiers() -> [String] {
        guard AXIsProcessTrusted() else { return [] }
        guard let controlCenter = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == controlCenterBundleID
        }) else { return [] }

        let application = AXUIElementCreateApplication(controlCenter.processIdentifier)
        guard let menuBar = element(of: application, attribute: kAXExtrasMenuBarAttribute),
              let items = copyValue(of: menuBar, attribute: kAXChildrenAttribute) as? [AXUIElement]
        else { return [] }

        return items.compactMap { copyValue(of: $0, attribute: kAXIdentifierAttribute) as? String }
    }

    private static func copyValue(of element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func element(of element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = copyValue(of: element, attribute: attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }
}

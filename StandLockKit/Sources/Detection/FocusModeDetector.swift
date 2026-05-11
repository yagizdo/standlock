import Foundation

public struct FocusModeDetector: Sendable {
    public init() {}

    public func isFocusModeActive() -> Bool {
        let dndPrefs = UserDefaults(suiteName: "com.apple.notificationcenterui")
        return dndPrefs?.bool(forKey: "doNotDisturb") ?? false
    }
}

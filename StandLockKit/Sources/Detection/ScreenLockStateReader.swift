import CoreGraphics

/// Isolates the platform's session dictionary and its non-public lock-state key.
public struct ScreenLockStateReader: Sendable {
    private static let lockedKey = "CGSSessionScreenIsLocked"

    public init() {}

    public func isLocked() -> Bool? {
        Self.isLocked(in: CGSessionCopyCurrentDictionary() as? [String: Any])
    }

    static func isLocked(in session: [String: Any]?) -> Bool? {
        guard let session, !session.isEmpty else { return nil }
        guard let value = session[lockedKey] else { return false }
        return value as? Bool
    }
}

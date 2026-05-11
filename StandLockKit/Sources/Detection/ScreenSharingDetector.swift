public struct ScreenSharingDetector: Sendable {
    public init() {}

    public func isScreenBeingShared() async -> Bool {
        // v1: conservative default. Reliable detection requires Screen Recording
        // permission and monitoring active capture sessions.
        false
    }
}

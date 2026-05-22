import AppKit

public struct ScreenSharingDetector: Sendable {
    public init() {}

    public func isScreenBeingShared() async -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        return apps.contains { app in
            let exe = app.executableURL?.lastPathComponent
            return exe == "ScreensharingAgent" || exe == "screencaptureui"
        }
    }
}

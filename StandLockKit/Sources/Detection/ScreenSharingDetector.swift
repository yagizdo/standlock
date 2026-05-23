import AppKit

public struct ScreenSharingDetector: Sendable {
    private let processNames: @Sendable () -> [String]

    public init() {
        self.processNames = {
            NSWorkspace.shared.runningApplications.compactMap { $0.executableURL?.lastPathComponent }
        }
    }

    init(processNames: @escaping @Sendable () -> [String]) {
        self.processNames = processNames
    }

    public func isScreenBeingShared() async -> Bool {
        processNames().contains { $0 == "ScreensharingAgent" || $0 == "screencaptureui" }
    }
}

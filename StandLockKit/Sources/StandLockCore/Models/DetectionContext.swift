import Foundation

public struct DetectionContext: Sendable {
    public let cameraActive: Bool
    public let microphoneActive: Bool
    public let calendarEventActive: Bool
    public let screenSharingActive: Bool
    public let idleDuration: TimeInterval

    public init(
        cameraActive: Bool = false, microphoneActive: Bool = false,
        calendarEventActive: Bool = false, screenSharingActive: Bool = false,
        idleDuration: TimeInterval = 0
    ) {
        self.cameraActive = cameraActive; self.microphoneActive = microphoneActive
        self.calendarEventActive = calendarEventActive; self.screenSharingActive = screenSharingActive
        self.idleDuration = idleDuration
    }

    public static let clear = DetectionContext()
}

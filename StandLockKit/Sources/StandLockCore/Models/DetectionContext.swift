import Foundation

public struct DetectionContext: Sendable {
    public let cameraActive: Bool
    public let microphoneActive: Bool
    public let calendarEventActive: Bool
    public let screenSharingActive: Bool
    public let focusModeActive: Bool
    public let idleDuration: TimeInterval

    public init(
        cameraActive: Bool = false, microphoneActive: Bool = false,
        calendarEventActive: Bool = false, screenSharingActive: Bool = false,
        focusModeActive: Bool = false, idleDuration: TimeInterval = 0
    ) {
        self.cameraActive = cameraActive; self.microphoneActive = microphoneActive
        self.calendarEventActive = calendarEventActive; self.screenSharingActive = screenSharingActive
        self.focusModeActive = focusModeActive; self.idleDuration = idleDuration
    }

    public var shouldDefer: Bool {
        cameraActive || microphoneActive || calendarEventActive || screenSharingActive
    }

    public var deferralReason: DeferralReason? {
        if cameraActive { return .cameraActive }
        if microphoneActive { return .microphoneActive }
        if calendarEventActive { return .calendarEvent }
        if screenSharingActive { return .screenSharing }
        if focusModeActive { return .focusMode }
        return nil
    }

    public static let clear = DetectionContext()
}

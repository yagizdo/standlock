import Foundation
import StandLockCore

public actor CompositeDetector: ContextDetecting {
    private let _checkCamera: @Sendable () -> Bool
    private let _checkMicrophone: @Sendable () -> Bool
    private let _checkCalendar: @Sendable () -> Bool
    private let _checkPrivacyIndicator: @Sendable () -> Bool
    private let _checkIdle: @Sendable () -> TimeInterval

    public init(
        camera: CameraDetector = CameraDetector(),
        microphone: MicrophoneDetector = MicrophoneDetector(),
        calendar: CalendarDetector = CalendarDetector(),
        privacyIndicator: PrivacyIndicatorDetector = PrivacyIndicatorDetector(),
        idle: IdleDetector = IdleDetector()
    ) {
        _checkCamera = { camera.isCameraActive() }
        _checkMicrophone = { microphone.isMicrophoneActive() }
        _checkCalendar = { calendar.hasActiveEvent() }
        _checkPrivacyIndicator = { privacyIndicator.isPrivacyIndicatorVisible() }
        _checkIdle = { idle.idleDuration() }
    }

    init(
        cameraCheck: @escaping @Sendable () -> Bool,
        microphoneCheck: @escaping @Sendable () -> Bool,
        calendarCheck: @escaping @Sendable () -> Bool,
        privacyIndicatorCheck: @escaping @Sendable () -> Bool,
        idleCheck: @escaping @Sendable () -> TimeInterval
    ) {
        _checkCamera = cameraCheck
        _checkMicrophone = microphoneCheck
        _checkCalendar = calendarCheck
        _checkPrivacyIndicator = privacyIndicatorCheck
        _checkIdle = idleCheck
    }

    public func currentContext() async -> DetectionContext {
        let cameraActive = _checkCamera()
        let microphoneActive = _checkMicrophone()
        // One privacy indicator stands for the camera, the microphone and screen
        // capture alike, so screen capture is what is left of it once the other two
        // are ruled out. A screen shared with the microphone live therefore defers
        // the break as a microphone call rather than as screen sharing.
        let screenSharingActive = _checkPrivacyIndicator() && !cameraActive && !microphoneActive
        return DetectionContext(
            cameraActive: cameraActive,
            microphoneActive: microphoneActive,
            calendarEventActive: _checkCalendar(),
            screenSharingActive: screenSharingActive,
            idleDuration: _checkIdle()
        )
    }
}

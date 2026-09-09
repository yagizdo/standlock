import Foundation
import StandLockCore

public actor CompositeDetector: ContextDetecting {
    private let _checkCamera: @Sendable () -> Bool
    private let _checkMicrophone: @Sendable () -> Bool
    private let _checkCalendar: @Sendable () -> Bool
    private let _checkScreenSharing: @Sendable () async -> Bool
    private let _checkIdle: @Sendable () -> TimeInterval

    public init(
        camera: CameraDetector = CameraDetector(),
        microphone: MicrophoneDetector = MicrophoneDetector(),
        calendar: CalendarDetector = CalendarDetector(),
        screenSharing: ScreenSharingDetector = ScreenSharingDetector(),
        idle: IdleDetector = IdleDetector()
    ) {
        _checkCamera = { camera.isCameraActive() }
        _checkMicrophone = { microphone.isMicrophoneActive() }
        _checkCalendar = { calendar.hasActiveEvent() }
        _checkScreenSharing = { await screenSharing.isScreenBeingShared() }
        _checkIdle = { idle.idleDuration() }
    }

    init(
        cameraCheck: @escaping @Sendable () -> Bool,
        microphoneCheck: @escaping @Sendable () -> Bool,
        calendarCheck: @escaping @Sendable () -> Bool,
        screenSharingCheck: @escaping @Sendable () async -> Bool,
        idleCheck: @escaping @Sendable () -> TimeInterval
    ) {
        _checkCamera = cameraCheck
        _checkMicrophone = microphoneCheck
        _checkCalendar = calendarCheck
        _checkScreenSharing = screenSharingCheck
        _checkIdle = idleCheck
    }

    public func currentContext() async -> DetectionContext {
        DetectionContext(
            cameraActive: _checkCamera(),
            microphoneActive: _checkMicrophone(),
            calendarEventActive: _checkCalendar(),
            screenSharingActive: await _checkScreenSharing(),
            idleDuration: _checkIdle()
        )
    }
}

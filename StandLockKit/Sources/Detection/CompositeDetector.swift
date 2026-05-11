import Foundation
import StandLockCore

public actor CompositeDetector: ContextDetecting {
    private let _checkCamera: @Sendable () -> Bool
    private let _checkMicrophone: @Sendable () -> Bool
    private let _checkCalendar: @Sendable () -> Bool
    private let _checkScreenSharing: @Sendable () async -> Bool
    private let _checkFocusMode: @Sendable () -> Bool
    private let _checkIdle: @Sendable () -> TimeInterval

    public init(
        camera: CameraDetector = CameraDetector(),
        microphone: MicrophoneDetector = MicrophoneDetector(),
        calendar: CalendarDetector = CalendarDetector(),
        screenSharing: ScreenSharingDetector = ScreenSharingDetector(),
        focusMode: FocusModeDetector = FocusModeDetector(),
        idle: IdleDetector = IdleDetector()
    ) {
        _checkCamera = { camera.isCameraActive() }
        _checkMicrophone = { microphone.isMicrophoneActive() }
        _checkCalendar = { calendar.hasActiveEvent() }
        _checkScreenSharing = { await screenSharing.isScreenBeingShared() }
        _checkFocusMode = { focusMode.isFocusModeActive() }
        _checkIdle = { idle.idleDuration() }
    }

    init(
        cameraCheck: @escaping @Sendable () -> Bool,
        microphoneCheck: @escaping @Sendable () -> Bool,
        calendarCheck: @escaping @Sendable () -> Bool,
        screenSharingCheck: @escaping @Sendable () async -> Bool,
        focusModeCheck: @escaping @Sendable () -> Bool,
        idleCheck: @escaping @Sendable () -> TimeInterval
    ) {
        _checkCamera = cameraCheck
        _checkMicrophone = microphoneCheck
        _checkCalendar = calendarCheck
        _checkScreenSharing = screenSharingCheck
        _checkFocusMode = focusModeCheck
        _checkIdle = idleCheck
    }

    public func currentContext() async -> DetectionContext {
        DetectionContext(
            cameraActive: _checkCamera(),
            microphoneActive: _checkMicrophone(),
            calendarEventActive: _checkCalendar(),
            screenSharingActive: await _checkScreenSharing(),
            focusModeActive: _checkFocusMode(),
            idleDuration: _checkIdle()
        )
    }
}

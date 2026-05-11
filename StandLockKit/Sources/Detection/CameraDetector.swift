import AVFoundation

public struct CameraDetector: Sendable {
    public init() {}

    public func isCameraActive() -> Bool {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        return devices.contains { $0.isInUseByAnotherApplication }
    }
}

import AVFoundation

public struct CameraDetector: Sendable {
    public init() {}

    public func isCameraActive() -> Bool {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14, *) {
            deviceTypes.append(.external)
        } else {
            deviceTypes.append(.externalUnknown)
        }
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        ).devices
        return devices.contains { $0.isInUseByAnotherApplication }
    }
}

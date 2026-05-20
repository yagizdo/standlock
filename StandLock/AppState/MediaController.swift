import Foundation

@MainActor
final class MediaController {
    private var didPause = false
    private let sendCommand: (@convention(c) (UInt32, AnyObject?) -> Bool)?

    nonisolated init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ), let sym = dlsym(handle, "MRMediaRemoteSendCommand") else {
            self.sendCommand = nil
            return
        }
        self.sendCommand = unsafeBitCast(
            sym, to: (@convention(c) (UInt32, AnyObject?) -> Bool).self
        )
    }

    func pause() {
        guard let sendCommand else { return }
        _ = sendCommand(1, nil)
        didPause = true
    }

    func resumeIfPaused() {
        defer { didPause = false }
        guard didPause, let sendCommand else { return }
        _ = sendCommand(0, nil)
    }

    func reset() {
        didPause = false
    }
}

import AppKit
import StandLockCore

/// Plays once per cue from the coordinator path, never from `showOverlay`, which reruns on screen
/// changes. `NSSound`, not AudioServices: system sound IDs go silent with UI sound effects off.
final class BreakSoundPlayer {
    /// Nil on a system without the sound: the cue stays silent.
    private let approaching = NSSound(named: "Ping")
    private let ended = NSSound(named: "Glass")

    func play(_ cue: BreakCue) {
        switch cue {
        case .approaching: approaching?.play()
        case .ended: ended?.play()
        }
    }
}

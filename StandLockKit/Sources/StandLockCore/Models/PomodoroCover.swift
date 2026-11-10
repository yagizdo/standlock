import Foundation

/// Which Pomodoro phase the overlay covers. `.breaks` is the classic session; `.focus` covers
/// the screen while the user works away from the Mac and leaves the breaks open.
public enum PomodoroCover: String, Codable, Sendable, CaseIterable {
    case breaks
    case focus
}

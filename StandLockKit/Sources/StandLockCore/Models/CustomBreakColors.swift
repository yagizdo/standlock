import Foundation

/// The neutral break screen slots derived from a user's background and text pair.
/// Accent colours are not here: each discipline level keeps its theme accent.
public struct CustomBreakColors: Equatable, Sendable {
    public let paper: HexColor
    public let paperEdge: HexColor
    public let ink: HexColor
    public let inkSoft: HexColor
    public let inkFaint: HexColor
    public let isDark: Bool

    public init(
        paper: HexColor,
        paperEdge: HexColor,
        ink: HexColor,
        inkSoft: HexColor,
        inkFaint: HexColor,
        isDark: Bool
    ) {
        self.paper = paper
        self.paperEdge = paperEdge
        self.ink = ink
        self.inkSoft = inkSoft
        self.inkFaint = inkFaint
        self.isDark = isDark
    }
}

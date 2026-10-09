import Foundation

/// The neutral break screen slots derived from a user's background and text pair.
/// Accent colours are not here: each discipline level keeps its theme accent.
public struct CustomBreakColors: Equatable, Sendable {
    public let paper: RGBColor
    public let paperEdge: RGBColor
    public let ink: RGBColor
    public let inkSoft: RGBColor
    public let inkFaint: RGBColor
    public let isDark: Bool

    public init(
        paper: RGBColor,
        paperEdge: RGBColor,
        ink: RGBColor,
        inkSoft: RGBColor,
        inkFaint: RGBColor,
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

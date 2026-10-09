import Foundation

/// Break overlay customization. Later break screen options go here as new fields.
public struct BreakScreenPreferences: Codable, Sendable, Equatable {
    /// `"#RRGGBB"`; nil means the theme's colours.
    public var backgroundHex: String?
    /// `"#RRGGBB"`; nil means the theme's colours.
    public var textHex: String?
    public var showsStatistics: Bool
    /// Shown verbatim under the timer when non-empty.
    public var message: String

    public init(
        backgroundHex: String? = nil,
        textHex: String? = nil,
        showsStatistics: Bool = true,
        message: String = ""
    ) {
        self.backgroundHex = backgroundHex
        self.textHex = textHex
        self.showsStatistics = showsStatistics
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case backgroundHex, textHex
        case showsStatistics
        case message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundHex = try c.decodeIfPresent(String.self, forKey: .backgroundHex)
        textHex = try c.decodeIfPresent(String.self, forKey: .textHex)
        showsStatistics = try c.decodeIfPresent(Bool.self, forKey: .showsStatistics) ?? true
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    /// Nil unless both hexes parse. Soft and faint ink sit 20% and 50% toward the paper,
    /// and the paper edge 10% toward black, matching the built-in palettes.
    public var customColors: CustomBreakColors? {
        guard let backgroundHex, let textHex,
              let paper = RGBColor(hex: backgroundHex),
              let ink = RGBColor(hex: textHex) else { return nil }
        return CustomBreakColors(
            paper: paper,
            paperEdge: paper.mixed(with: .black, amount: 0.1),
            ink: ink,
            inkSoft: ink.mixed(with: paper, amount: 0.2),
            inkFaint: ink.mixed(with: paper, amount: 0.5),
            isDark: paper.isDark
        )
    }
}

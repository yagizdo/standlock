import Foundation

/// Formats a colour as `"#RRGGBB"` and parses one typed or pasted back, so a text field
/// can edit a colour directly. Surrounding whitespace is ignored; anything `HexColor(hex:)`
/// rejects throws, which makes a bound text field keep its previous value.
public struct HexColorFormat: ParseableFormatStyle {
    public var parseStrategy: Strategy { Strategy() }

    public init() {}

    public func format(_ value: HexColor) -> String {
        value.hex
    }

    public struct Strategy: ParseStrategy {
        public init() {}

        public func parse(_ value: String) throws -> HexColor {
            guard let color = HexColor(hex: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw CocoaError(.formatting)
            }
            return color
        }
    }
}

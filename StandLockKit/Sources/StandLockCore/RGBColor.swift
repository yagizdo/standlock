import Foundation

/// An opaque sRGB colour with channels in `0...1`, stored as `"#RRGGBB"`.
///
/// Luminance and contrast follow WCAG 2.2:
/// https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
public struct RGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public static let black = RGBColor(red: 0, green: 0, blue: 0)
    public static let white = RGBColor(red: 1, green: 1, blue: 1)

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses `"#RRGGBB"` or `"RRGGBB"`, case-insensitive. Returns `nil` for anything else.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        // `UInt32(_:radix:)` alone accepts a leading "+", so check every character first.
        guard digits.count == 6,
              digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Uppercase `"#RRGGBB"`.
    public var hex: String {
        func byte(_ channel: Double) -> Int {
            min(max(Int((channel * 255).rounded()), 0), 255)
        }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    public var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 (same luminance) to 21 (black on white). Order does not matter.
    public func contrastRatio(with other: RGBColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Linear blend per channel; `amount` is clamped to `0...1` (0 is `self`, 1 is `other`).
    public func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let t = min(max(amount, 0), 1)
        return RGBColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    /// True when white text reads better on this colour than black text.
    public var isDark: Bool {
        contrastRatio(with: .white) > contrastRatio(with: .black)
    }
}

import SwiftUI
import AppKit

enum BreakTypography {
    private static func customOrFallback(_ name: String, size: CGFloat, fallback: Font) -> Font {
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return fallback
    }

    static func timerNumerals(size: CGFloat) -> Font {
        customOrFallback("Newsreader-ExtraLight", size: size,
                         fallback: .system(size: size, weight: .ultraLight, design: .serif))
    }

    static func exerciseName(size: CGFloat = 36) -> Font {
        customOrFallback("Newsreader-Regular", size: size,
                         fallback: .system(size: size, weight: .regular, design: .serif))
    }

    static func exerciseBody() -> Font {
        customOrFallback("Newsreader-Regular", size: 17,
                         fallback: .system(size: 17, weight: .regular, design: .serif))
    }

    static func label(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name = weight == .semibold ? "Inter-SemiBold" : "Inter-Medium"
        return customOrFallback(name, size: size, fallback: .system(size: size, weight: weight))
    }

    static func keycap() -> Font {
        customOrFallback("JetBrainsMono-Medium", size: 12,
                         fallback: .system(size: 12, weight: .medium, design: .monospaced))
    }
}

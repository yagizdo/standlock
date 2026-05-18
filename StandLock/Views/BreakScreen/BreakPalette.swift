import SwiftUI
import StandLockCore

struct BreakPalette {
    let paper: Color
    let paperEdge: Color
    let ink: Color
    let inkSoft: Color
    let inkFaint: Color
    let accent: Color

    static func `for`(_ level: DisciplineLevel) -> BreakPalette {
        switch level {
        case .gentle: .gentle
        case .firm: .firm
        case .strict: .strict
        }
    }

    static let gentle = BreakPalette(
        paper: Color(hex: 0xE0F9E7),
        paperEdge: Color(hex: 0xC6F1D3),
        ink: Color(hex: 0x0F1F14),
        inkSoft: Color(hex: 0x3B4D41),
        inkFaint: Color(hex: 0x7D8A81),
        accent: Color(hex: 0x00793D)
    )

    static let firm = BreakPalette(
        paper: Color(hex: 0xFFEAE2),
        paperEdge: Color(hex: 0xFFD7CA),
        ink: Color(hex: 0x271511),
        inkSoft: Color(hex: 0x57423D),
        inkFaint: Color(hex: 0x92827E),
        accent: Color(hex: 0xA33E25)
    )

    static let strict = BreakPalette(
        paper: Color(hex: 0xE6F2FF),
        paperEdge: Color(hex: 0xD1E5FF),
        ink: Color(hex: 0x141A29),
        inkSoft: Color(hex: 0x404858),
        inkFaint: Color(hex: 0x808693),
        accent: Color(hex: 0x3B5EB2)
    )
}

private extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

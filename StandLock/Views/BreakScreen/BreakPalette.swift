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
        paper: Color(hex: 0xE7ECF1),
        paperEdge: Color(hex: 0xD0D9E2),
        ink: Color(hex: 0x141B24),
        inkSoft: Color(hex: 0x3C4858),
        inkFaint: Color(hex: 0x7B8896),
        accent: Color(hex: 0x5B7D9E)
    )

    static let firm = BreakPalette(
        paper: Color(hex: 0xDDDCE9),
        paperEdge: Color(hex: 0xC0BFCF),
        ink: Color(hex: 0x181622),
        inkSoft: Color(hex: 0x443F58),
        inkFaint: Color(hex: 0x807B91),
        accent: Color(hex: 0x6E6993)
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

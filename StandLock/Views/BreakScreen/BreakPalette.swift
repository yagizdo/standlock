import SwiftUI
import StandLockCore

struct BreakPalette {
    let paper: Color
    let paperEdge: Color
    let ink: Color
    let inkSoft: Color
    let inkFaint: Color
    let accent: Color
    /// The colour a subtle chip fill is drawn in before its opacity is applied:
    /// black on light paper, white on dark. It cannot be derived from the slots
    /// above, which all carry a hue.
    let wash: Color
    /// The colour text takes when it sits on an `accent` fill. Light themes put
    /// white there; dark themes need dark ink, because their accents are light.
    let onAccent: Color

    static let gentle = BreakPalette(
        paper: Color(hex: 0xE7ECF1),
        paperEdge: Color(hex: 0xD0D9E2),
        ink: Color(hex: 0x141B24),
        inkSoft: Color(hex: 0x3C4858),
        inkFaint: Color(hex: 0x7B8896),
        accent: Color(hex: 0x5B7D9E),
        wash: Color(hex: 0x000000),
        onAccent: Color(hex: 0xFFFFFF)
    )

    static let firm = BreakPalette(
        paper: Color(hex: 0xDDDCE9),
        paperEdge: Color(hex: 0xC0BFCF),
        ink: Color(hex: 0x181622),
        inkSoft: Color(hex: 0x443F58),
        inkFaint: Color(hex: 0x807B91),
        accent: Color(hex: 0x6E6993),
        wash: Color(hex: 0x000000),
        onAccent: Color(hex: 0xFFFFFF)
    )

    static let strict = BreakPalette(
        paper: Color(hex: 0xE6F2FF),
        paperEdge: Color(hex: 0xD1E5FF),
        ink: Color(hex: 0x141A29),
        inkSoft: Color(hex: 0x404858),
        inkFaint: Color(hex: 0x808693),
        accent: Color(hex: 0x3B5EB2),
        wash: Color(hex: 0x000000),
        onAccent: Color(hex: 0xFFFFFF)
    )

    // The dark palettes invert the ink/paper relationship rather than dimming the
    // light ones, and keep each level's hue so the discipline stays readable at a
    // glance. `paperEdge` stays darker than `paper`, as it is in the light
    // palettes, so the radial background still reads as a page edge.

    static let gentleDark = BreakPalette(
        paper: Color(hex: 0x151A21),
        paperEdge: Color(hex: 0x0E1218),
        ink: Color(hex: 0xE4EAF1),
        inkSoft: Color(hex: 0xB3BECB),
        inkFaint: Color(hex: 0x7F8A98),
        accent: Color(hex: 0x7FA3C6),
        wash: Color(hex: 0xFFFFFF),
        onAccent: Color(hex: 0x101419)
    )

    static let firmDark = BreakPalette(
        paper: Color(hex: 0x171620),
        paperEdge: Color(hex: 0x100F17),
        ink: Color(hex: 0xE6E3F0),
        inkSoft: Color(hex: 0xBAB5C9),
        inkFaint: Color(hex: 0x857F96),
        accent: Color(hex: 0x9A93C4),
        wash: Color(hex: 0xFFFFFF),
        onAccent: Color(hex: 0x121017)
    )

    static let strictDark = BreakPalette(
        paper: Color(hex: 0x131826),
        paperEdge: Color(hex: 0x0C101B),
        ink: Color(hex: 0xDFE7F5),
        inkSoft: Color(hex: 0xAEB9CC),
        inkFaint: Color(hex: 0x7C8699),
        accent: Color(hex: 0x6E8FE0),
        wash: Color(hex: 0xFFFFFF),
        onAccent: Color(hex: 0x0E1220)
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

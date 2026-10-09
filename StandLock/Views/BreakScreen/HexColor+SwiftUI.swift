import AppKit
import SwiftUI
import StandLockCore

extension Color {
    init(_ rgb: HexColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

extension HexColor {
    /// Nil when the colour cannot be converted to sRGB. Channels are read only from the
    /// converted colour: reading them from another colour space raises an exception.
    init?(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
    }
}

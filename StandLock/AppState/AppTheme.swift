import AppKit
import SwiftUI
import StandLockCore

/// A theme the app can render in: the AppKit appearance every window adopts, the
/// SwiftUI colour scheme the break overlay forces, and one break palette per
/// discipline level.
///
/// Themes are values identified by `id`, not enum cases. Adding one is a new static
/// plus an entry in `all` and its catalog keys -- no persisted value changes meaning
/// and no `switch` has to be found and widened.
struct AppTheme: Identifiable, Equatable {
    let id: String
    /// The string-catalog key for this theme's name in the Appearance picker.
    let nameKey: String
    let colorScheme: ColorScheme
    let appearance: NSAppearance.Name

    private let gentle: BreakPalette
    private let firm: BreakPalette
    private let strict: BreakPalette

    func palette(for level: DisciplineLevel) -> BreakPalette {
        switch level {
        case .gentle: gentle
        case .firm: firm
        case .strict: strict
        }
    }

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }

    // `"light"` and `"dark"` are the same ids `resolveTheme` falls back to as its
    // system defaults. Renaming one here means renaming it there.
    static let light = AppTheme(
        id: "light", nameKey: "Light",
        colorScheme: .light, appearance: .aqua,
        gentle: .gentle, firm: .firm, strict: .strict
    )

    static let dark = AppTheme(
        id: "dark", nameKey: "Dark",
        colorScheme: .dark, appearance: .darkAqua,
        gentle: .gentleDark, firm: .firmDark, strict: .strictDark
    )

    static let all: [AppTheme] = [.light, .dark]

    /// - Returns: the theme with this id, or `.light` when the id is unknown.
    ///   `resolveTheme` already filters unknown ids; this fallback is the guard for
    ///   a caller that did not go through it.
    static func named(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? .light
    }
}

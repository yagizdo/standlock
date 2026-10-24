import AppKit
import SwiftUI
import StandLockCore

/// The colours, colour scheme and window appearance one break overlay renders with,
/// resolved once so the window and the view cannot disagree.
struct BreakScreenLook {
    let palette: BreakPalette
    let colorScheme: ColorScheme
    let appearance: NSAppearance.Name

    /// - Returns: the theme's own look when no custom colours are set. Otherwise the
    ///   custom pair with the level's accent from the light or dark theme, whichever
    ///   matches the custom background, so system controls draw in the matching mode.
    static func resolve(
        theme: AppTheme, level: DisciplineLevel, breakScreen: BreakScreenPreferences
    ) -> BreakScreenLook {
        guard let custom = breakScreen.customColors else {
            return BreakScreenLook(
                palette: theme.palette(for: level),
                colorScheme: theme.colorScheme,
                appearance: theme.appearance
            )
        }
        let base = custom.isDark ? AppTheme.dark : AppTheme.light
        let basePalette = base.palette(for: level)
        return BreakScreenLook(
            palette: BreakPalette(
                paper: Color(custom.paper),
                paperEdge: Color(custom.paperEdge),
                ink: Color(custom.ink),
                inkSoft: Color(custom.inkSoft),
                inkFaint: Color(custom.inkFaint),
                accent: basePalette.accent,
                wash: basePalette.wash,
                onAccent: basePalette.onAccent
            ),
            colorScheme: base.colorScheme,
            appearance: base.appearance
        )
    }
}

import AppKit
import SwiftUI
import StandLockCore

/// Owns the app's appearance choice and puts it into force.
///
/// The selection is kept outside the `preferences` blob, like `hasCompletedOnboarding`
/// and the language choice, so an older build simply ignores the key. It is a theme id
/// rather than a two-case value, which is what lets a third theme ship without
/// migrating anything.
@MainActor
final class ThemeStore: ObservableObject {
    private static let selectionKey = "appTheme"

    /// The user's explicit choice, or `nil` to follow the Mac.
    @Published private(set) var selection: String?

    /// Themes the app ships. The Appearance picker builds its rows from this, so a
    /// new theme reaches the UI with no change there.
    let available: [AppTheme] = AppTheme.all

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selection = defaults.string(forKey: Self.selectionKey)
    }

    /// The theme to render in right now.
    ///
    /// Computed rather than stored: the only input that can change without going
    /// through `select` is the Mac's own appearance, and reading it here means the
    /// next break picks it up without this store subscribing to anything.
    var current: AppTheme {
        AppTheme.named(resolveTheme(
            selection: selection,
            available: available.map(\.id),
            systemPrefersDark: Self.systemPrefersDark()
        ))
    }

    /// - Parameter id: a theme the app ships, or `nil` to follow the Mac.
    func select(_ id: String?) {
        selection = id
        if let id {
            defaults.set(id, forKey: Self.selectionKey)
        } else {
            defaults.removeObject(forKey: Self.selectionKey)
        }
        applyAppearance()
    }

    /// Assigning `nil` is what makes every AppKit window follow the Mac's appearance
    /// live, which is why this store needs no notification observer: Settings, the
    /// menu bar panel and onboarding are drawn with system colours and follow along
    /// on their own.
    ///
    /// The test is whether the stored id resolves, not whether one is present, so an
    /// id left behind by a build that shipped a theme this one does not goes back to
    /// following the Mac rather than pinning whatever `current` fell back to.
    func applyAppearance() {
        let isExplicit = selection.map { id in available.contains { $0.id == id } } ?? false
        NSApp.appearance = isExplicit ? NSAppearance(named: current.appearance) : nil
    }

    /// Read on every `current` read, since it is an eager argument to `resolveTheme`,
    /// but only used when the selection does not resolve. That is exactly the case
    /// where `applyAppearance` has left `NSApp.appearance` unset, so
    /// `effectiveAppearance` reports the Mac's own appearance rather than one we forced.
    private static func systemPrefersDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

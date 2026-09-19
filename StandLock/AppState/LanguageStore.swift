import Foundation
import StandLockCore

/// Owns the app's language choice and the locale every SwiftUI root renders in.
///
/// The selection is kept outside the `preferences` blob, like `hasCompletedOnboarding`,
/// so an older build simply ignores the key.
@MainActor
final class LanguageStore: ObservableObject {
    private static let selectionKey = "appLanguage"
    /// Not API. Writing it is what makes AppKit menus and Sparkle follow the choice on
    /// the next launch; the in-app UI switches immediately through `locale`.
    private static let appleLanguagesKey = "AppleLanguages"

    @Published private(set) var locale: Locale
    private(set) var selection: String?

    /// Language codes the app ships, e.g. `["en", "tr"]`. Grows when a catalog gains a
    /// column, so a new language reaches the picker with no Swift change.
    let available: [String]

    private let defaults: UserDefaults
    /// Read once at init. `select` writes the app's own `AppleLanguages`, so re-reading it
    /// later would only ever hand back the app's last explicit choice.
    private let systemPreferred: [String]

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.available = bundle.localizations.filter { $0 != "Base" }.sorted()
        self.selection = defaults.string(forKey: Self.selectionKey)

        // The macOS-wide list, not the app's own domain. `Bundle.main.preferredLocalizations`
        // is already filtered by the app's `AppleLanguages` key, so after one explicit
        // choice and a relaunch "System" could never reach the real Mac language again.
        let global = defaults.persistentDomain(forName: UserDefaults.globalDomain)?[Self.appleLanguagesKey] as? [String]
        self.systemPreferred = global ?? Locale.preferredLanguages

        self.locale = Locale(identifier: resolveLanguage(
            selection: selection,
            available: available,
            systemPreferred: systemPreferred
        ))
    }

    /// - Parameter code: a language code the app ships, or `nil` to follow the system.
    func select(_ code: String?) {
        selection = code
        if let code {
            defaults.set(code, forKey: Self.selectionKey)
        } else {
            defaults.removeObject(forKey: Self.selectionKey)
        }

        let resolved = resolveLanguage(
            selection: code,
            available: available,
            systemPreferred: systemPreferred
        )
        locale = Locale(identifier: resolved)

        if code == nil {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        } else {
            defaults.set([resolved], forKey: Self.appleLanguagesKey)
        }
    }

    /// Resolves a catalog entry in the selected language.
    ///
    /// For anything a `Text` renders whole, prefer `Text(LocalizedStringKey(...))` and let
    /// the environment locale do the work. This exists for the few places that compose or
    /// transform the result -- an `NSMenuItem` title, an uppercased pill, a concatenation.
    func string(_ resource: LocalizedStringResource) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }

    /// Resolves a key held in a variable, such as a string that came from the Kit.
    /// An unknown key resolves to itself.
    func string(key: String) -> String {
        string(LocalizedStringResource(String.LocalizationValue(key)))
    }

    /// The language's own name for itself, e.g. `"tr"` -> "Türkçe".
    ///
    /// Resolved from the whole identifier rather than its language code, so a script
    /// tag survives: `zh-Hans` reads 简体中文, where `localizedString(forLanguageCode:)`
    /// answers a bare 中文 for every Chinese variant alike. Latin-script languages
    /// are unaffected -- both calls return "Türkçe" and "English".
    func displayName(for code: String) -> String {
        let locale = Locale(identifier: code)
        let name = locale.localizedString(forIdentifier: code)
            ?? locale.localizedString(forLanguageCode: code)
        guard let name, let first = name.first else { return code }
        return String(first).uppercased(with: locale) + name.dropFirst()
    }
}

import Foundation

/// What the user types before Settings resets the app. The app name reads the same in every
/// language, so it needs no translation, and with no `i` in it Turkish case folding cannot
/// get in the way.
public enum ResetConfirmation {
    public static let phrase = "StandLock"

    public static func matches(_ input: String) -> Bool {
        phraseMatches(input, expected: phrase, locale: Locale(identifier: "en_US_POSIX"))
    }
}

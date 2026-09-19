import Foundation

/// Compares typed input against an expected escape phrase.
///
/// Surrounding whitespace is trimmed and the comparison is case-insensitive under
/// `locale`, so Turkish pairs ı/I and i/İ while leaving i/I distinct. Diacritics are
/// never folded: ş and s, ğ and g, ç and c stay different letters.
public func phraseMatches(_ input: String, expected: String, locale: Locale) -> Bool {
    input
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .compare(expected, options: [.caseInsensitive], range: nil, locale: locale) == .orderedSame
}

/// The largest jump in character count a phrase field accepts in one change.
///
/// Four covers an input method commit -- Pinyin turns `nihao` into 你好 in a single
/// update, and a committed word runs to about four characters -- while staying well
/// under the shortest escape phrase the app ships, 反正我更喜欢坐着 at eight.
private let maxPhraseInputJump = 4

/// Whether a break screen should accept a change to its phrase field, or revert it.
///
/// The break screens reject input that arrives faster than a person types, so the
/// escape phrase cannot be pasted off the screen the user is reading it from.
/// Counting one character per change is the wrong test: SwiftUI's `TextField`
/// binding never sees an input method's marked text, only the commit, so every
/// Chinese, Japanese, or Korean word arrives as a single multi-character jump and
/// was rejected outright -- leaving the phrase impossible to type and the user
/// locked inside the break.
///
/// Growth past `maxPhraseInputJump` characters is still a paste. Shrinking is always
/// the user deleting.
public func acceptsPhraseInput(previous: String, new: String) -> Bool {
    new.count - previous.count <= maxPhraseInputJump
}

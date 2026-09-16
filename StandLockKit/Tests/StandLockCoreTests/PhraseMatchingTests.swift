import Foundation
import Testing
@testable import StandLockCore

@Suite("Phrase Matching")
struct PhraseMatchingTests {

    let tr = Locale(identifier: "tr")
    let en = Locale(identifier: "en")
    let zh = Locale(identifier: "zh-Hans")

    @Test func turkishUppercasePhraseMatches() {
        #expect(phraseMatches(
            "BU MOLAYI ATLAMAYI SEÇİYORUM",
            expected: "Bu molayı atlamayı seçiyorum",
            locale: tr
        ))
    }

    @Test func turkishDottedAndDotlessArePairedCorrectly() {
        #expect(phraseMatches("ı", expected: "I", locale: tr))
        #expect(phraseMatches("i", expected: "İ", locale: tr))
    }

    @Test func turkishPlainIAndCapitalIAreNotAPair() {
        #expect(!phraseMatches("i", expected: "I", locale: tr))
    }

    @Test func englishLocaleDoesNotPairDotlessI() {
        #expect(!phraseMatches("ı", expected: "I", locale: en))
    }

    @Test func diacriticsNeverFold() {
        #expect(!phraseMatches("seciyorum", expected: "seçiyorum", locale: tr))
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect(phraseMatches(
            "  I choose to skip this break ",
            expected: "I choose to skip this break",
            locale: en
        ))
    }

    @Test func partialInputDoesNotMatch() {
        #expect(!phraseMatches("i choose to skip", expected: "I choose to skip this break", locale: en))
    }

    @Test func chinesePhraseMatchesItself() {
        #expect(phraseMatches("反正我更喜欢坐着", expected: "反正我更喜欢坐着", locale: zh))
    }

    @Test func chineseSurroundingWhitespaceIsTrimmed() {
        #expect(phraseMatches("  反正我更喜欢坐着 ", expected: "反正我更喜欢坐着", locale: zh))
    }

    /// Why the Simplified Chinese escape phrases carry no punctuation. The user
    /// retypes these, and an input method may render a sentence-final stop as a
    /// half-width `.`, or the user may simply leave it off. Either way the
    /// comparison fails and the break cannot be dismissed, so the phrases are
    /// written without punctuation rather than relying on the user reproducing it.
    @Test func chineseTrailingPunctuationBreaksTheMatch() {
        #expect(!phraseMatches("反正我更喜欢坐着。", expected: "反正我更喜欢坐着", locale: zh))
        #expect(!phraseMatches("反正我更喜欢坐着.", expected: "反正我更喜欢坐着", locale: zh))
    }

    /// Regression evidence: the locale-free comparison this matcher replaces fails
    /// on a Turkish phrase, which is why `phraseMatches` exists.
    @Test func caseInsensitiveCompareFailsOnTurkish() {
        #expect("BU MOLAYI ATLAMAYI SEÇİYORUM"
            .caseInsensitiveCompare("Bu molayı atlamayı seçiyorum") != .orderedSame)
    }
}

@Suite("Phrase Input Acceptance")
struct PhraseInputAcceptanceTests {

    @Test func oneNewCharacterIsAccepted() {
        #expect(acceptsPhraseInput(previous: "I choose", new: "I choose "))
    }

    @Test func deletingIsAccepted() {
        #expect(acceptsPhraseInput(previous: "I choose to skip", new: "I choose"))
        #expect(acceptsPhraseInput(previous: "你好吗", new: ""))
    }

    /// The bug this function exists to fix. SwiftUI's `TextField` binding never sees
    /// an input method's marked text, only the commit, so Pinyin turns `nihao` into
    /// 你好 in a single two-character update. The old rule -- reject any growth past
    /// one character -- reverted that, which left every Chinese escape phrase
    /// impossible to type and locked the user inside the break.
    @Test func inputMethodCommitIsAccepted() {
        #expect(acceptsPhraseInput(previous: "", new: "你好"))
        #expect(acceptsPhraseInput(previous: "我的", new: "我的腿是装"))
    }

    @Test func pastedChinesePhraseIsRejected() {
        #expect(!acceptsPhraseInput(previous: "", new: "反正我更喜欢坐着"))
    }

    @Test func pastedEnglishPhraseIsRejected() {
        #expect(!acceptsPhraseInput(previous: "", new: "I choose to skip this break"))
    }

    /// The boundary is load-bearing in both directions: a normal input method commit
    /// has to fit under it, and the shortest escape phrase the app ships in any
    /// language -- 反正我更喜欢坐着, eight characters -- has to sit above it.
    @Test func theJumpBoundaryIsFourCharacters() {
        #expect(acceptsPhraseInput(previous: "", new: "我的腿是"))
        #expect(!acceptsPhraseInput(previous: "", new: "我的腿是装"))
    }
}

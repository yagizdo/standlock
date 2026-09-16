import Foundation
import Testing
@testable import StandLockCore

@Suite("Language Resolution")
struct LanguageResolutionTests {

    @Test func explicitSelectionWins() {
        #expect(resolveLanguage(selection: "tr", available: ["en", "tr"], systemPreferred: ["en"]) == "tr")
    }

    @Test func unavailableSelectionFallsBackToSystem() {
        #expect(resolveLanguage(selection: "de", available: ["en", "tr"], systemPreferred: ["tr"]) == "tr")
    }

    @Test func systemRegionTagMatchesByLanguageCode() {
        #expect(resolveLanguage(selection: nil, available: ["en", "tr"], systemPreferred: ["tr-TR", "en"]) == "tr")
    }

    @Test func noSystemMatchFallsBackToEnglish() {
        #expect(resolveLanguage(selection: nil, available: ["en", "tr"], systemPreferred: ["ja", "fr"]) == "en")
    }

    @Test func emptyAvailableFallsBackToEnglish() {
        #expect(resolveLanguage(selection: nil, available: [], systemPreferred: ["tr"]) == "en")
    }

    @Test func selectionWithRegionTagMatchesByLanguageCode() {
        #expect(resolveLanguage(selection: "tr-TR", available: ["en", "tr"], systemPreferred: ["en"]) == "tr")
    }

    @Test func scriptTaggedSelectionResolves() {
        #expect(resolveLanguage(
            selection: "zh-Hans",
            available: ["en", "tr", "zh-Hans"],
            systemPreferred: []
        ) == "zh-Hans")
    }

    @Test func chineseSystemPreferenceResolves() {
        #expect(resolveLanguage(
            selection: nil,
            available: ["en", "tr", "zh-Hans"],
            systemPreferred: ["zh-Hans-CN"]
        ) == "zh-Hans")
    }

    /// The matcher truncates at the first separator, so a script tag does not
    /// survive it and both Chinese variants land on the one column the app ships.
    /// That is why Traditional Chinese is out of scope rather than a second entry:
    /// adding `zh-Hant` here would make the winner depend on array order, not on
    /// what the reader asked for.
    @Test func traditionalChineseFallsThroughToSimplified() {
        #expect(resolveLanguage(
            selection: nil,
            available: ["en", "tr", "zh-Hans"],
            systemPreferred: ["zh-Hant-TW"]
        ) == "zh-Hans")
    }
}

import Testing
@testable import StandLockCore

struct SettingsSearchTests {
    @Test func findsASubstringInsideATerm() {
        #expect(settingsSearchMatches(query: "startup", terms: ["Launch at Startup"]))
    }

    @Test func looksInEveryTerm() {
        #expect(settingsSearchMatches(query: "pause", terms: ["Look", "Content", "Pause Media"]))
    }

    @Test func ignoresCase() {
        #expect(settingsSearchMatches(query: "LAUNCH", terms: ["Launch at Startup"]))
        #expect(settingsSearchMatches(query: "launch", terms: ["LAUNCH AT STARTUP"]))
    }

    @Test func ignoresDiacritics() {
        #expect(settingsSearchMatches(query: "gorunum", terms: ["Görünüm"]))
        #expect(settingsSearchMatches(query: "Görünüm", terms: ["gorunum"]))
        #expect(settingsSearchMatches(query: "baslangic", terms: ["Başlangıç"]))
    }

    /// `tr` folding lowers `İ` to `ı`, so a locale-aware match cannot find `İ` from a plain `i`.
    @Test(arguments: ["istatistik", "ISTATISTIK", "İSTATİSTİK", "ıstatıstık"])
    func treatsDottedCapitalIAsI(query: String) {
        #expect(settingsSearchMatches(query: query, terms: ["İstatistikler"]))
    }

    @Test func treatsDotlessIAsI() {
        #expect(settingsSearchMatches(query: "kisayol", terms: ["Kısayol"]))
        #expect(settingsSearchMatches(query: "ekrani", terms: ["Mola Ekranı"]))
        #expect(settingsSearchMatches(query: "EKRANI", terms: ["Mola Ekranı"]))
        #expect(settingsSearchMatches(query: "isik", terms: ["Işık"]))
    }

    @Test func treatsEnglishIAlike() {
        #expect(settingsSearchMatches(query: "I", terms: ["i"]))
        #expect(settingsSearchMatches(query: "i", terms: ["I"]))
    }

    @Test func findsChineseTerms() {
        #expect(settingsSearchMatches(query: "统计", terms: ["统计信息"]))
        #expect(!settingsSearchMatches(query: "设置", terms: ["统计信息"]))
    }

    @Test(arguments: ["", " ", "  \n"])
    func emptyQueryMatchesEverything(query: String) {
        #expect(settingsSearchMatches(query: query, terms: ["General"]))
        #expect(settingsSearchMatches(query: query, terms: []))
    }

    @Test func ignoresSpacesAroundTheQuery() {
        #expect(settingsSearchMatches(query: "  menu bar ", terms: ["Menu Bar"]))
    }

    @Test func keepsSpacesInsideTheQuery() {
        #expect(!settingsSearchMatches(query: "menu  bar", terms: ["Menu Bar"]))
    }

    @Test func noMatch() {
        #expect(!settingsSearchMatches(query: "zzz", terms: ["General", "Startup"]))
    }

    @Test func noTermsNoMatch() {
        #expect(!settingsSearchMatches(query: "general", terms: []))
    }
}

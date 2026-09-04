import Testing
@testable import Detection

@Suite("PrivacyIndicatorDetector Tests")
struct PrivacyIndicatorDetectorTests {
    private let staticMenuExtras = [
        "com.apple.menuextra.clock",
        "com.apple.menuextra.controlcenter",
        "com.apple.menuextra.wifi",
        "com.apple.menuextra.battery",
        "com.apple.menuextra.bluetooth",
        "com.apple.menuextra.focusmode",
    ]

    @Test func reportsHiddenWhenOnlyStaticMenuExtrasArePresent() {
        let detector = PrivacyIndicatorDetector(menuExtraIdentifiers: { self.staticMenuExtras })
        #expect(!detector.isPrivacyIndicatorVisible())
    }

    @Test func reportsVisibleWhenAudioVideoMenuExtraAppears() {
        let detector = PrivacyIndicatorDetector(
            menuExtraIdentifiers: { self.staticMenuExtras + ["com.apple.menuextra.audiovideo"] }
        )
        #expect(detector.isPrivacyIndicatorVisible())
    }

    /// Other menu extras come and go on their own -- a running timer or a playing
    /// track adds one -- and none of them mean the screen is being captured.
    @Test func ignoresOtherDynamicMenuExtras() {
        let detector = PrivacyIndicatorDetector(
            menuExtraIdentifiers: {
                self.staticMenuExtras + ["com.apple.menuextra.timer", "com.apple.menuextra.now-playing"]
            }
        )
        #expect(!detector.isPrivacyIndicatorVisible())
    }

    /// Reading the menu extras needs accessibility access; without it the list comes
    /// back empty and the detector must not claim the screen is being captured.
    @Test func reportsHiddenWhenMenuExtrasCannotBeRead() {
        let detector = PrivacyIndicatorDetector(menuExtraIdentifiers: { [] })
        #expect(!detector.isPrivacyIndicatorVisible())
    }
}

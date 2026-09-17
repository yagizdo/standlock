import Foundation
import Testing
@testable import StandLockCore

@Suite("Theme Resolution")
struct ThemeResolutionTests {

    @Test func explicitSelectionWins() {
        #expect(resolveTheme(selection: "light", available: ["light", "dark"], systemPrefersDark: true) == "light")
    }

    @Test func unknownSelectionFallsBackToSystem() {
        #expect(resolveTheme(selection: "solarized", available: ["light", "dark"], systemPrefersDark: true) == "dark")
    }

    @Test func nilSelectionFollowsSystemDark() {
        #expect(resolveTheme(selection: nil, available: ["light", "dark"], systemPrefersDark: true) == "dark")
    }

    @Test func nilSelectionFollowsSystemLight() {
        #expect(resolveTheme(selection: nil, available: ["light", "dark"], systemPrefersDark: false) == "light")
    }

    @Test func emptyAvailableFallsBackToLight() {
        #expect(resolveTheme(selection: nil, available: [], systemPrefersDark: true) == "light")
    }

    @Test func missingSystemDefaultFallsBackToFirstAvailable() {
        #expect(resolveTheme(selection: nil, available: ["solarized"], systemPrefersDark: true) == "solarized")
    }
}

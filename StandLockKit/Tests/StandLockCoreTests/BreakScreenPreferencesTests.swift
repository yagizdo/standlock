import Foundation
import Testing
@testable import StandLockCore

@Suite("BreakScreenPreferences")
struct BreakScreenPreferencesTests {

    @Test func defaultsLeaveTheBreakScreenUnchanged() {
        let screen = AppPreferences().breakScreen
        #expect(screen == BreakScreenPreferences())
        #expect(screen.backgroundHex == nil)
        #expect(screen.textHex == nil)
        #expect(screen.showsStatistics)
        #expect(screen.message.isEmpty)
        #expect(screen.customColors == nil)
    }

    @Test func roundTripsInsideAppPreferences() throws {
        let prefs = AppPreferences(breakScreen: BreakScreenPreferences(
            backgroundHex: "#102030",
            textHex: "#F0E0D0",
            showsStatistics: false,
            message: "Drink water"
        ))
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded == prefs)
    }

    @Test func decodesEmptyJSONToDefaults() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(decoded.breakScreen == BreakScreenPreferences())
    }

    @Test func decodesPartialBreakScreen() throws {
        let json = #"{"breakScreen": {"message": "Drink water"}}"#
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))
        #expect(decoded.breakScreen.message == "Drink water")
        #expect(decoded.breakScreen.showsStatistics)
        #expect(decoded.breakScreen.backgroundHex == nil)
        #expect(decoded.breakScreen.textHex == nil)
    }

    @Test func displayMessageTrimsWhitespace() {
        #expect(BreakScreenPreferences(message: "  Drink water \n").displayMessage == "Drink water")
        #expect(BreakScreenPreferences(message: " \n ").displayMessage.isEmpty)
    }

    @Test func customColorsNeedBothValidHexes() {
        #expect(BreakScreenPreferences(backgroundHex: "#102030").customColors == nil)
        #expect(BreakScreenPreferences(backgroundHex: "#ZZZZZZ", textHex: "#F0E0D0").customColors == nil)
    }

    @Test func customColorsDeriveSlots() throws {
        let light = try #require(BreakScreenPreferences(backgroundHex: "#FFFFFF", textHex: "#000000").customColors)
        #expect(light.paper == .white)
        #expect(light.ink == .black)
        #expect(light.inkSoft == HexColor.black.mixed(with: .white, amount: 0.2))
        #expect(light.inkFaint == HexColor.black.mixed(with: .white, amount: 0.5))
        #expect(light.paperEdge == HexColor.white.mixed(with: .black, amount: 0.1))
        #expect(light.isDark == false)

        let dark = try #require(BreakScreenPreferences(backgroundHex: "#000000", textHex: "#FFFFFF").customColors)
        #expect(dark.isDark == true)
    }
}

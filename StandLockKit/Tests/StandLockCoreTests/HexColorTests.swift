import Foundation
import Testing
@testable import StandLockCore

@Suite("HexColor")
struct HexColorTests {

    @Test func parsesHexWithAndWithoutHash() throws {
        for input in ["#FF8000", "ff8000"] {
            let color = try #require(HexColor(hex: input))
            #expect(abs(color.red - 1) < 0.0001)
            #expect(abs(color.green - 128.0 / 255.0) < 0.0001)
            #expect(abs(color.blue - 0) < 0.0001)
        }
    }

    @Test func rejectsMalformedHex() {
        for input in ["", "#FFF", "#GGGGGG", "#FF80001", "+FFFFF", "#+FFFFF"] {
            #expect(HexColor(hex: input) == nil, "\(input) should not parse")
        }
    }

    @Test func hexRoundTripsUppercase() {
        #expect(HexColor(hex: "#1a2b3c")?.hex == "#1A2B3C")
    }

    @Test func luminanceOfReferenceColors() throws {
        #expect(abs(HexColor.white.relativeLuminance - 1) < 0.0005)
        #expect(abs(HexColor.black.relativeLuminance - 0) < 0.0005)
        let grey = try #require(HexColor(hex: "#808080"))
        #expect(abs(grey.relativeLuminance - 0.2159) < 0.0005)
    }

    @Test func contrastBlackOnWhiteIs21() {
        #expect(abs(HexColor.black.contrastRatio(with: .white) - 21) < 0.001)
        #expect(abs(HexColor.white.contrastRatio(with: .black) - 21) < 0.001)
    }

    @Test func contrastWithSelfIs1() throws {
        let color = try #require(HexColor(hex: "#5B7D9E"))
        #expect(abs(color.contrastRatio(with: color) - 1) < 0.0001)
    }

    @Test func grey777OnWhiteFallsJustBelowAA() throws {
        let grey = try #require(HexColor(hex: "#777777"))
        let ratio = grey.contrastRatio(with: .white)
        #expect(abs(ratio - 4.48) < 0.01)
        #expect(ratio < 4.5)
    }

    @Test func mixedInterpolatesComponents() {
        #expect(HexColor.black.mixed(with: .white, amount: 0) == .black)
        #expect(HexColor.black.mixed(with: .white, amount: 1) == .white)

        let half = HexColor.black.mixed(with: .white, amount: 0.5)
        #expect(abs(half.red - 0.5) < 0.0001)
        #expect(abs(half.green - 0.5) < 0.0001)
        #expect(abs(half.blue - 0.5) < 0.0001)

        #expect(HexColor.black.mixed(with: .white, amount: -0.5) == .black)
        #expect(HexColor.black.mixed(with: .white, amount: 1.5) == .white)
    }

    @Test func isDarkFollowsContrast() throws {
        for hex in ["#151A21", "#333333"] {
            #expect(try #require(HexColor(hex: hex)).isDark, "\(hex) should be dark")
        }
        for hex in ["#E7ECF1", "#EEEEEE"] {
            #expect(try !#require(HexColor(hex: hex)).isDark, "\(hex) should be light")
        }
        #expect(HexColor.black.isDark)
        #expect(!HexColor.white.isDark)
    }
}

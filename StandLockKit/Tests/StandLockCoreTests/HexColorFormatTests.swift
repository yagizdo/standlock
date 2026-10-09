import Foundation
import Testing
@testable import StandLockCore

@Suite("HexColorFormat")
struct HexColorFormatTests {

    @Test func formatsAsUppercaseHex() throws {
        let color = try #require(HexColor(hex: "#1a2b3c"))
        #expect(HexColorFormat().format(color) == "#1A2B3C")
    }

    @Test func parsesTypedOrPastedHex() throws {
        let strategy = HexColorFormat().parseStrategy
        let expected = try #require(HexColor(hex: "#FF8000"))
        for input in ["#ff8000", "FF8000", "  #FF8000 \n"] {
            #expect(try strategy.parse(input) == expected)
        }
    }

    @Test func rejectsMalformedHex() {
        let strategy = HexColorFormat().parseStrategy
        for input in ["", "#FFF", "orange", "#GGGGGG"] {
            #expect(throws: (any Error).self) { try strategy.parse(input) }
        }
    }
}

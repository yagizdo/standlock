import Testing
@testable import StandLockCore

@Suite("Pixel Grid Tests")
struct PixelGridTests {

    private let sprite = PixelSprite(["A.", ".B"], palette: ["A": 0xAA0000, "B": 0x0000BB])

    @Test func aStampKeepsTheBackgroundUnderTransparentPixels() {
        var grid = PixelGrid(width: 3, height: 2) { _, _ in 0x111111 }
        grid.stamp(sprite, x: 1, y: 0)

        #expect(grid[x: 0, y: 0] == 0x111111)
        #expect(grid[x: 1, y: 0] == 0xAA0000)
        #expect(grid[x: 2, y: 0] == 0x111111)
        #expect(grid[x: 1, y: 1] == 0x111111)
        #expect(grid[x: 2, y: 1] == 0x0000BB)
    }

    @Test func aSpriteHangingOverAnyEdgeDrawsOnlyItsInsidePart() {
        var grid = PixelGrid(width: 2, height: 2)
        grid.stamp(sprite, x: -1, y: -1)
        grid.stamp(sprite, x: 1, y: 1)

        #expect(grid[x: 0, y: 0] == 0x0000BB)
        #expect(grid[x: 1, y: 1] == 0xAA0000)
        #expect(grid[x: 1, y: 0] == nil)
        #expect(grid[x: 0, y: 1] == nil)
    }

    @Test func runsJoinOneColourAlongARowAndSkipTransparentPixels() {
        var grid = PixelGrid(width: 5, height: 2) { x, y in y == 0 && x < 3 ? 0x111111 : nil }
        grid.stamp(PixelSprite(["AA"], palette: ["A": 0xAA0000]), x: 3, y: 1)

        #expect(grid.runs == [
            PixelRun(x: 0, y: 0, length: 3, color: 0x111111),
            PixelRun(x: 3, y: 1, length: 2, color: 0xAA0000),
        ])
    }

    @Test func aRunEndsWhereTheColourChanges() {
        let grid = PixelGrid(width: 4, height: 1) { x, _ in x < 2 ? 0x111111 : 0x222222 }

        #expect(grid.runs == [
            PixelRun(x: 0, y: 0, length: 2, color: 0x111111),
            PixelRun(x: 2, y: 0, length: 2, color: 0x222222),
        ])
    }
}

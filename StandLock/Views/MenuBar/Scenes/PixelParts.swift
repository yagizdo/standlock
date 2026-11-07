import Foundation
import StandLockCore

/// Sprites and motion that more than one pixel scene draws: sky, sleep, speech bubbles.
enum PixelParts {
    /// A column that moves `speed` pixels a second and wraps from the right edge to the left.
    /// A still scene (nil `time`) keeps `start`.
    static func drift(from start: Int, speed: Double, width: Int, time: TimeInterval?) -> Int {
        guard let time else { return start }
        return (start + width + Int(time * speed)) % (64 + width) - width
    }

    /// Stars that twinkle in turn and a moon in the top right corner.
    static func stampNight(on grid: inout PixelGrid, time: TimeInterval?) {
        for (index, position) in starPositions.enumerated() where time.map({ (Int($0 * 2) + index) % 7 != 0 }) ?? true {
            grid.stamp(star, x: position.x, y: position.y)
        }
        grid.stamp(moon, x: 52, y: 3)
    }

    /// Two letters that float up from `x`, `y` and start again every four seconds.
    static func stampSleep(on grid: inout PixelGrid, x: Int, y: Int, time: TimeInterval?) {
        let rise = time.map { Int($0 * 1.5) % 6 } ?? 2
        grid.stamp(smallZ, x: x + rise / 2, y: y - rise)
        grid.stamp(bigZ, x: x + 6 + rise / 2, y: y - 6 - rise)
    }

    /// Darker ground under a hopping character: a row `width` wide around `centerX` and a
    /// shorter one below it, both narrowing as `hop` rises. Darkens what is already there.
    static func stampShadow(on grid: inout PixelGrid, centerX: Int, y: Int, width: Int, hop: Int) {
        for (row, rowWidth) in [max(4, width - hop), max(2, width - hop - 4)].enumerated() {
            for x in (centerX - rowWidth / 2)..<(centerX - rowWidth / 2 + rowWidth) {
                guard let color = grid[x: x, y: y + row] else { continue }
                let dark = (((color >> 16) & 0xFF) * 13 / 20) << 16 | (((color >> 8) & 0xFF) * 13 / 20) << 8 | (color & 0xFF) * 13 / 20
                grid.stamp(PixelSprite(["S"], palette: ["S": dark]), x: x, y: y + row)
            }
        }
    }

    private static let starPositions: [(x: Int, y: Int)] = [
        (4, 3), (15, 9), (27, 2), (33, 15), (44, 6), (60, 14), (22, 18), (8, 16),
    ]

    static let sun = PixelSprite([
        ".YYYY.",
        "YYYYYY",
        "YYYYYY",
        "YYYYYY",
        "YYYYYY",
        ".YYYY.",
    ], palette: ["Y": 0xFFE39A])

    private static let moon = PixelSprite([
        "..MMM.",
        ".MMM..",
        "MMM...",
        "MMM...",
        ".MMM..",
        "..MMM.",
    ], palette: ["M": 0xF4E9C1])

    private static let star = PixelSprite(["S"], palette: ["S": 0xF4E9C1])

    static let cloudWidth = 12
    private static let cloudRows = [
        "...WWWW.....",
        ".WWWWWWWW...",
        "WWWWWWWWWWWW",
        ".SSSSSSSSSS.",
    ]
    static let cloud = PixelSprite(cloudRows, palette: ["W": 0xFFFFFF, "S": 0xDCEBF3])
    static let nightCloud = PixelSprite(cloudRows, palette: ["W": 0x4A5A80, "S": 0x3E4D70])

    private static let smallZ = PixelSprite(["ZZZZ", "..Z.", ".Z..", "ZZZZ"], palette: ["Z": 0xE8F0FF])
    private static let bigZ = PixelSprite(["ZZZZZ", "...Z.", "..Z..", ".Z...", "ZZZZZ"], palette: ["Z": 0xE8F0FF])

    private static let bubbleColors: [Character: UInt] = ["W": 0xF3EFE6, "B": 0x1B2437]

    /// A bubble with three dots, its tail at the bottom left.
    static let waitingBubble = PixelSprite([
        ".WWWWWWWWW.",
        "WWWWWWWWWWW",
        "WWBWWBWWBWW",
        "WWWWWWWWWWW",
        ".WWWWWWWWW.",
        ".WW........",
        "W..........",
    ], palette: bubbleColors)

    /// A bubble with a question mark, its tail at the bottom left.
    static let questionBubble = PixelSprite([
        ".WWWWWWW.",
        "WWWBBBWWW",
        "WWWWWBWWW",
        "WWWWBWWWW",
        "WWWWWWWWW",
        "WWWWBWWWW",
        ".WWWWWWW.",
        ".WW......",
        "W........",
    ], palette: bubbleColors)
}

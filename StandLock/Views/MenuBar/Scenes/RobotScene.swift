import SwiftUI
import StandLockCore

/// A small pixel robot in a room by a window. Its face is a screen, so it shows each look there
/// instead of in a speech bubble.
struct RobotScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    var body: some View {
        PixelGridView(grid: grid)
    }

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let left = 26

    private var grid: PixelGrid {
        var grid = PixelGrid(width: 64, height: 34) { x, y in background(x: x, y: y) }

        grid.stamp(isNight ? Self.nightPlant : Self.plant, x: 50, y: 14)
        grid.stamp(isNight ? Self.nightRug : Self.rug, x: left - 2, y: 30)

        let top = look == .timeToStand ? 4 - hopHeight : 4
        if look == .timeToStand {
            PixelParts.stampShadow(on: &grid, centerX: left + 10, y: 31, width: 18, hop: hopHeight)
        }
        grid.stamp(Self.robot, x: left, y: top)
        grid.stamp(PixelSprite(["AA", "AA"], palette: ["A": antennaColor]), x: left + 9, y: top)
        grid.stamp(face, x: left + 4, y: top + 5)
        for (index, light) in chestLights.enumerated() {
            grid.stamp(PixelSprite(["L"], palette: ["L": light]), x: left + 7 + index * 2, y: top + 18)
        }
        if look == .timeToStand, top < 4 {
            let flame = time.map { Int($0 * 8) % 2 == 0 } ?? true ? Self.flame : Self.shortFlame
            grid.stamp(flame, x: left + 5, y: top + 27)
            grid.stamp(flame, x: left + 12, y: top + 27)
        }
        if look == .paused {
            PixelParts.stampSleep(on: &grid, x: 45, y: 12, time: time)
        }
        return grid
    }

    // MARK: - Robot

    /// The screen shows the look: eyes and mouth, a loading row, or a question mark.
    private var face: PixelSprite {
        switch look {
        case .working: return sceneIsBlinking(time) ? Self.blinkFace : Self.calmFace
        case .breakSoon: return Self.alertFace
        case .timeToStand: return Self.happyFace
        case .paused: return Self.sleepFace
        case .noSchedules: return Self.questionFace
        case .breakWaiting:
            // Three dots, one lit at a time.
            let lit = time.map { Int($0 * 3) % 3 } ?? 1
            return PixelSprite(Self.loadingRows(lit: lit), palette: Self.screenColors)
        }
    }

    private var antennaColor: UInt {
        let on = time.map { Int($0 * (look == .breakSoon ? 4 : 1)) % 2 == 0 } ?? true
        switch look {
        case .working, .timeToStand: return on ? 0x7ED67A : 0x4F7A4E
        case .breakSoon: return on ? 0xF5C842 : 0x8A7A48
        case .breakWaiting: return 0xF5C842
        case .paused: return 0x5A6270
        case .noSchedules: return 0x6EB4F0
        }
    }

    /// Red, yellow and green. While working one is lit at a time; asleep all three are off.
    private var chestLights: [UInt] {
        let bright: [UInt] = [0xF0605A, 0xF5C842, 0x7ED67A]
        let dim: [UInt] = [0x8A5250, 0x8A7A48, 0x4F7A4E]
        switch look {
        case .paused:
            return dim
        case .working:
            let lit = time.map { Int($0 * 2) % 3 } ?? 0
            return (0..<3).map { $0 == lit ? bright[$0] : dim[$0] }
        case .breakSoon, .timeToStand, .breakWaiting, .noSchedules:
            return bright
        }
    }

    /// Rocket boots lift it every 1.2 s, up to four pixels, so the antenna stays on the card.
    /// A still scene holds it mid air.
    private var hopHeight: Int {
        guard time != nil else { return 3 }
        let phase = tick.truncatingRemainder(dividingBy: 1.2) / 1.2
        return phase < 0.55 ? Int((sin(phase / 0.55 * .pi) * 4).rounded()) : 0
    }

    // MARK: - Room

    private func background(x: Int, y: Int) -> UInt {
        if (4...21).contains(x), (3...19).contains(y) {
            return window(x: x, y: y)
        }
        if (3...22).contains(x), y == 20 {
            return isNight ? 0x6E6880 : 0xD9CBB3
        }
        if y < 25 {
            let stripe = x % 8 == 0
            return isNight ? (stripe ? 0x544D61 : 0x5B5468) : (stripe ? 0xE2D4BD : 0xEADFCB)
        }
        if y == 25 {
            return isNight ? 0x463F52 : 0xC9B79A
        }
        let seam = y % 3 == 1 || (x + (y / 3) * 7) % 16 == 0
        return isNight ? (seam ? 0x3E3234 : 0x4A3C3E) : (seam ? 0xA27650 : 0xB98A5B)
    }

    /// A window with a cross frame: a cloud drifts past by day, a moon and stars show at night.
    private func window(x: Int, y: Int) -> UInt {
        if x <= 5 || x >= 20 || y <= 4 || y >= 18 || x == 12 || x == 13 || y == 11 {
            return isNight ? 0x8E8AA0 : 0xF4EEE2
        }
        if isNight {
            if Self.windowStars.contains(where: { $0 == (x, y) }) || Self.windowMoon.contains(where: { $0 == (x, y) }) {
                return 0xF4E9C1
            }
            return y < 11 ? 0x1E2A4A : 0x2A3760
        }
        let cloudX = time.map { 6 + Int($0 * 0.6) % 26 - 12 } ?? 7
        let cloud = PixelParts.cloud
        let row = y - 6, column = x - cloudX
        if (0..<cloud.rows.count).contains(row), (0..<cloud.rows[row].count).contains(column),
           let color = cloud.palette[cloud.rows[row][column]] {
            return color
        }
        return y < 11 ? 0xA9D8F0 : 0xC4E5F4
    }

    private static let windowStars: [(Int, Int)] = [(7, 7), (10, 14), (17, 15), (8, 16), (15, 13)]
    private static let windowMoon: [(Int, Int)] = [(16, 6), (17, 6), (15, 7), (15, 8), (16, 9), (17, 9)]

    // MARK: - Sprites

    private static let robot = PixelSprite([
        ".........AA.........",
        ".........AA.........",
        ".........DD.........",
        "..DDDDDDDDDDDDDDDD..",
        "..DMMMMMMMMMMMMMMD..",
        "..DMFFFFFFFFFFFFMD..",
        "..DMFFFFFFFFFFFFMD..",
        "DDDMFFFFFFFFFFFFMDDD",
        "DSDMFFFFFFFFFFFFMDSD",
        "DDDMFFFFFFFFFFFFMDDD",
        "..DMFFFFFFFFFFFFMD..",
        "..DMFFFFFFFFFFFFMD..",
        "..DMMMMMMMMMMMMMMD..",
        "..DSSSSSSSSSSSSSSD..",
        "..DDDDDDDDDDDDDDDD..",
        "......DDDDDDDD......",
        "...DDDDDDDDDDDDDD...",
        ".DDDMMMMMMMMMMMMDDD.",
        ".DSDMMMMMMMMMMMMDSD.",
        ".DSDMMMMMMMMMMMMDSD.",
        ".DSDMMMMMMMMMMMMDSD.",
        ".DDDSSSSSSSSSSSSDDD.",
        "...DSSSSSSSSSSSSD...",
        "...DDDDDDDDDDDDDD...",
        ".....DSD....DSD.....",
        ".....DSD....DSD.....",
        "....DDDDD..DDDDD....",
    ], palette: ["D": 0x2E3440, "M": 0xC9D3DE, "S": 0x9AA7B6, "F": 0x1D2B36, "A": 0x7ED67A])

    private static let screenColors: [Character: UInt] = ["F": 0x1D2B36, "C": 0x6EF0E0, "c": 0x2F6E6A, "W": 0xFFFFFF]

    private static let calmFace = PixelSprite([
        "FFFFFFFFFFFF",
        "FFCWFFFFCWFF",
        "FFCCFFFFCCFF",
        "FFFFFFFFFFFF",
        "FFFFCFFCFFFF",
        "FFFFFCCFFFFF",
        "FFFFFFFFFFFF",
    ], palette: screenColors)

    private static let blinkFace = PixelSprite([
        "FFFFFFFFFFFF",
        "FFFFFFFFFFFF",
        "FFCCFFFFCCFF",
        "FFFFFFFFFFFF",
        "FFFFCFFCFFFF",
        "FFFFFCCFFFFF",
        "FFFFFFFFFFFF",
    ], palette: screenColors)

    /// Wide eyes and an open mouth: the antenna is blinking.
    private static let alertFace = PixelSprite([
        "FCCCFFFFCCCF",
        "FCFCFFFFCFCF",
        "FCCCFFFFCCCF",
        "FFFFFFFFFFFF",
        "FFFFFCCFFFFF",
        "FFFFFCCFFFFF",
        "FFFFFFFFFFFF",
    ], palette: screenColors)

    private static let happyFace = PixelSprite([
        "FFFFFFFFFFFF",
        "FFCFFFFFFCFF",
        "FCFCFFFFCFCF",
        "FFFFFFFFFFFF",
        "FFFCFFFFCFFF",
        "FFFFCCCCFFFF",
        "FFFFFFFFFFFF",
    ], palette: screenColors)

    private static let sleepFace = PixelSprite([
        "FFFFFFFFFFFF",
        "FFFFFFFFFFFF",
        "FFccFFFFccFF",
        "FFFFFFFFFFFF",
        "FFFFFccFFFFF",
        "FFFFFFFFFFFF",
        "FFFFFFFFFFFF",
    ], palette: screenColors)

    private static let questionFace = PixelSprite([
        "FFFFCCCCFFFF",
        "FFFCFFFFCFFF",
        "FFFFFFFCFFFF",
        "FFFFFFCFFFFF",
        "FFFFFCFFFFFF",
        "FFFFFFFFFFFF",
        "FFFFFCFFFFFF",
    ], palette: screenColors)

    private static func loadingRows(lit: Int) -> [String] {
        let dots = (0..<3).map { $0 == lit ? "CC" : "cc" }
        let row = "FF" + dots.joined(separator: "F") + "FF"
        return ["FFFFFFFFFFFF", "FFFFFFFFFFFF", row, row, "FFFFFFFFFFFF", "FFFFFFFFFFFF", "FFFFFFFFFFFF"]
    }

    private static let flame = PixelSprite(["OYO", ".O."], palette: ["O": 0xF28A1E, "Y": 0xFFE07A])
    private static let shortFlame = PixelSprite(["OYO"], palette: ["O": 0xF28A1E, "Y": 0xFFE07A])

    private static let rugRows = [
        ".RRRRRRRRRRRRRRRRRRRRRR.",
        "RSSSSSSSSSSSSSSSSSSSSSSR",
        ".RRRRRRRRRRRRRRRRRRRRRR.",
    ]
    private static let rug = PixelSprite(rugRows, palette: ["R": 0xC8665A, "S": 0xE6A07A])
    private static let nightRug = PixelSprite(rugRows, palette: ["R": 0x6A3A44, "S": 0x7E4A50])

    private static let plantRows = [
        "...G..G...",
        "..GGLGGG..",
        ".GGLGGLGG.",
        "GGGGGGGGGG",
        ".GGGLGGGG.",
        "..GGGGGG..",
        "...GGGG...",
        ".DDDDDDDD.",
        ".PPPPPPPP.",
        "..PPPPPP..",
        "..PPPPPP..",
        "...PPPP...",
    ]
    private static let plant = PixelSprite(plantRows, palette: ["G": 0x5E9E3A, "L": 0x8CC65A, "D": 0x9E4E2E, "P": 0xC9683F])
    private static let nightPlant = PixelSprite(plantRows, palette: ["G": 0x2F4A3A, "L": 0x3E5E46, "D": 0x4A2E2E, "P": 0x5E3A36])
}

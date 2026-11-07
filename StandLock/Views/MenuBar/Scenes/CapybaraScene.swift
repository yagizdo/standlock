import SwiftUI
import StandLockCore

/// A pixel capybara soaking in a hot spring under the mountains, a mandarin on its head.
struct CapybaraScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    var body: some View {
        PixelGridView(grid: grid)
    }

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    /// The capybara's left edge and the row the water starts on.
    private let left = 18
    private let waterline = 24

    private var grid: PixelGrid {
        var grid = PixelGrid(width: 64, height: 34) { x, y in background(x: x, y: y) }

        if isNight {
            PixelParts.stampNight(on: &grid, time: time)
        } else {
            grid.stamp(PixelParts.sun, x: 6, y: 3)
        }
        let cloud = isNight ? PixelParts.nightCloud : PixelParts.cloud
        grid.stamp(cloud, x: PixelParts.drift(from: 30, speed: 0.5, width: PixelParts.cloudWidth, time: time), y: 5)

        stampSteam(on: &grid)
        stampCapybara(on: &grid)
        grid.stamp(isNight ? Self.nightWaterFront : Self.waterFront, x: left - 1, y: waterline)
        if look != .timeToStand || hopHeight == 0 {
            grid.stamp(isNight ? Self.nightRipple : Self.ripple, x: left - 1, y: waterline)
        }

        switch look {
        case .paused:
            PixelParts.stampSleep(on: &grid, x: 41, y: 8, time: time)
        case .breakWaiting:
            grid.stamp(PixelParts.waitingBubble, x: 46, y: 2)
        case .noSchedules:
            grid.stamp(PixelParts.questionBubble, x: 46, y: 0)
        case .breakSoon:
            grid.stamp(duckFacesRight ? Self.duckRight : Self.duckLeft, x: duckX, y: waterline - 3)
        case .working, .timeToStand:
            break
        }
        return grid
    }

    // MARK: - Capybara

    private func stampCapybara(on grid: inout PixelGrid) {
        let top: Int
        if look == .timeToStand {
            top = 10 - hopHeight
            grid.stamp(Self.standingCapybara, x: left, y: top)
        } else {
            // It sinks a pixel and rises again, slowly, as if breathing.
            top = 10 + (time.map { Int($0 / 1.6) % 2 } ?? 0)
            grid.stamp(Self.bathingCapybara, x: left, y: top)
        }
        grid.stamp(Self.mandarin, x: left + 19, y: top - 2)

        if look == .paused || sceneIsBlinking(time) {
            grid.stamp(Self.closedEye, x: left + 19, y: top + 4)
            return
        }
        let gaze = self.gaze
        grid.stamp(Self.eye, x: left + 19 + gaze.x, y: top + 4 + gaze.y)
    }

    /// The eye moves one pixel: after the duck before a break, toward a bubble otherwise.
    private var gaze: (x: Int, y: Int) {
        switch look {
        case .breakSoon: (duckX < left + 15 ? -1 : duckX > left + 22 ? 1 : 0, 0)
        case .breakWaiting: (-1, 0)
        case .noSchedules: (1, -1)
        case .working, .timeToStand, .paused: (0, 0)
        }
    }

    /// A hop out of the water every 1.4 s, up to seven pixels, so the legs clear the surface.
    /// A still scene holds it mid air.
    private var hopHeight: Int {
        guard time != nil else { return 6 }
        let phase = tick.truncatingRemainder(dividingBy: 1.4) / 1.4
        return phase < 0.55 ? Int((sin(phase / 0.55 * .pi) * 7).rounded()) : 0
    }

    /// A toy duck that floats from side to side in the last minute.
    private var duckX: Int {
        guard time != nil else { return 44 }
        return 28 + Int((sin(tick * 0.7) * 22).rounded())
    }

    private var duckFacesRight: Bool {
        time.map { cos($0 * 0.7) >= 0 } ?? false
    }

    // MARK: - Background

    /// Wisps that rise from the water and fade out above the rocks.
    private func stampSteam(on grid: inout PixelGrid) {
        let color: UInt = isNight ? 0x8C9AB8 : 0xF6FBFA
        for wisp in Self.wisps {
            let rise = time.map { (Int($0 * 2.5) + wisp.offset) % 9 } ?? wisp.offset
            let y = waterline - 1 - rise
            grid.stamp(PixelSprite(["S"], palette: ["S": color]), x: wisp.x + (y % 4 < 2 ? 0 : 1), y: y)
        }
    }

    private func background(x: Int, y: Int) -> UInt {
        if y >= waterline {
            let shift = time == nil ? 0 : Int(tick * 2)
            if y % 3 == 1, (x + y * 5 + shift) % 11 < 2 {
                return isNight ? 0x4F7A8A : 0xA6E2DC
            }
            return Self.water(row: y - waterline, night: isNight)
        }
        if y >= waterline - 2 {
            let seam = (x + (y == waterline - 2 ? 0 : 2)) % 4 == 0
            return isNight ? (seam ? 0x2A2A33 : 0x3E3E4A) : (seam ? 0x6E6E6A : 0x9A9A94)
        }
        // Near hills peak every 24 columns, far mountains every 32 with snow on their tops.
        let hill = 17 + abs((x + 20) % 24 - 12) / 2
        if y >= hill {
            return isNight ? 0x24363A : 0x7FA86A
        }
        let peak = 9 + abs((x + 16) % 32 - 16) * 3 / 4
        if y >= peak {
            if y < 12 {
                return isNight ? 0x8C9AB8 : 0xF4F7FA
            }
            return isNight ? 0x2C3858 : 0x9BB3D1
        }
        return (isNight ? Self.nightSky : Self.daySky)[min(y / 5, 3)]
    }

    private static func water(row: Int, night: Bool) -> UInt {
        if row < 5 {
            return night ? 0x2F5260 : 0x6FC6C0
        }
        return night ? 0x284856 : 0x5BB3B0
    }

    private static let daySky: [UInt] = [0xBFE0F0, 0xCFE6F0, 0xDDEDEE, 0xEAF1EA]
    private static let nightSky: [UInt] = [0x1E2A4A, 0x253456, 0x2D3E63, 0x354870]

    private static let wisps: [(x: Int, offset: Int)] = [(10, 0), (18, 4), (46, 2), (54, 7), (60, 5)]

    // MARK: - Sprites

    private static let capybaraColors: [Character: UInt] = [
        "D": 0x3B2618, "B": 0xA0703F, "S": 0x8A5E33, "L": 0xC4925C, "N": 0x3B2618, "P": 0xE39A86, "K": 0x1E140D,
    ]

    private static let bathingCapybara = PixelSprite([
        "...............DD...........",
        "..............DLLD..........",
        "...............DDDDDDDDD....",
        "..DDDDDDDD....DBBBBBBBBBDD..",
        ".DBBBBBBBBDDDDBBBBBBBBBBBBD.",
        "DBBBBBBBBBBBBBBBBBBBBBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBBBBSSNND",
        "DBBBBBBBBBBBBBBBBBBBBBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBPBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBBBBSDDD.",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
    ], palette: capybaraColors)

    /// Out of the water, legs and all, for the hop.
    private static let standingCapybara = PixelSprite([
        "...............DD...........",
        "..............DLLD..........",
        "...............DDDDDDDDD....",
        "..DDDDDDDD....DBBBBBBBBBDD..",
        ".DBBBBBBBBDDDDBBBBBBBBBBBBD.",
        "DBBBBBBBBBBBBBBBBBBBBBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBBBBSSNND",
        "DBBBBBBBBBBBBBBBBBBBBBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBPBBSSSSD",
        "DBBBBBBBBBBBBBBBBBBBBBBSDDD.",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        "DBBBBBBBBBBBBBBBBBBBBBBD....",
        ".DBBBBBBBBBBBBBBBBBBBBD.....",
        "..DDBBDDDDDDDDDDDBBDD.......",
        "...DBBD.........DBBD........",
        "...DDDD.........DDDD........",
    ], palette: capybaraColors)

    private static let eye = PixelSprite(["KW", "KK"], palette: capybaraColors.merging(["W": 0xFFFFFF]) { $1 })
    private static let closedEye = PixelSprite(["BB", "KK"], palette: capybaraColors)

    private static let mandarin = PixelSprite([
        ".GG.",
        "OYYO",
        "OYYO",
        ".OO.",
    ], palette: ["G": 0x5E9E3A, "Y": 0xF7A23A, "O": 0xC9681C])

    /// The water in front of the capybara, so its body ends at the surface.
    private static let waterFrontRows = Array(repeating: String(repeating: "A", count: 30), count: 5)
        + Array(repeating: String(repeating: "B", count: 30), count: 5)
    private static let waterFront = PixelSprite(waterFrontRows, palette: ["A": water(row: 0, night: false), "B": water(row: 5, night: false)])
    private static let nightWaterFront = PixelSprite(waterFrontRows, palette: ["A": water(row: 0, night: true), "B": water(row: 5, night: true)])

    /// A light ring on the surface where the body meets the water.
    private static let rippleRow = "WWW.WWWWWWWWWWWWWWWWWWWWWW.WWW"
    private static let ripple = PixelSprite([rippleRow], palette: ["W": 0xA6E2DC])
    private static let nightRipple = PixelSprite([rippleRow], palette: ["W": 0x4F7A8A])

    private static let duckColors: [Character: UInt] = ["Y": 0xFFD43B, "K": 0x1E140D, "O": 0xF28A1E]
    private static let duckRight = PixelSprite([
        "...YY.",
        "...YKO",
        "YYYYY.",
        ".YYY..",
    ], palette: duckColors)
    private static let duckLeft = PixelSprite([
        ".YY...",
        "OKY...",
        ".YYYYY",
        "..YYY.",
    ], palette: duckColors)
}

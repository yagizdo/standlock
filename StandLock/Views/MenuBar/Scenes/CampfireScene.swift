import SwiftUI
import StandLockCore

/// A pixel camper roasting a marshmallow by a fire at dusk, a tent behind among the pines.
struct CampfireScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    var body: some View {
        PixelGridView(grid: grid)
    }

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private var grid: PixelGrid {
        var grid = PixelGrid(width: 64, height: 34) { x, y in background(x: x, y: y) }
        PixelParts.stampNight(on: &grid, time: time)

        for pine in Self.pines {
            grid.stamp(isNight ? Self.nightPine : Self.pine, x: pine, y: 13)
        }
        grid.stamp(isNight ? Self.tentNight : Self.tent, x: 44, y: 15)
        grid.stamp(Self.seat, x: 8, y: 27)

        // Fire
        grid.stamp(Self.logs, x: 26, y: 27)
        if isNight {
            grid.stamp(Self.embers, x: 27, y: 25)
        } else {
            let frame = time.map { Int($0 * 6) % 2 } ?? 0
            grid.stamp(frame == 0 ? Self.flameA : Self.flameB, x: 27, y: 19)
            stampSparks(on: &grid)
        }
        grid.stamp(Self.stones, x: 24, y: 29)

        switch look {
        case .timeToStand:
            grid.stamp(Self.standingCamper, x: 8, y: 9)
            stampEyes(on: &grid, x: 13, y: 15)
        case .paused:
            PixelParts.stampSleep(on: &grid, x: 36, y: 16, time: time)
        case .working, .breakSoon, .breakWaiting, .noSchedules:
            grid.stamp(Self.sittingCamper, x: 9, y: 14)
            grid.stamp(Self.stick, x: 21, y: 20)
            let burning = look == .breakSoon
            grid.stamp(burning ? Self.burningMarshmallow : Self.marshmallow, x: 27, y: burning ? 16 : 18)
            stampEyes(on: &grid, x: 13, y: 20)
            if look == .breakWaiting { grid.stamp(PixelParts.waitingBubble, x: 18, y: 4) }
            if look == .noSchedules { grid.stamp(PixelParts.questionBubble, x: 18, y: 2) }
        }
        return grid
    }

    private func stampEyes(on grid: inout PixelGrid, x: Int, y: Int) {
        let eye = PixelSprite(look == .breakSoon ? ["K", "K"] : ["K"], palette: ["K": 0x1E1A24])
        let shut = PixelSprite(["F"], palette: ["F": 0xC9906A])
        let dx = look == .breakSoon ? 1 : 0
        let dy = look == .breakSoon ? -1 : 0
        if sceneIsBlinking(time) {
            grid.stamp(shut, x: x, y: y)
            grid.stamp(shut, x: x + 3, y: y)
            return
        }
        grid.stamp(eye, x: x + dx, y: y + dy)
        grid.stamp(eye, x: x + 3 + dx, y: y + dy)
    }

    private func stampSparks(on grid: inout PixelGrid) {
        for index in 0..<4 {
            let rise = time.map { (Int($0 * 4) + index * 3) % 12 } ?? index * 3
            let x = 30 + index * 2 + (rise % 4 < 2 ? 0 : 1)
            let color: UInt = rise > 7 ? 0xB0503A : 0xFFC04A
            grid.stamp(PixelSprite(["S"], palette: ["S": color]), x: x, y: 18 - rise)
        }
    }

    private func background(x: Int, y: Int) -> UInt {
        if y < 24 {
            let day: [UInt] = [0x2B2D5C, 0x3E3A6A, 0x6A4B7A, 0xB0607A, 0xE08A6A]
            let night: [UInt] = [0x10142C, 0x151A36, 0x1B2140, 0x222849, 0x2A2F52]
            return (isNight ? night : day)[min(y / 5, 4)]
        }
        // Firelight on the grass, smaller when the fire is down to embers.
        let dx = x - 32, dy = (y - 29) * 3
        let reach = dx * dx + dy * dy
        let flicker = time.map { Int($0 * 6) % 2 } ?? 0
        let inner = isNight ? 40 : 150 + flicker * 20
        let outer = isNight ? 120 : 380 + flicker * 30
        if reach < inner { return isNight ? 0x3E3428 : 0x6A5634 }
        if reach < outer { return isNight ? 0x2C2C2A : 0x4A4A32 }
        return isNight ? 0x1C2620 : 0x2E3B30
    }

    private static let pines = [-3, 4, 11, 40, 57]

    private static let pineRows = [
        "....T....",
        "...TTT...",
        "..TTTTT..",
        "...TTT...",
        "..TTTTT..",
        ".TTTTTTT.",
        "..TTTTT..",
        ".TTTTTTT.",
        "TTTTTTTTT",
        "....T....",
        "....T....",
    ]
    private static let pine = PixelSprite(pineRows, palette: ["T": 0x1C2638])
    private static let nightPine = PixelSprite(pineRows, palette: ["T": 0x0C1020])

    private static let tentRows = [
        "........K.........",
        ".......KTK........",
        "......KTTtK.......",
        ".....KTTTttK......",
        "....KTTTDtttK.....",
        "...KTTTDDDtttK....",
        "..KTTTDDDDDtttK...",
        ".KTTTDDDDDDDtttK..",
        "KTTTDDDDDDDDDtttK.",
        "KKKKKKKKKKKKKKKKK.",
    ]
    private static let tent = PixelSprite(tentRows, palette: ["K": 0x2A1A14, "T": 0xE07B39, "t": 0xB85F28, "D": 0x3B2A20])
    private static let tentNight = PixelSprite(tentRows, palette: ["K": 0x150D0A, "T": 0x8A4A28, "t": 0x6A3820, "D": 0xF2B35A])

    private static let seat = PixelSprite([
        ".LLLLLLLLLLLL.",
        "OLLLLLLLLLLLLO",
        ".LLLLLLLLLLLL.",
    ], palette: ["L": 0x6B4226, "O": 0xC49A6C])

    private static let fireColors: [Character: UInt] = ["R": 0xD9432E, "O": 0xF28A1E, "Y": 0xFFD95A, "W": 0xFFF3B0]

    private static let flameA = PixelSprite([
        ".....R.....",
        "....ROR....",
        "...ROOR.R..",
        "..ROYOROR..",
        "..ROYYOOR..",
        ".ROYYWYOOR.",
        ".ROYWWWYOR.",
        "ROOYWWWYOOR",
        ".ROOYYYOOR.",
    ], palette: fireColors)

    private static let flameB = PixelSprite([
        "......R....",
        "..R..ROR...",
        "..RR.ROOR..",
        "..RORYOOR..",
        "..ROOYYOR..",
        ".ROOYWYYOR.",
        ".ROYWWWYOR.",
        "ROOYWWWYOOR",
        ".ROOYYYOOR.",
    ], palette: fireColors)

    private static let embers = PixelSprite([
        "...R...R...",
        "..ROR.ROR..",
        ".ROOOROOOR.",
    ], palette: fireColors)

    private static let logs = PixelSprite([
        ".LLL.....LLL.",
        "...LLL.LLL...",
        ".....LLL.....",
    ], palette: ["L": 0x6B4226])

    private static let stones = PixelSprite([
        "SS.............SS",
        ".SSSDSSSDSSSDSSS.",
    ], palette: ["S": 0x8A8A90, "D": 0x5E5E66])

    private static let camperColors: [Character: UInt] = [
        "K": 0x1E1A24, "P": 0xF3EFE6, "H": 0xD9544A, "h": 0xB8423A, "F": 0xF2C49A, "R": 0xF0A08A,
        "S": 0xF2B33A, "C": 0x3F7FA8, "J": 0x3A4660, "B": 0x3B2A20,
    ]

    private static let sittingCamper = PixelSprite([
        ".....KK.....",
        "....KPPK....",
        "...KHHHHK...",
        "..KHHHHHHK..",
        "..KhhhhhhK..",
        "..KFFFFFFK..",
        "..KFFFFFFK..",
        "..KRFFFFRK..",
        "...KFFFFK...",
        "..KSSSSSSK..",
        ".KCCCSCCCCKC",
        ".KCCCSCCCCKF",
        ".KCCCCCCCCK.",
        ".KJJJJJJJJK.",
        ".KJJKKKKJJK.",
        "..KJK..KJK..",
        "..KJK..KJK..",
        ".KBBK.KBBK..",
    ], palette: camperColors)

    /// Arms up for a stretch.
    private static let standingCamper = PixelSprite([
        "......KK......",
        ".....KPPK.....",
        "KF..KHHHHK..FK",
        "KCK.HHHHHHK.KC",
        ".KCKhhhhhhKKC.",
        "..KCFFFFFFKCK.",
        "...KFFFFFFKK..",
        "...KRFFFFRK...",
        "....KFFFFK....",
        "...KSSSSSSK...",
        "..KCCCSCCCCK..",
        "..KCCCSCCCCK..",
        "..KCCCCCCCCK..",
        "..KJJJJJJJJK..",
        "..KJJJKKJJJK..",
        "...KJJK.KJJK..",
        "...KJJK.KJJK..",
        "...KJJK.KJJK..",
        "..KBBBK.KBBBK.",
    ], palette: camperColors)

    private static let stick = PixelSprite([
        "......L",
        ".....L.",
        "...LL..",
        ".LL....",
        "L......",
    ], palette: ["L": 0x8A5A34])

    private static let marshmallow = PixelSprite(["MM", "MM"], palette: ["M": 0xFBF4E6])
    private static let burningMarshmallow = PixelSprite([".Y", "OR", "MB", "BB"], palette: ["Y": 0xFFD95A, "O": 0xF28A1E, "R": 0xD9432E, "M": 0xD9A05A, "B": 0x3B2A20])
}

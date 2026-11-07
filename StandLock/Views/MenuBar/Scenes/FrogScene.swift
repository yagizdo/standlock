import SwiftUI
import StandLockCore

/// A pixel frog on a lily pad. The whole card is one 64 x 34 grid of 4 pt pixels, and every
/// movement steps a whole pixel, so it keeps the pixel look in motion too.
struct FrogScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    var body: some View {
        PixelGridView(grid: grid)
    }

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private var grid: PixelGrid {
        var grid = PixelGrid(width: 64, height: 34) { x, y in background(x: x, y: y) }

        if isNight {
            for (index, star) in Self.stars.enumerated() where time == nil || (Int(tick * 2) + index) % 7 != 0 {
                grid.stamp(Self.star, x: star.x, y: star.y)
            }
            grid.stamp(Self.moon, x: 52, y: 3)
        } else {
            grid.stamp(Self.sun, x: 52, y: 4)
        }
        let cloud = isNight ? Self.nightCloud : Self.cloud
        grid.stamp(cloud, x: drift(from: 6, speed: 0.5), y: 5)
        grid.stamp(cloud, x: drift(from: 36, speed: 0.8), y: 10)
        grid.stamp(Self.reeds, x: 52, y: 17)

        // The pad rocks one pixel on the water while the frog rests on it.
        let bob = time == nil || look == .timeToStand ? 0 : Int(tick / 0.9) % 2
        grid.stamp(Self.pad, x: 14, y: 25 + bob)
        stampFrog(on: &grid, bob: bob)

        switch look {
        case .paused:
            let rise = time == nil ? 2 : Int(tick * 1.5) % 6
            grid.stamp(Self.smallZ, x: 34 + rise / 2, y: 11 - rise)
            grid.stamp(Self.bigZ, x: 40 + rise / 2, y: 5 - rise)
        case .breakWaiting:
            grid.stamp(Self.waitingBubble, x: 33, y: 4)
        case .noSchedules:
            grid.stamp(Self.questionBubble, x: 33, y: 3)
        case .breakSoon:
            grid.stamp(Self.fly, x: flyPosition.x, y: flyPosition.y)
        case .working, .timeToStand:
            break
        }
        return grid
    }

    // MARK: - Frog

    private func stampFrog(on grid: inout PixelGrid, bob: Int) {
        // The head's top left corner. The standing frog is wider, its head sits two columns in.
        let head: (x: Int, y: Int)
        if look == .timeToStand {
            let height = hopHeight
            grid.stamp(Self.standingFrog, x: 15, y: 9 - height)
            head = (17, 9 - height)
        } else {
            grid.stamp(Self.sittingFrog, x: 17, y: 13 + bob)
            head = (17, 13 + bob)
        }

        if look == .paused || sceneIsBlinking(time) {
            grid.stamp(Self.closedEye, x: head.x + 3, y: head.y + 1)
            grid.stamp(Self.closedEye, x: head.x + 10, y: head.y + 1)
            return
        }
        let gaze = self.gaze
        grid.stamp(Self.pupil, x: head.x + 4 + gaze.x, y: head.y + 2 + gaze.y)
        grid.stamp(Self.pupil, x: head.x + 11 + gaze.x, y: head.y + 2 + gaze.y)
    }

    /// Pupils move one pixel inside the eye: up at the fly before a break, aside while waiting.
    private var gaze: (x: Int, y: Int) {
        switch look {
        case .breakSoon: (flyPosition.x < 25 ? -1 : 0, -1)
        case .breakWaiting: (-1, 0)
        case .noSchedules: (-1, -1)
        case .working, .timeToStand, .paused: (0, 0)
        }
    }

    /// A hop every 1.2 s, up to six pixels. A still scene holds the frog mid air.
    private var hopHeight: Int {
        guard time != nil else { return 4 }
        let phase = tick.truncatingRemainder(dividingBy: 1.2) / 1.2
        return phase < 0.5 ? Int((sin(phase / 0.5 * .pi) * 6).rounded()) : 0
    }

    /// A fly that loops above the frog's head in the last minute.
    private var flyPosition: (x: Int, y: Int) {
        guard time != nil else { return (36, 7) }
        return (25 + Int((cos(tick * 2.2) * 14).rounded()), 7 + Int((sin(tick * 4.4) * 3).rounded()))
    }

    // MARK: - Background

    private func background(x: Int, y: Int) -> UInt {
        if y < 24 {
            return (isNight ? Self.nightSky : Self.daySky)[min(y / 6, 3)]
        }
        let shift = time == nil ? 0 : Int(tick * 2)
        if y % 3 == 1, (x + y * 7 + shift) % 13 < 3 {
            return isNight ? 0x4D7FA3 : 0x8CCDE6
        }
        if y < 27 {
            return isNight ? 0x2A4F6E : 0x5DB0D2
        }
        return isNight ? 0x234662 : 0x4FA3C7
    }

    /// A column that moves `speed` pixels a second and wraps from the right edge to the left.
    private func drift(from start: Int, speed: Double) -> Int {
        guard time != nil else { return start }
        let width = 12
        return (start + width + Int(tick * speed)) % (64 + width) - width
    }

    private static let daySky: [UInt] = [0x8FCBEB, 0xA3D6EF, 0xB8E0F3, 0xCCE9F6]
    private static let nightSky: [UInt] = [0x1E2A4A, 0x253456, 0x2D3E63, 0x354870]
    private static let stars: [(x: Int, y: Int)] = [(4, 3), (15, 9), (27, 2), (33, 15), (44, 6), (60, 14), (22, 18), (8, 16)]

    // MARK: - Sprites

    private static let frogColors: [Character: UInt] = [
        "K": 0x1E3B2A, "G": 0x6CC24A, "L": 0xB5E68A, "W": 0xFFFFFF, "P": 0xF29CA3,
    ]

    private static let sittingFrog = PixelSprite([
        "...KKK....KKK...",
        "..KWWWK..KWWWK..",
        "..KWWWKKKKWWWK..",
        ".KGWWWGGGGWWWGK.",
        ".KGGWWGGGGWWGGK.",
        "KGGGGGGGGGGGGGGK",
        "KGPPGKGGGGKGPPGK",
        "KGGGGGKKKKGGGGGK",
        ".KGGLLLLLLLLGGK.",
        ".KGLLLLLLLLLLGK.",
        "KGGKLLLLLLLLKGGK",
        "KGGGKKKKKKKKGGGK",
        ".KKK........KKK.",
    ], palette: frogColors)

    /// Arms up and legs down, for the hop.
    private static let standingFrog = PixelSprite([
        ".....KKK....KKK.....",
        "KK..KWWWK..KWWWK..KK",
        "KGK.KWWWKKKKWWWK.KGK",
        ".KGKGWWWGGGGWWWGKGK.",
        "..KKGGWWGGGGWWGGKK..",
        "..KGGGGGGGGGGGGGGK..",
        "..KGPPGKGGGGKGPPGK..",
        "..KGGGGGKKKKGGGGGK..",
        "...KGGLLLLLLLLGGK...",
        "...KGLLLLLLLLLLGK...",
        "...KGLLLLLLLLLLGK...",
        "....KGLLLLLLLLGK....",
        ".....KGGKKKKGGK.....",
        ".....KGK....KGK.....",
        ".....KGK....KGK.....",
        "....KGGK....KGGK....",
        "....KKK......KKK....",
    ], palette: frogColors)

    private static let pupil = PixelSprite(["BB", "BB"], palette: ["B": 0x1B1B1B])

    /// Covers one eye's white with a lid and a dark line.
    private static let closedEye = PixelSprite(["GGG", "GGG", "KKK", "GGG"], palette: frogColors)

    private static let pad = PixelSprite([
        ".....DDDDDDDDDDDD.....",
        "...DDLLLLLLLLLLLLDD...",
        ".DDLLLLLLLLLLLLLLLLDD.",
        "DLLLLLLLLLLLLLLLLLLLLD",
        ".DDDDDDDDDDDDDDDDDDDD.",
    ], palette: ["D": 0x245C2B, "L": 0x3E8E41])

    private static let cloudRows = [
        "...WWWW.....",
        ".WWWWWWWW...",
        "WWWWWWWWWWWW",
        ".SSSSSSSSSS.",
    ]
    private static let cloud = PixelSprite(cloudRows, palette: ["W": 0xFFFFFF, "S": 0xDCEBF3])
    private static let nightCloud = PixelSprite(cloudRows, palette: ["W": 0x4A5A80, "S": 0x3E4D70])

    private static let sun = PixelSprite([
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

    private static let reeds = PixelSprite([
        ".C...C",
        ".C.C.C",
        ".C.C.C",
        ".R.C.R",
        ".R.R.R",
        ".R.R.R",
        ".R.R.R",
        "RR.R.R",
    ], palette: ["C": 0x7A4A2A, "R": 0x4F8A3A])

    private static let fly = PixelSprite(["W..W", ".BB.", ".BB."], palette: ["W": 0xF4FAFD, "B": 0x1B1B1B])

    private static let smallZ = PixelSprite(["ZZZZ", "..Z.", ".Z..", "ZZZZ"], palette: ["Z": 0xE8F0FF])
    private static let bigZ = PixelSprite(["ZZZZZ", "...Z.", "..Z..", ".Z...", "ZZZZZ"], palette: ["Z": 0xE8F0FF])

    private static let bubbleColors: [Character: UInt] = ["W": 0xF3EFE6, "B": 0x1B2437]

    private static let waitingBubble = PixelSprite([
        ".WWWWWWWWW.",
        "WWWWWWWWWWW",
        "WWBWWBWWBWW",
        "WWWWWWWWWWW",
        ".WWWWWWWWW.",
        ".WW........",
        "W..........",
    ], palette: bubbleColors)

    private static let questionBubble = PixelSprite([
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

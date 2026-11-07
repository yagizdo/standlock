import SwiftUI
import StandLockCore

/// A pixel fox on a tree stump in an autumn wood, with leaves coming down.
struct FoxScene: View {
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
            PixelParts.stampNight(on: &grid, time: time)
        } else {
            grid.stamp(PixelParts.sun, x: 52, y: 4)
        }
        let cloud = isNight ? PixelParts.nightCloud : PixelParts.cloud
        grid.stamp(cloud, x: PixelParts.drift(from: 20, speed: 0.6, width: PixelParts.cloudWidth, time: time), y: 4)

        for tree in Self.trees {
            grid.stamp(isNight ? Self.nightTree : tree.sprite, x: tree.x, y: 14)
        }
        if !isNight {
            stampLeaves(on: &grid)
        }
        grid.stamp(Self.stump, x: 12, y: 26)
        stampFox(on: &grid)

        switch look {
        case .paused:
            PixelParts.stampSleep(on: &grid, x: 34, y: 10, time: time)
        case .breakWaiting:
            grid.stamp(PixelParts.waitingBubble, x: 33, y: 2)
        case .noSchedules:
            grid.stamp(PixelParts.questionBubble, x: 33, y: 1)
        case .breakSoon:
            let wingsOpen = time.map { Int($0 * 6) % 2 == 0 } ?? true
            grid.stamp(wingsOpen ? Self.butterflyOpen : Self.butterflyClosed, x: butterfly.x, y: butterfly.y)
        case .working, .timeToStand:
            break
        }
        return grid
    }

    // MARK: - Fox

    private func stampFox(on grid: inout PixelGrid) {
        let top: Int
        if look == .timeToStand {
            top = 6 - hopHeight
            PixelParts.stampShadow(on: &grid, centerX: 26, y: 28, width: 14, hop: hopHeight)
            grid.stamp(Self.standingFox, x: 14, y: top)
        } else {
            top = 8
            grid.stamp(Self.sittingFox, x: 14, y: top)
        }

        if look == .paused || sceneIsBlinking(time) {
            grid.stamp(Self.closedEye, x: 18, y: top + 6)
            grid.stamp(Self.closedEye, x: 26, y: top + 6)
            return
        }
        let gaze = self.gaze
        grid.stamp(Self.eye, x: 18 + gaze.x, y: top + 6 + gaze.y)
        grid.stamp(Self.eye, x: 26 + gaze.x, y: top + 6 + gaze.y)
    }

    /// Eyes move one pixel: after the butterfly before a break, toward a bubble otherwise.
    private var gaze: (x: Int, y: Int) {
        switch look {
        case .breakSoon: (butterfly.x < 18 ? -1 : butterfly.x > 28 ? 1 : 0, -1)
        case .breakWaiting: (-1, 0)
        case .noSchedules: (1, -1)
        case .working, .timeToStand, .paused: (0, 0)
        }
    }

    /// A hop every 1.2 s, up to five pixels. A still scene holds the fox mid air.
    private var hopHeight: Int {
        guard time != nil else { return 3 }
        let phase = tick.truncatingRemainder(dividingBy: 1.2) / 1.2
        return phase < 0.5 ? Int((sin(phase / 0.5 * .pi) * 5).rounded()) : 0
    }

    /// A butterfly that loops above the fox's ears in the last minute.
    private var butterfly: (x: Int, y: Int) {
        guard time != nil else { return (36, 3) }
        return (22 + Int((cos(tick * 1.8) * 13).rounded()), 3 + Int((sin(tick * 3.6) * 2).rounded()))
    }

    // MARK: - Background

    /// Leaves fall the height of the card, swaying one or two pixels.
    private func stampLeaves(on grid: inout PixelGrid) {
        for (index, leaf) in Self.leaves.enumerated() {
            let fall = time.map { Int($0 * leaf.speed) } ?? 0
            let y = (fall + leaf.offset) % 34
            let sway = time.map { sin($0 * 1.5 + Double(index)) } ?? 0
            let sprite = sway < 0 ? leaf.left : leaf.right
            grid.stamp(sprite, x: leaf.x + Int((sway * 2).rounded()), y: y)
        }
    }

    private func background(x: Int, y: Int) -> UInt {
        if y < 24 {
            return (isNight ? Self.nightSky : Self.daySky)[min(y / 6, 3)]
        }
        if (x * 7 + y * 13) % 11 == 0 {
            return isNight ? 0x4A3B45 : 0xE0A050
        }
        if (x * 5 + y * 3) % 17 == 0 {
            return isNight ? 0x2E242E : 0x8E5129
        }
        return isNight ? 0x3B2F3A : 0xB9733A
    }

    private static let daySky: [UInt] = [0x9FCFE0, 0xB6DAE0, 0xCDE4DC, 0xE3EDD6]
    private static let nightSky: [UInt] = [0x1E2A4A, 0x253456, 0x2D3E63, 0x354870]

    // MARK: - Sprites

    private static let foxColors: [Character: UInt] = [
        "D": 0x4A2414, "O": 0xE8803A, "W": 0xFFF4E6, "K": 0x2A1A14,
    ]

    private static let sittingFox = PixelSprite([
        ".DD............DD.......",
        ".DKD..........DKD.......",
        ".DKOD........DOKD.......",
        ".DOOOD......DOOOD.......",
        ".DOOOODDDDDDOOOOD.......",
        ".DOOOOOOOOOOOOOOD.......",
        "DOOOOOOOOOOOOOOOOD......",
        "DOOOOOOOOOOOOOOOOD......",
        "DWOOOOOOOOOOOOOOWD......",
        "DWWWOOOOOOOOOOWWWD..DDD.",
        ".DWWWWWOOOOWWWWWD..DWWWD",
        "..DWWWWWKKWWWWWD..DWWWWD",
        "...DDWWWWWWWWDD...DOWWOD",
        "...DOOOWWWWOOOD...DOOOOD",
        "..DOOOWWWWWWOOOD..DOOOOD",
        "..DOOOWWWWWWOOODDDDOOOOD",
        "..DOOOOWWWWOOOODOOOOOOD.",
        "..DOOOOOOOOOOOODOOOOOD..",
        "..DKKKDOOOODKKKDDDDDD...",
        "...DDD.DDDD.DDD.........",
    ], palette: foxColors)

    /// Paws up and legs down, for the hop.
    private static let standingFox = PixelSprite([
        ".DD............DD.......",
        ".DKD..........DKD.......",
        ".DKOD........DOKD.......",
        ".DOOOD......DOOOD.......",
        ".DOOOODDDDDDOOOOD.......",
        ".DOOOOOOOOOOOOOOD.......",
        "DOOOOOOOOOOOOOOOOD......",
        "DOOOOOOOOOOOOOOOOD......",
        "DWOOOOOOOOOOOOOOWD......",
        "DWWWOOOOOOOOOOWWWD......",
        ".DWWWWWOOOOWWWWWD.......",
        "..DWWWWWKKWWWWWD........",
        "...DDWWWWWWWWDD.....DDD.",
        "...DOOOWWWWOOOD....DWWWD",
        ".DKDOOWWWWWWOODKD.DWWWWD",
        ".DODOOWWWWWWOODOD.DOWWOD",
        "..DDOOOWWWWOOODD..DOOOOD",
        "...DOOOOOOOOOODDDDOOOOD.",
        "...DOOOD..DOOOD.DOOOOD..",
        "...DOOD....DOOD..DDDD...",
        "...DKKD....DKKD.........",
        "...DDDD....DDDD.........",
    ], palette: foxColors)

    private static let eye = PixelSprite(["KW", "KK"], palette: foxColors.merging(["W": 0xFFFFFF]) { $1 })
    private static let closedEye = PixelSprite(["OO", "KK"], palette: foxColors)

    private static let stump = PixelSprite([
        "..DDDDDDDDDDDDDDDDDD..",
        ".DTTTTTTTTTTTTTTTTTTD.",
        "DTTRRRRRRRRRRRRRRRRTTD",
        "DBTTTTTTTTTTTTTTTTTTBD",
        "DBBBBBBBBBBBBBBBBBBBBD",
        "DBBBNBBBBBBBNBBBBBNBBD",
        "DBBBNBBBBBBBNBBBBBNBBD",
        "DBBBBBBBBBBBBBBBBBBBBD",
    ], palette: ["D": 0x4A2C1A, "T": 0xE2B07A, "R": 0xC28A55, "B": 0x8A5A34, "N": 0x6B4226])

    private static let treeRows = [
        "....CCCC....",
        "..CCCCCCCC..",
        ".CCCCCCCCCC.",
        "CCCCCCCCCCCC",
        "CCCCCCCCCCCC",
        "SCCCCCCCCCCS",
        ".SSCCCCCCSS.",
        "...SSSSSS...",
        ".....TT.....",
        ".....TT.....",
    ]
    private static let orangeTree = PixelSprite(treeRows, palette: ["C": 0xE58B3A, "S": 0xC46A2A, "T": 0x6B4226])
    private static let redTree = PixelSprite(treeRows, palette: ["C": 0xD0533A, "S": 0xA83E2C, "T": 0x6B4226])
    private static let yellowTree = PixelSprite(treeRows, palette: ["C": 0xEBC14E, "S": 0xC99A30, "T": 0x6B4226])
    private static let nightTree = PixelSprite(treeRows, palette: ["C": 0x2E3552, "S": 0x262B45, "T": 0x1F2238])

    private static let trees: [(sprite: PixelSprite, x: Int)] = [
        (orangeTree, -4), (yellowTree, 5), (redTree, 38), (yellowTree, 47), (orangeTree, 56),
    ]

    private struct Leaf {
        let x: Int
        let offset: Int
        let speed: Double
        let left: PixelSprite
        let right: PixelSprite

        init(x: Int, offset: Int, speed: Double, color: UInt) {
            self.x = x
            self.offset = offset
            self.speed = speed
            left = PixelSprite(["LL", "L."], palette: ["L": color])
            right = PixelSprite(["LL", ".L"], palette: ["L": color])
        }
    }

    private static let leaves = [
        Leaf(x: 6, offset: 8, speed: 3, color: 0xE58B3A),
        Leaf(x: 40, offset: 2, speed: 2.5, color: 0xD0533A),
        Leaf(x: 50, offset: 20, speed: 3.5, color: 0xEBC14E),
        Leaf(x: 60, offset: 11, speed: 2.8, color: 0xD0533A),
    ]

    private static let butterflyOpen = PixelSprite(["PP.PP", ".PBP.", "PP.PP"], palette: ["P": 0x9B6FD8, "B": 0x2A1A14])
    private static let butterflyClosed = PixelSprite(["..B..", ".PBP.", "..B.."], palette: ["P": 0x9B6FD8, "B": 0x2A1A14])
}

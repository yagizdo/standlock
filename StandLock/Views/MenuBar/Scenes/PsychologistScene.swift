import SwiftUI
import StandLockCore

/// A psychologist taking notes in a therapy armchair, tissues and tea on the side table and a
/// calico cat asleep on the rug. Now and then, and while a break waits, the notes stop for a
/// daydream of a cook. At a break the psychologist gets up to pet the cat, paused is an evening read, and with nothing
/// scheduled the psychologist dozes off with the cat on their lap.
struct PsychologistScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused || look == .noSchedules }

    /// 0 to 1: the daydream cloud. While working: 10 s of notes, then 7 s of daydream.
    private var daydream: Double {
        switch look {
        case .breakWaiting:
            return 1
        case .working:
            guard let time else { return 0 }
            let phase = time.truncatingRemainder(dividingBy: 17)
            return phase < 10 ? 0 : min(1, (phase - 10) / 0.6, (17 - phase) / 0.6)
        default:
            return 0
        }
    }

    private let skin: UInt = 0xF1CDB3
    private let sweater: UInt = 0xF1E6D2
    private let jeans: UInt = 0x343B4A
    private let chairX: CGFloat = 112

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x2E2A3A : 0xE9DCCB)
            Path { path in
                for x in stride(from: 0.0, through: 256, by: 24) {
                    path.addRect(CGRect(x: x, y: 0, width: 6, height: 112))
                }
            }
            .fill(Color(hex: isNight ? 0x332E40 : 0xEFE4D6))
            if isNight {
                RadialGradient(colors: [Color(hex: 0xFFE7A8, opacity: 0.2), .clear], center: .center, startRadius: 10, endRadius: 100)
                    .frame(width: 220, height: 160).position(x: chairX + 10, y: 70)
            }
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0xB07A4A)).frame(height: 24).position(x: 128, y: 124)
            Rectangle().fill(Color(hex: isNight ? 0x3A2E26 : 0x8A5A33)).frame(height: 3).position(x: 128, y: 113)
            Ellipse().fill(Color(hex: isNight ? 0x5A3E3A : 0xC9785A)).frame(width: 170, height: 16).position(x: 112, y: 123)
            diploma
            clock
            plant
            sideTable
            chairBack
            if look == .timeToStand {
                chairFront
                cat(awake: true, purring: true).position(x: 100, y: 113)
                SceneStander(head: head, top: sweater, pants: jeans, rightHand: CGPoint(x: 84, y: 94))
                    .position(x: 52, y: 116 - 58)
                hearts
            } else {
                sittingPerson
                chairFront
                Capsule().fill(Color(hex: jeans)).frame(width: 64, height: 18).position(x: chairX, y: 101)
                lap
                if look != .noSchedules {
                    cat(awake: look == .breakSoon, purring: false).position(x: 36, y: 115)
                }
            }
            switch look {
            case .noSchedules:
                SceneBubble(text: "z z").position(x: 168, y: 34)
            case .working, .breakWaiting:
                if daydream > 0 {
                    daydreamCloud.opacity(daydream)
                }
            case .breakSoon, .timeToStand, .paused:
                EmptyView()
            }
        }
    }

    // MARK: - Person

    private var head: SceneHead {
        let eyes: SceneHead.Eyes
        let mouth: SceneHead.Mouth
        switch look {
        case .noSchedules: eyes = .closed; mouth = .smile
        case .timeToStand: eyes = .happy; mouth = .grin
        case .breakSoon: eyes = .open(lookingUp: true); mouth = .open
        case .working, .breakWaiting, .paused:
            eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: daydream > 0.5); mouth = .smile
        }
        return SceneHead(hair: .wavy, hairColor: 0x2B1E1A, skin: skin, eyes: eyes, mouth: mouth, earring: true)
    }

    private var sittingPerson: some View {
        ZStack {
            SceneTop(color: sweater).frame(width: 56, height: 38).position(x: chairX, y: 86)
            head.rotationEffect(.degrees(look == .noSchedules ? 12 : 0), anchor: .bottom).position(x: chairX, y: 46)
        }
    }

    /// What rests on the lap: notes while working, a book in the evening, the cat at night.
    @ViewBuilder private var lap: some View {
        switch look {
        case .working, .breakSoon:
            notebook(open: true).position(x: chairX - 2, y: 93)
            hand.position(x: chairX - 22, y: 96)
            pen
        case .breakWaiting:
            notebook(open: false).position(x: chairX - 2, y: 94)
            hand.position(x: chairX - 18, y: 96)
            hand.position(x: chairX + 14, y: 96)
        case .paused:
            book.position(x: chairX, y: 86)
        case .noSchedules:
            cat(awake: false, purring: false).position(x: chairX, y: 92)
        case .timeToStand:
            EmptyView()
        }
    }

    private var hand: some View {
        Circle().fill(Color(hex: skin)).frame(width: 10, height: 10)
    }

    /// The pen scribbles across the page while working and lifts when a break is near.
    private var pen: some View {
        let writing = look == .working && time != nil && daydream == 0
        let tip = writing
            ? CGPoint(x: chairX + 2 + CGFloat(sin(tick * 1.3)) * 8, y: 92 + CGFloat(sin(tick * 14)) * 1)
            : CGPoint(x: chairX + 10, y: 80)
        return ZStack {
            Path { path in
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x + 10, y: tip.y - 12))
            }
            .stroke(Color(hex: 0x3F5E8C), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            hand.position(x: tip.x + 6, y: tip.y - 5)
        }
    }

    private func notebook(open: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x6A4E8A)).frame(width: 42, height: 26)
            if open {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xFBF6EA)).frame(width: 38, height: 22)
                ForEach(0..<4, id: \.self) { line in
                    Capsule().fill(Color(hex: 0x9FB4CC)).frame(width: line == 3 ? 16 : 28, height: 1.2)
                        .offset(x: line == 3 ? -6 : 0, y: CGFloat(line) * 4.5 - 7)
                }
            } else {
                Capsule().fill(Color(hex: 0xF2C94C)).frame(width: 14, height: 3).offset(y: -5)
            }
        }
        .rotationEffect(.degrees(-6))
    }

    private var book: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x8A3A4A)).frame(width: 46, height: 28)
            Rectangle().fill(Color(hex: 0x5A2232)).frame(width: 2.5, height: 28)
            Capsule().fill(Color(hex: 0xF2C94C)).frame(width: 12, height: 3).offset(x: 11, y: -4)
            hand.offset(x: -24, y: 2)
            hand.offset(x: 24, y: 2)
        }
    }

    // MARK: - Cat

    private let catWhite = Color(hex: 0xFBF7F1)
    private let catGinger = Color(hex: 0xDB8F48)
    private let catTabby = Color(hex: 0x8C7A68)
    private let catDark = Color(hex: 0x3A2F28)

    /// A small long-haired calico: curled up asleep, or sitting up with the tail swaying. White
    /// chest, ginger and tabby back, the face split ginger and tabby by a white blaze.
    @ViewBuilder private func cat(awake: Bool, purring: Bool) -> some View {
        if awake {
            let sway = time.map { CGFloat(sin($0 * 2)) * 4 } ?? 0
            ZStack {
                catTail(from: CGPoint(x: 8, y: 14), to: CGPoint(x: 24 + sway, y: -6))
                CatFluff(bumps: 14, depth: 0.12).fill(catTabby).frame(width: 22, height: 26).offset(x: 6, y: 3)
                CatFluff(bumps: 10, depth: 0.14).fill(catGinger).frame(width: 14, height: 16).offset(x: 10, y: 8)
                CatFluff(bumps: 16, depth: 0.1).fill(catWhite).frame(width: 25, height: 27).offset(x: -2, y: 5)
                catHead(eyesClosed: purring).offset(x: -2, y: -12)
            }
        } else {
            ZStack {
                catTail(from: CGPoint(x: 18, y: 6), to: CGPoint(x: -10, y: 11))
                CatFluff(bumps: 22, depth: 0.08).fill(catWhite).frame(width: 46, height: 25)
                CatFluff(bumps: 14, depth: 0.12).fill(catGinger).frame(width: 24, height: 16).offset(x: 2, y: -4)
                CatFluff(bumps: 12, depth: 0.12).fill(catTabby).frame(width: 20, height: 15).offset(x: 13, y: -2)
                CatFluff(bumps: 8, depth: 0.16).fill(catDark).frame(width: 9, height: 7).offset(x: 9, y: -6)
                catHead(eyesClosed: true).offset(x: -15, y: 1)
            }
        }
    }

    private func catTail(from start: CGPoint, to end: CGPoint) -> some View {
        let path = Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: end.x + 6, y: start.y + 2))
        }
        return ZStack {
            path.stroke(catTabby, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            path.stroke(catGinger, style: StrokeStyle(lineWidth: 9, dash: [5, 6]))
            path.stroke(catDark.opacity(0.5), style: StrokeStyle(lineWidth: 9, dash: [1.5, 9.5], dashPhase: 3))
        }
        .frame(width: 1, height: 1)
    }

    private func catHead(eyesClosed: Bool) -> some View {
        let ink = Color(hex: 0x2E2430)
        return ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                let ear = Path { path in
                    path.move(to: CGPoint(x: 12 + side * 10, y: 11))
                    path.addLine(to: CGPoint(x: 12 + side * 9, y: 0))
                    path.addLine(to: CGPoint(x: 12 + side * 2, y: 5))
                    path.closeSubpath()
                }
                ear.fill(side < 0 ? catGinger : catTabby)
                Path { path in
                    path.move(to: CGPoint(x: 12 + side * 8.5, y: 9))
                    path.addLine(to: CGPoint(x: 12 + side * 8.5, y: 3))
                    path.addLine(to: CGPoint(x: 12 + side * 4.5, y: 6))
                    path.closeSubpath()
                }
                .fill(Color(hex: 0xF2BFBC))
            }
            ZStack {
                catGinger
                catTabby.frame(width: 12).offset(x: 6)
                ForEach([-1.0, 1], id: \.self) { row in
                    Capsule().fill(catDark.opacity(0.55)).frame(width: 4, height: 1.2).offset(x: 9, y: -2 + row * 2.5)
                }
                Ellipse().fill(catDark.opacity(0.85)).frame(width: 7, height: 4).offset(x: 1, y: -9)
                Capsule().fill(catWhite).frame(width: 4, height: 11).offset(y: -1)
                Ellipse().fill(catWhite).frame(width: 16, height: 10).offset(y: 6)
            }
            .frame(width: 26, height: 22)
            .clipShape(CatFluff(bumps: 16, depth: 0.1))
            .offset(y: 2)
            ForEach([-1.0, 1], id: \.self) { side in
                Group {
                    if eyesClosed {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addQuadCurve(to: CGPoint(x: 4, y: 0), control: CGPoint(x: 2, y: 2))
                        }
                        .stroke(ink, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                        .frame(width: 4, height: 2)
                    } else {
                        ZStack {
                            Circle().fill(Color(hex: 0xA8D08E)).frame(width: 5, height: 5)
                            Capsule().fill(ink).frame(width: 1.4, height: 3.6)
                            Circle().fill(Color.white).frame(width: 1.2, height: 1.2).offset(x: 1, y: -1)
                        }
                    }
                }
                .offset(x: side * 5, y: 1)
            }
            Ellipse().fill(Color(hex: 0xF2A0A8)).frame(width: 3, height: 2.2).offset(y: 5)
        }
        .frame(width: 24, height: 24)
    }

    /// Small hearts rising from the cat while it is petted.
    private var hearts: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let rise = time.map { ($0 * 0.6 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1) } ?? Double(index) * 0.5
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: 0xE8707A).opacity(1 - rise * 0.8))
                    .position(x: 112 + CGFloat(index) * 12 + CGFloat(sin(rise * 6)) * 3, y: 92 - CGFloat(rise) * 30)
            }
        }
    }

    // MARK: - Daydream

    /// A thought cloud with a cook in a chef's hat, bubbles trailing back to the head.
    private var daydreamCloud: some View {
        let drift = time.map { CGFloat(sin($0 * 1.2)) * 1.5 } ?? 0
        // Lavender, so the white chef's hat stands out against it.
        let cloud = Color(hex: 0xE6E0F2)
        return ZStack {
            Circle().fill(cloud).frame(width: 5, height: 5).position(x: 90, y: 34)
            Circle().fill(cloud).frame(width: 8, height: 8).position(x: 82, y: 28)
            ZStack {
                ForEach(Array([(-16.0, 4.0, 26.0), (0, -6, 34), (16, 4, 26), (0, 12, 28)].enumerated()), id: \.offset) { _, puff in
                    Circle().fill(cloud).frame(width: puff.2, height: puff.2).offset(x: puff.0, y: puff.1)
                }
                SceneHead(hair: .crop, hairColor: 0x2A211D, skin: 0xEDCDB2,
                          eyes: sceneIsBlinking(time.map { $0 + 1.3 }) ? .closed : .open(lookingUp: false), mouth: .smile,
                          beard: 0xB59E8C, earring: true, chefHat: true)
                    .scaleEffect(0.46)
                    .offset(y: 8)
            }
            .position(x: 50, y: 32 + drift)
        }
    }

    // MARK: - Room

    private var chairColor: Color { Color(hex: isNight ? 0x2F5452 : 0x4F8A86) }
    private var chairShade: Color { Color(hex: isNight ? 0x264644 : 0x427774) }

    private var chairBack: some View {
        RoundedRectangle(cornerRadius: 20).fill(chairColor).frame(width: 96, height: 78).position(x: chairX, y: 68)
    }

    private var chairFront: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                RoundedRectangle(cornerRadius: 9).fill(chairColor).frame(width: 20, height: 40).position(x: chairX + side * 46, y: 90)
                Rectangle().fill(Color(hex: 0x3B2A20)).frame(width: 4, height: 6).position(x: chairX + side * 44, y: 113)
            }
            RoundedRectangle(cornerRadius: 6).fill(chairShade).frame(width: 112, height: 12).position(x: chairX, y: 106)
        }
    }

    private var sideTable: some View {
        let steaming = look != .noSchedules
        return ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                Rectangle().fill(Color(hex: 0x6A4A32)).frame(width: 3, height: 24).position(x: 196 + side * 14, y: 102)
            }
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0x5A4434 : 0x8A5E3A)).frame(width: 40, height: 5).position(x: 196, y: 89)
            // A tissue box, the one thing every therapy room has.
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0xB8BCC8 : 0xF4F1EA)).frame(width: 18, height: 12).position(x: 186, y: 81)
            Rectangle().fill(Color(hex: 0x8FB8C9).opacity(isNight ? 0.5 : 1)).frame(width: 18, height: 3).position(x: 186, y: 83)
            Path { path in
                path.move(to: CGPoint(x: 181, y: 75))
                path.addQuadCurve(to: CGPoint(x: 191, y: 75), control: CGPoint(x: 188, y: 64))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(isNight ? 0.6 : 1))
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xE08A6A)).frame(width: 10, height: 11).position(x: 206, y: 81)
            Circle().stroke(Color(hex: 0xE08A6A), lineWidth: 2).frame(width: 6, height: 6).position(x: 212, y: 81)
            if steaming {
                ForEach(0..<2, id: \.self) { index in
                    let rise = time.map { ($0 * 8 + Double(index) * 9).truncatingRemainder(dividingBy: 18) } ?? Double(index) * 9
                    Capsule().fill(Color.white.opacity(0.7 - rise / 26)).frame(width: 3, height: 7)
                        .position(x: 204 + CGFloat(index) * 4 + CGFloat(sin(rise / 4)) * 2, y: 70 - rise)
                }
            }
        }
    }

    private var diploma: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0x5A4434 : 0x8A5E33)).frame(width: 36, height: 28)
            Rectangle().fill(Color(hex: isNight ? 0x8E8878 : 0xFBF6EA)).frame(width: 30, height: 22)
            ForEach(0..<3, id: \.self) { line in
                Capsule().fill(Color(hex: 0xB8AE9C)).frame(width: line == 0 ? 18 : 22, height: 1.5).offset(y: CGFloat(line) * 4 - 6)
            }
            Circle().fill(Color(hex: 0xC4504A).opacity(isNight ? 0.6 : 1)).frame(width: 6, height: 6).offset(x: 9, y: 6)
        }
        .position(x: 222, y: 34)
    }

    private var clock: some View {
        ZStack {
            Circle().fill(Color(hex: isNight ? 0x8E8878 : 0xFBF8F2)).frame(width: 20, height: 20)
            Circle().stroke(Color(hex: 0x3A3040), lineWidth: 2).frame(width: 20, height: 20)
            Capsule().fill(Color(hex: 0x3A3040)).frame(width: 1.6, height: 7).offset(y: -3)
            Capsule().fill(Color(hex: 0x3A3040)).frame(width: 1.6, height: 5).rotationEffect(.degrees(90)).offset(x: 2)
        }
        .position(x: 172, y: 22)
    }

    private var plant: some View {
        ZStack {
            ForEach(Array([(-22.0, -14.0), (-8, -28), (8, -26), (22, -12), (0, -10)].enumerated()), id: \.offset) { _, leaf in
                Ellipse().fill(Color(hex: isNight ? 0x3E6A44 : 0x6AAE6A)).frame(width: 10, height: 22)
                    .rotationEffect(.degrees(leaf.0 * 1.6)).offset(x: leaf.0 * 0.6, y: leaf.1)
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xC9683F)).frame(width: 20, height: 18).offset(y: 6)
        }
        .position(x: 240, y: 100)
    }
}

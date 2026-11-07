import SwiftUI
import StandLockCore

/// Someone on a window seat with hot chocolate, watching the rain. When it is time to stand the
/// rain stops and a rainbow comes out; when paused they doze against the window at night.
struct RainyDayScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }
    private var isClear: Bool { look == .timeToStand }

    private let skin: UInt = 0xF5D0B0
    private let sweater: UInt = 0xB8A0D8
    private let pants: UInt = 0x6E7FA0
    private let sitterX: CGFloat = 168

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x2E2838 : 0xEAD9C6)
            Rectangle().fill(Color(hex: isNight ? 0x3E3030 : 0xB98A5A)).frame(height: 18).position(x: 128, y: 127)
            Ellipse().fill(Color(hex: isNight ? 0x3A3448 : 0xD9A0A0)).frame(width: 96, height: 12).position(x: 56, y: 126)
            plant
            curtains
            window
            lights
            seat
            if isClear {
                mug(steaming: true).position(x: 204, y: 88)
                SceneStretch(head: head, top: sweater, pants: pants, time: time).position(x: 72, y: 124 - 58)
            } else {
                if isNight {
                    mug(steaming: false).position(x: 220, y: 88)
                }
                SceneSitter(head: head, top: sweater, pants: pants, lean: isNight ? -10 : 0).position(x: sitterX, y: 120 - 46)
                blanket
                if !isNight {
                    heldMug
                }
            }
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 132, y: 30)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 206, y: 28)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 202, y: 28)
            case .working, .breakSoon, .timeToStand:
                EmptyView()
            }
        }
    }

    private var head: SceneHead {
        let eyes: SceneHead.Eyes
        let mouth: SceneHead.Mouth
        switch look {
        case .paused: eyes = .closed; mouth = .smile
        case .timeToStand: eyes = .happy; mouth = .grin
        case .breakSoon: eyes = .open(lookingUp: true); mouth = .open
        case .working, .breakWaiting, .noSchedules:
            eyes = sceneIsBlinking(time) || sipping ? .closed : .open(lookingUp: look == .noSchedules); mouth = .smile
        }
        return SceneHead(hair: .long, hairColor: 0x4A2E22, skin: skin, eyes: eyes, mouth: mouth)
    }

    private var sipping: Bool {
        look == .working && (time.map { $0.truncatingRemainder(dividingBy: 6) < 1.2 } ?? false)
    }

    private func mug(steaming: Bool) -> some View {
        ZStack {
            if steaming {
                ForEach(0..<2, id: \.self) { index in
                    let rise = time.map { ($0 * 10 + Double(index) * 8).truncatingRemainder(dividingBy: 16) } ?? Double(index) * 8
                    Capsule().fill(Color.white.opacity(0.8 - rise / 22)).frame(width: 3, height: 7)
                        .offset(x: -3 + CGFloat(index) * 6 + CGFloat(sin(rise / 4) * 1.5), y: -12 - rise)
                }
            }
            Circle().stroke(Color(hex: 0xC99A3A), lineWidth: 2.5).frame(width: 8, height: 8).offset(x: 7)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xE8C15A)).frame(width: 13, height: 13)
            Ellipse().fill(Color(hex: 0x6B4226)).frame(width: 11, height: 3).offset(y: -5.5)
        }
    }

    private var heldMug: some View {
        let y: CGFloat = sipping ? 66 : 84
        return ZStack {
            mug(steaming: false).position(x: sitterX, y: y)
            Circle().fill(Color(hex: skin)).frame(width: 10, height: 10).position(x: sitterX - 9, y: y + 3)
            Circle().fill(Color(hex: skin)).frame(width: 10, height: 10).position(x: sitterX + 9, y: y + 3)
        }
    }

    private var blanket: some View {
        ZStack {
            Capsule().fill(Color(hex: 0xF3E6D2)).frame(width: 56, height: 16)
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle().fill(Color(hex: 0x8FAF8A)).frame(width: 4, height: 16)
                }
            }
        }
        .clipShape(Capsule())
        .position(x: sitterX, y: 98)
    }

    /// The view outside, in a 126 x 74 frame.
    private var outside: some View {
        ZStack {
            Color(hex: isNight ? 0x1E2A3E : isClear ? 0xBFE3F2 : 0x9FB4C4)
            if isClear {
                ForEach(Array([0xE86A6A, 0xF2B33A, 0xF2E06A, 0x7FC47A, 0x6EA8E8].enumerated()), id: \.offset) { index, color in
                    Circle().trim(from: 0.5, to: 1).stroke(Color(hex: UInt(color)).opacity(0.8), lineWidth: 3.5)
                        .frame(width: 104 - CGFloat(index) * 7, height: 104 - CGFloat(index) * 7)
                        .position(x: 63, y: 76)
                }
                Circle().fill(Color(hex: 0xFFD95A)).frame(width: 14, height: 14).position(x: 106, y: 14)
            } else if isNight {
                Circle().fill(Color(hex: 0xF4E9C1, opacity: 0.6)).frame(width: 10, height: 10).position(x: 104, y: 14)
            }
            ForEach(Array([(14.0, 22.0), (40, 16), (66, 26), (94, 18), (118, 24)].enumerated()), id: \.offset) { index, roof in
                Rectangle().fill(Color(hex: isNight ? 0x18223A : isClear ? 0x9FB8C8 : 0x7F94A4)).frame(width: 24, height: roof.1).position(x: roof.0, y: 74 - roof.1 / 2)
                if isNight, index % 2 == 0 {
                    Rectangle().fill(Color(hex: 0xF2C94C, opacity: 0.8)).frame(width: 4, height: 4).position(x: roof.0 - 4, y: 74 - roof.1 + 7)
                }
            }
            if !isClear {
                ForEach(0..<14, id: \.self) { index in
                    let fall = CGFloat((tick * 110 + Double(index) * 23).truncatingRemainder(dividingBy: 90)) - 8
                    Capsule().fill(Color.white.opacity(isNight ? 0.35 : 0.6)).frame(width: 1.5, height: 9)
                        .position(x: CGFloat((index * 37) % 126), y: fall)
                }
            }
            if look == .breakSoon {
                let grow = time.map { ($0 * 1.2).truncatingRemainder(dividingBy: 1) } ?? 0.4
                Circle().stroke(Color.white.opacity(0.8 * (1 - grow)), lineWidth: 1.5).frame(width: 6 + grow * 18, height: 6 + grow * 18).position(x: 30, y: 18)
                Ellipse().fill(Color.white.opacity(0.85)).frame(width: 5, height: 7).position(x: 30, y: 18 + grow * 20)
            }
        }
        .frame(width: 126, height: 74)
        .clipped()
    }

    private var window: some View {
        let frame = Color(hex: isNight ? 0x6A5A70 : 0xFBF4E6)
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(frame).frame(width: 136, height: 84)
            outside
            Rectangle().fill(frame).frame(width: 4, height: 74)
            Rectangle().fill(frame).frame(width: 126, height: 4)
            Rectangle().fill(Color(hex: isNight ? 0x7A6A80 : 0xF3EBDD)).frame(width: 146, height: 6).offset(y: 44)
        }
        .position(x: 176, y: 50)
    }

    private var curtains: some View {
        ForEach([102.0, 250], id: \.self) { x in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: isNight ? 0x6A4A5A : 0xD98A7A)).frame(width: 16, height: 92)
                Capsule().fill(Color(hex: isNight ? 0x8A6A3A : 0xF2C94C)).frame(width: 18, height: 4).offset(y: 14)
            }
            .position(x: x, y: 50)
        }
    }

    private var lights: some View {
        let colors: [UInt] = [0xF2C94C, 0xE86A6A, 0x7FC47A, 0x6EA8E8]
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 106, y: 4))
                path.addQuadCurve(to: CGPoint(x: 246, y: 4), control: CGPoint(x: 176, y: 22))
            }
            .stroke(Color(hex: 0x5A4A40), lineWidth: 1)
            ForEach(0..<8, id: \.self) { index in
                let t = (Double(index) + 0.5) / 8
                let x = 106 + 140 * t
                let y = 4 + 2 * t * (1 - t) * 18
                let on = isNight || (time.map { Int($0 * 1.5 + Double(index)) % 3 != 0 } ?? true)
                if isNight {
                    Circle().fill(Color(hex: colors[index % 4], opacity: 0.3)).frame(width: 12, height: 12).position(x: x, y: y + 3)
                }
                Circle().fill(Color(hex: colors[index % 4]).opacity(on ? 1 : 0.5)).frame(width: 5, height: 5).position(x: x, y: y + 3)
            }
        }
    }

    private var seat: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: isNight ? 0x4A3A30 : 0xB98A5A)).frame(width: 152, height: 30).position(x: 176, y: 121)
            RoundedRectangle(cornerRadius: 5).fill(Color(hex: isNight ? 0x46506A : 0xC9D6E8)).frame(width: 148, height: 10).position(x: 176, y: 102)
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: isNight ? 0x6A4A50 : 0xF0B8B0)).frame(width: 22, height: 20)
                .rotationEffect(.degrees(-8)).position(x: 122, y: 90)
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: isNight ? 0x6A5A3A : 0xF2D58A)).frame(width: 22, height: 20)
                .rotationEffect(.degrees(8)).position(x: 234, y: 90)
        }
    }

    private var plant: some View {
        ZStack {
            ForEach(Array([(-30.0, 0.0), (-10, 4), (12, 2), (32, -2), (0, -6)].enumerated()), id: \.offset) { index, leaf in
                Ellipse().fill(Color(hex: isNight ? 0x2E4A34 : (index % 2 == 0 ? 0x5E9E3A : 0x6CB24A)))
                    .frame(width: 16, height: 34)
                    .rotationEffect(.degrees(leaf.0))
                    .position(x: 40 + leaf.0 * 0.6, y: 72 + leaf.1)
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: isNight ? 0x6A3A30 : 0xC9683F)).frame(width: 26, height: 24).position(x: 40, y: 108)
        }
    }
}

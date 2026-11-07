import SwiftUI
import StandLockCore

/// A cook frying a steak at the stove. The steak flips when a break is near; when it is time to
/// stand the cook steps back to stretch, and when paused they doze on a stool by a cold stove.
struct CookingScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let skin: UInt = 0xEDCDB2
    private let jacket: UInt = 0xF3F0E8
    private let scarf: UInt = 0xD9534A
    private let apron: UInt = 0xF2C94C
    private let pants: UInt = 0x3A3F4A
    /// Where the cook stands; the frame is 80 x 116 with feet at y 116.
    private let cookX: CGFloat = 104
    private let pan = CGPoint(x: 184, y: 84)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x26303A : 0xDDEBF0)
            Path { path in
                for y in stride(from: 15.0, through: 114, by: 16) { path.addRect(CGRect(x: 0, y: y, width: 256, height: 1.5)) }
                for x in stride(from: 15.0, through: 256, by: 16) { path.addRect(CGRect(x: x, y: 0, width: 1.5, height: 114)) }
            }
            .fill(Color(hex: isNight ? 0x202830 : 0xC8DCE4))
            Rectangle().fill(Color(hex: isNight ? 0x3A3440 : 0xD9C3A5)).frame(height: 22).position(x: 128, y: 125)
            shelf
            window
            stove
            skillet
            switch look {
            case .timeToStand:
                spatula(hand: CGPoint(x: 222, y: 60), angle: 1.9)
                SceneStretch(head: head, top: jacket, pants: pants, scarf: scarf, apron: apron, time: time).position(x: 92, y: 116 - 58)
            case .paused:
                stool
                SceneSitter(head: head, top: jacket, pants: pants, scarf: scarf, apron: apron, lean: 12).position(x: 70, y: 116 - 46)
            default:
                let hand = spatulaHand
                SceneStander(head: head, top: jacket, pants: pants, scarf: scarf, apron: apron,
                             rightHand: CGPoint(x: hand.x - cookX + 40, y: hand.y))
                    .position(x: cookX, y: 116 - 58)
                spatula(hand: hand, angle: look == .breakSoon ? -0.5 : 0.35)
            }
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 108, y: 16)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 144, y: 18)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 140, y: 18)
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
            eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: look == .noSchedules); mouth = .smile
        }
        return SceneHead(hair: .crop, hairColor: 0x2A211D, skin: skin, eyes: eyes, mouth: mouth,
                         beard: 0xB59E8C, earring: true, chefHat: true)
    }

    /// The hand presses the steak down while it fries, and lifts for the flip.
    private var spatulaHand: CGPoint {
        switch look {
        case .breakSoon:
            return CGPoint(x: 142, y: 62)
        case .working:
            let press = time.map { max(0, sin($0 * 4)) * 3 } ?? 0
            return CGPoint(x: 142, y: 70 + press)
        default:
            return CGPoint(x: 142, y: 70)
        }
    }

    /// A turner: a handle from the hand and a flat blade at `angle` radians below the horizontal.
    private func spatula(hand: CGPoint, angle: Double) -> some View {
        let blade = CGPoint(x: hand.x + 28 * cos(angle), y: hand.y + 28 * sin(angle))
        return ZStack {
            Path { path in
                path.move(to: hand)
                path.addLine(to: blade)
            }
            .stroke(Color(hex: 0x3A2A20), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xA8B0BC)).frame(width: 12, height: 9)
                .rotationEffect(.radians(angle)).position(blade)
        }
    }

    private var steak: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xF3E1C8)).frame(width: 32, height: 11)
            Ellipse().fill(Color(hex: 0x8A4A2E)).frame(width: 28, height: 10).offset(x: -2)
            ForEach([-8.0, 0, 8], id: \.self) { x in
                Capsule().fill(Color(hex: 0x5A2E1E)).frame(width: 2, height: 9).rotationEffect(.degrees(35)).offset(x: x - 2)
            }
        }
    }

    private var skillet: some View {
        ZStack {
            if !isNight {
                ForEach([-14.0, 0, 14], id: \.self) { x in
                    Ellipse().fill(Color(hex: 0x6EA8E8)).frame(width: 7, height: 5).position(x: pan.x + x, y: 92)
                }
            }
            Capsule().fill(Color(hex: 0x2E2E34)).frame(width: 36, height: 6).rotationEffect(.degrees(-6)).position(x: pan.x + 44, y: pan.y - 1)
            Ellipse().fill(Color(hex: 0x2E2E34)).frame(width: 66, height: 16).position(x: pan.x, y: pan.y + 2)
            Ellipse().fill(Color(hex: 0x45454C)).frame(width: 58, height: 10).position(x: pan.x, y: pan.y)
            if !isNight {
                if look == .breakSoon {
                    let p = time.map { ($0 / 1.2).truncatingRemainder(dividingBy: 1) } ?? 0.5
                    steak.rotationEffect(.degrees(p * 360))
                        .position(x: pan.x, y: pan.y - 3 - CGFloat(sin(p * .pi)) * 36)
                } else {
                    steak.position(x: pan.x, y: pan.y - 3)
                }
                sizzle
            }
        }
    }

    private var sizzle: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let phase = (tick * 2.2 + Double(index) * 0.37).truncatingRemainder(dividingBy: 1)
                Circle().fill(Color(hex: 0xFFF3B0).opacity(1 - phase)).frame(width: 2.5, height: 2.5)
                    .position(x: pan.x - 22 + CGFloat(index) * 11 + CGFloat(sin(phase * 6)) * 2, y: pan.y - 6 - CGFloat(phase) * 12)
            }
            ForEach(0..<2, id: \.self) { index in
                let rise = time.map { ($0 * 10 + Double(index) * 13).truncatingRemainder(dividingBy: 26) } ?? Double(index) * 13
                Capsule().fill(Color.white.opacity(0.8 - rise / 32)).frame(width: 5, height: 11)
                    .position(x: pan.x - 8 + CGFloat(index) * 16 + CGFloat(sin(rise / 5) * 3), y: pan.y - 16 - rise)
            }
        }
    }

    private var stove: some View {
        ZStack {
            Rectangle().fill(Color(hex: isNight ? 0x4A505A : 0xE9EEF2)).frame(width: 104, height: 46).position(x: 186, y: 114)
            Rectangle().fill(Color(hex: 0x3A3F4A)).frame(width: 108, height: 6).position(x: 186, y: 92)
            ForEach([-30.0, -18, 18, 30], id: \.self) { x in
                Circle().fill(Color(hex: 0x3A3F4A)).frame(width: 6, height: 6).position(x: 186 + x, y: 101)
            }
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x3A3F4A)).frame(width: 70, height: 20).position(x: 186, y: 120)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: isNight ? 0x2A2E36 : 0x5A6270)).frame(width: 60, height: 12).position(x: 186, y: 121)
        }
    }

    private var shelf: some View {
        ZStack {
            Rectangle().fill(Color(hex: isNight ? 0x5A4434 : 0xA8743F)).frame(width: 76, height: 5).position(x: 50, y: 34)
            ForEach(Array([(0xE08A3A, 24.0), (0x5E9E6A, 44), (0xF2C94C, 64), (0xD9534A, 80)].enumerated()), id: \.offset) { _, jar in
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(isNight ? 0.2 : 0.55)).frame(width: 14, height: 18).position(x: jar.1, y: 22)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: UInt(jar.0)).opacity(isNight ? 0.5 : 1)).frame(width: 10, height: 10).position(x: jar.1, y: 25)
                Capsule().fill(Color(hex: 0x6E6458)).frame(width: 12, height: 3).position(x: jar.1, y: 12)
            }
        }
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: isNight ? 0x5A6270 : 0xFBF8F2)).frame(width: 56, height: 40)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0x1F2A48 : 0xBFE3F2)).frame(width: 48, height: 32)
            if isNight {
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 9, height: 9).offset(x: 12, y: -6)
            }
            Rectangle().fill(Color(hex: isNight ? 0x5A6270 : 0xFBF8F2)).frame(width: 3, height: 32)
        }
        .position(x: 214, y: 28)
    }

    private var stool: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                Rectangle().fill(Color(hex: 0x3E2E22)).frame(width: 4, height: 22).position(x: 70 + side * 13, y: 105)
            }
            Capsule().fill(Color(hex: 0x5A4434)).frame(width: 40, height: 6).position(x: 70, y: 95)
        }
    }
}

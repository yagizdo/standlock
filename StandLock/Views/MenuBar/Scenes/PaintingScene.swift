import SwiftUI
import StandLockCore

/// A painter on a stool at an easel. When it is time to stand they get up to stretch; when paused
/// the canvas is covered with a cloth and they doze on the stool.
struct PaintingScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var isNight: Bool { look == .paused }

    private let skin: UInt = 0x8D5A3B
    private let smock: UInt = 0x7E9CC4
    private let pants: UInt = 0x5A4A40
    private let shoulder = CGPoint(x: 120, y: 60)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x2A2740 : 0xE9E2F2)
            window
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0xB98A5A)).frame(height: 24).position(x: 128, y: 124)
            Rectangle().fill(Color(hex: isNight ? 0x3A2E26 : 0x9A6A3E)).frame(height: 3).position(x: 128, y: 113)
            jars
            easel
            stool
            if look == .timeToStand {
                SceneStretch(head: head, top: smock, pants: pants, time: time).position(x: 100, y: 112 - 58)
            } else {
                if !isNight {
                    palette
                }
                SceneSitter(head: head, top: smock, pants: pants, lean: isNight ? 12 : 0).position(x: 100, y: 66)
                if !isNight {
                    brushArm
                }
            }
            if look == .breakSoon {
                drip
            }
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 134, y: 16)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 130, y: 12)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 126, y: 12)
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
        case .breakSoon: eyes = .open(lookingUp: false); mouth = .open
        case .working, .breakWaiting, .noSchedules:
            eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: look == .noSchedules); mouth = .smile
        }
        return SceneHead(hair: .beret(0xC4504A), hairColor: 0x2E2430, skin: skin, eyes: eyes, mouth: mouth)
    }

    /// Radians from the shoulder to the hand; dabs at the canvas while working.
    private var armAngle: Double {
        guard look == .working, let time else { return -0.25 }
        return -0.25 + sin(time * 5) * 0.14
    }

    private var hand: CGPoint {
        CGPoint(x: shoulder.x + 24 * cos(armAngle), y: shoulder.y + 24 * sin(armAngle))
    }

    private var brushTip: CGPoint {
        CGPoint(x: hand.x + 16 * cos(armAngle - 0.35), y: hand.y + 16 * sin(armAngle - 0.35))
    }

    private var brushArm: some View {
        ZStack {
            Path { path in
                path.move(to: shoulder)
                path.addLine(to: hand)
            }
            .stroke(Color(hex: smock), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Path { path in
                path.move(to: hand)
                path.addLine(to: brushTip)
            }
            .stroke(Color(hex: 0x8A5E33), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            Circle().fill(Color(hex: 0xD9534A)).frame(width: 5, height: 5).position(brushTip)
            Circle().fill(Color(hex: skin)).frame(width: 10, height: 10).position(hand)
        }
    }

    private var palette: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xE9C99A)).frame(width: 28, height: 18)
            ForEach(Array([0xD9534A, 0xF2C94C, 0x3F7FA8, 0x5E9E6A].enumerated()), id: \.offset) { index, color in
                Circle().fill(Color(hex: UInt(color))).frame(width: 5, height: 5)
                    .offset(x: -8 + CGFloat(index) * 5.5, y: index % 2 == 0 ? -3 : 2)
            }
            Circle().fill(Color(hex: skin)).frame(width: 10, height: 10).offset(x: 10, y: 6)
        }
        .position(x: 72, y: 74)
    }

    private var drip: some View {
        let fall = time.map { ($0 * 60).truncatingRemainder(dividingBy: 70) } ?? 30
        let start = brushTip
        return ZStack {
            Ellipse().fill(Color(hex: 0xD9534A)).frame(width: 14, height: 4).position(x: start.x, y: 114)
            if start.y + fall < 112 {
                Ellipse().fill(Color(hex: 0xD9534A)).frame(width: 4, height: 6).position(x: start.x, y: start.y + 4 + fall)
            }
        }
    }

    private var easel: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 176, y: 18))
                path.addLine(to: CGPoint(x: 150, y: 112))
                path.move(to: CGPoint(x: 176, y: 18))
                path.addLine(to: CGPoint(x: 202, y: 112))
                path.move(to: CGPoint(x: 176, y: 40))
                path.addLine(to: CGPoint(x: 176, y: 108))
            }
            .stroke(Color(hex: isNight ? 0x5A4434 : 0x8A5E33), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Rectangle().fill(Color(hex: isNight ? 0x5A4434 : 0x8A5E33)).frame(width: 74, height: 5).position(x: 176, y: 80)
            if isNight {
                Path { path in
                    path.move(to: CGPoint(x: 150, y: 24))
                    path.addQuadCurve(to: CGPoint(x: 202, y: 24), control: CGPoint(x: 176, y: 16))
                    path.addLine(to: CGPoint(x: 212, y: 84))
                    path.addQuadCurve(to: CGPoint(x: 140, y: 84), control: CGPoint(x: 176, y: 90))
                    path.closeSubpath()
                }
                .fill(Color(hex: 0x8A7E70))
                ForEach([160.0, 178, 194], id: \.self) { x in
                    Capsule().fill(Color(hex: 0x6E6458)).frame(width: 2, height: 46).position(x: x, y: 56)
                }
            } else {
                ZStack {
                    Rectangle().fill(Color(hex: 0xBFE3F2))
                    Ellipse().fill(Color(hex: 0x7FB06A)).frame(width: 90, height: 30).offset(x: -10, y: 22)
                    Ellipse().fill(Color(hex: 0x5E9E6A)).frame(width: 70, height: 24).offset(x: 24, y: 26)
                    Circle().fill(Color(hex: 0xF2C94C)).frame(width: 14, height: 14).offset(x: 16, y: -10)
                }
                .frame(width: 62, height: 48)
                .clipped()
                .overlay(Rectangle().stroke(Color(hex: 0xFBF8F2), lineWidth: 3))
                .position(x: 176, y: 54)
            }
        }
    }

    private var stool: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                Rectangle().fill(Color(hex: isNight ? 0x3E2E22 : 0x7A5230)).frame(width: 4, height: 22).position(x: 100 + side * 13, y: 101)
            }
            Capsule().fill(Color(hex: isNight ? 0x5A4434 : 0xA8743F)).frame(width: 40, height: 6).position(x: 100, y: 91)
        }
    }

    private var jars: some View {
        ZStack {
            ForEach(Array([(0x3F7FA8, 222.0), (0xF2C94C, 238), (0xD9534A, 230)].enumerated()), id: \.offset) { index, jar in
                Capsule().fill(Color(hex: 0x8A5E33)).frame(width: 2, height: 16)
                    .rotationEffect(.degrees(Double(index - 1) * 12)).position(x: jar.1, y: index == 2 ? 82 : 96)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: UInt(jar.0)).opacity(isNight ? 0.5 : 1))
                    .frame(width: 12, height: 14).position(x: jar.1, y: index == 2 ? 92 : 106)
            }
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0x9A6A3E)).frame(width: 30, height: 4).position(x: 230, y: 100)
        }
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: isNight ? 0x6A5A70 : 0xFBF8F2)).frame(width: 52, height: 44)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0x1F2A48 : 0xBFE3F2)).frame(width: 44, height: 36)
            if isNight {
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 10, height: 10).offset(x: -9, y: -7)
            }
            Rectangle().fill(Color(hex: isNight ? 0x6A5A70 : 0xFBF8F2)).frame(width: 3, height: 36)
            Rectangle().fill(Color(hex: isNight ? 0x6A5A70 : 0xFBF8F2)).frame(width: 44, height: 3)
        }
        .position(x: 34, y: 34)
    }
}

import SwiftUI
import StandLockCore

/// Someone in a hammock between two trees. When it is time to stand they hop out and stretch while
/// the hammock swings; when paused they sleep in it under the stars with fireflies about.
struct HammockScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let skin: UInt = 0xD9A27A
    private let top: UInt = 0x6EA8C8
    private let pants: UInt = 0x8A6A4A

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x1F2A48 : 0xBFE3F2)
            sky
            Ellipse().fill(Color(hex: isNight ? 0x2E4A34 : 0x8CC46A)).frame(width: 380, height: 70).position(x: 128, y: 128)
            flowers
            tree(x: 22)
            tree(x: 234)
            ZStack {
                ropes
                if look != .timeToStand {
                    lyingPerson
                }
                fabric
                if look != .timeToStand {
                    feet
                }
            }
            .rotationEffect(.degrees(swing), anchor: UnitPoint(x: 0.5, y: 0.34))
            if look == .timeToStand {
                SceneStretch(head: head, top: top, pants: pants, time: time).position(x: 128, y: 126 - 58)
            }
            if look == .breakSoon {
                fallingLeaf
            }
            if isNight {
                fireflies
            }
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 112, y: 30)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 116, y: 30)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 112, y: 30)
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
        return SceneHead(hair: .short, hairColor: 0xD98A3A, skin: skin, eyes: eyes, mouth: mouth)
    }

    private var swing: Double {
        guard let time else { return 0 }
        return sin(time * 1.2) * (look == .timeToStand ? 5 : 2.5)
    }

    /// The hammock's top edge at `x`, from (62, 66) to (194, 66) sagging to 85.
    private func edge(_ x: CGFloat) -> CGFloat {
        let t = (x - 62) / 132
        return 66 + 76 * t * (1 - t)
    }

    private var ropes: some View {
        Path { path in
            path.move(to: CGPoint(x: 28, y: 44))
            path.addLine(to: CGPoint(x: 62, y: 66))
            path.move(to: CGPoint(x: 228, y: 44))
            path.addLine(to: CGPoint(x: 194, y: 66))
        }
        .stroke(Color(hex: isNight ? 0x8A7E70 : 0xE9DCC6), lineWidth: 2)
    }

    private var fabricShape: Path {
        Path { path in
            path.move(to: CGPoint(x: 62, y: 66))
            path.addQuadCurve(to: CGPoint(x: 194, y: 66), control: CGPoint(x: 128, y: 104))
            path.addQuadCurve(to: CGPoint(x: 62, y: 66), control: CGPoint(x: 128, y: 150))
            path.closeSubpath()
        }
    }

    private var fabric: some View {
        ZStack {
            fabricShape.fill(Color(hex: isNight ? 0x8A5A3A : 0xE07B39))
            Path { path in
                for x in stride(from: 62.0, through: 194, by: 16) {
                    path.addRect(CGRect(x: x, y: 60, width: 7, height: 70))
                }
            }
            .fill(Color(hex: isNight ? 0x9A8A5A : 0xF2C94C))
            .clipShape(fabricShape)
        }
    }

    private var lyingPerson: some View {
        ZStack {
            Capsule().fill(Color(hex: top)).frame(width: 84, height: 24).rotationEffect(.degrees(4)).position(x: 128, y: 80)
            head.rotationEffect(.degrees(-24)).position(x: 82, y: 56)
        }
    }

    private var feet: some View {
        ForEach([0.0, 9], id: \.self) { dx in
            Ellipse().fill(Color(hex: 0x3B2A20)).frame(width: 9, height: 13).rotationEffect(.degrees(20)).position(x: 172 + dx, y: edge(172 + dx) - 4)
        }
    }

    private var fallingLeaf: some View {
        let p = time.map { ($0 / 2.4).truncatingRemainder(dividingBy: 1) } ?? 0.6
        return Ellipse().fill(Color(hex: 0x6CB24A)).frame(width: 9, height: 5)
            .rotationEffect(.degrees(sin(p * 12) * 40))
            .position(x: 54 + p * 34 + CGFloat(sin(p * 9)) * 6, y: 26 + p * 22)
    }

    private func tree(x: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color(hex: isNight ? 0x3E2E22 : 0x8A5E33)).frame(width: 13, height: 88).position(x: x, y: 70)
            ForEach(Array([(-14.0, 10.0, 34.0), (12, 6, 38), (0, -6, 36), (-4, 22, 26)].enumerated()), id: \.offset) { _, blob in
                Circle().fill(Color(hex: isNight ? 0x24402E : 0x5E9E3A)).frame(width: blob.2, height: blob.2).position(x: x + blob.0, y: 14 + blob.1)
            }
        }
    }

    private var flowers: some View {
        ForEach(Array([(40.0, 120.0, 0xF29AB0), (96, 128, 0xFFD95A), (160, 126, 0xFFFFFF), (214, 120, 0xF29AB0), (244, 130, 0xFFD95A)].enumerated()), id: \.offset) { _, flower in
            Circle().fill(Color(hex: UInt(flower.2)).opacity(isNight ? 0.4 : 1)).frame(width: 5, height: 5).position(x: flower.0, y: flower.1)
        }
    }

    @ViewBuilder private var sky: some View {
        if isNight {
            ForEach(Array([(60.0, 12.0), (100, 30), (150, 10), (176, 36), (204, 18)].enumerated()), id: \.offset) { index, star in
                let twinkle = time.map { sin($0 * 2 + Double(index)) > 0.6 } ?? false
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: twinkle ? 3 : 2, height: twinkle ? 3 : 2).position(x: star.0, y: star.1)
            }
            Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 14, height: 14).position(x: 128, y: 18)
        } else {
            ForEach(0..<2, id: \.self) { index in
                let x = CGFloat((tick * 4 + Double(index) * 150).truncatingRemainder(dividingBy: 300)) - 20
                ZStack {
                    Capsule().fill(.white).frame(width: 30, height: 9)
                    Circle().fill(.white).frame(width: 12, height: 12).offset(x: -4, y: -4)
                }
                .position(x: x, y: 18 + CGFloat(index) * 20)
            }
        }
    }

    private var fireflies: some View {
        ForEach(0..<5, id: \.self) { index in
            let phase = tick * 0.8 + Double(index) * 1.7
            let glow = time.map { sin($0 * 3 + Double(index) * 2) > 0 } ?? (index % 2 == 0)
            Circle().fill(Color(hex: 0xF2E06A, opacity: glow ? 0.95 : 0.3)).frame(width: 4, height: 4)
                .position(x: 60 + CGFloat(index) * 34 + CGFloat(sin(phase)) * 8, y: 100 + CGFloat(cos(phase * 1.3)) * 10 - CGFloat(index % 2) * 14)
        }
    }
}

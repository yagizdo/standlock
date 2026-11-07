import SwiftUI
import StandLockCore

/// Someone fishing off the end of a jetty on a lake. When it is time to stand they jump up and
/// cheer as a fish leaps; when paused they nap with their hat over their eyes.
struct FishingScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x1F2A48 : 0xBFE3F2)
            sky
            Ellipse().fill(Color(hex: isNight ? 0x2E4A3A : 0x8FBF7A)).frame(width: 190, height: 44).position(x: 196, y: 102)
            Ellipse().fill(Color(hex: isNight ? 0x27402F : 0x7FB06A)).frame(width: 170, height: 36).position(x: 50, y: 104)
            Rectangle().fill(Color(hex: isNight ? 0x2A4A6A : 0x5BA8C8)).frame(height: 36).position(x: 128, y: 118)
            ripples
            bobber
            if look == .timeToStand {
                leapingFish
            }
            jetty
            person
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 136, y: 18)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 136, y: 16)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 130, y: 16)
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
        return SceneHead(hair: .bucketHat(0x6E9E5A), hairColor: 0x3B2A20, skin: 0xC98E62, eyes: eyes, mouth: mouth,
                         hatOverEyes: isNight)
    }

    @ViewBuilder private var person: some View {
        if look == .timeToStand {
            Path { path in
                path.move(to: CGPoint(x: 36, y: 90))
                path.addLine(to: CGPoint(x: 118, y: 86))
            }
            .stroke(Color(hex: 0x5A3A22), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            let hop: CGFloat = time.map { phase in
                let p = phase.truncatingRemainder(dividingBy: 1.6) / 1.6
                return p < 0.3 ? sin(p / 0.3 * .pi) * 3 : 0
            } ?? 0
            SceneStretch(head: head, top: 0xE07B39, pants: 0x3A4660, time: time)
                .scaleEffect(0.78, anchor: .bottom)
                .position(x: 84, y: 92 - 58 - hop)
        } else {
            SceneSitter(head: head, top: 0xE07B39, pants: 0x3A4660)
                .position(x: 92, y: 68)
            Path { path in
                path.move(to: CGPoint(x: 104, y: 86))
                path.addLine(to: CGPoint(x: 162, y: 26))
            }
            .stroke(Color(hex: 0x5A3A22), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            Circle().fill(Color(hex: 0xC98E62)).frame(width: 10, height: 10).position(x: 112, y: 78)
            Path { path in
                path.move(to: CGPoint(x: 162, y: 26))
                path.addQuadCurve(to: CGPoint(x: 204, y: 108 + bobberDip), control: CGPoint(x: 196, y: 40))
            }
            .stroke(Color.white.opacity(isNight ? 0.4 : 0.8), lineWidth: 0.8)
        }
    }

    private var bobberDip: CGFloat {
        switch look {
        case .breakSoon:
            return time.map { sin($0 * 7) > 0 ? 4 : 0 } ?? 3
        case .timeToStand:
            return 0
        default:
            return time.map { CGFloat(sin($0 * 2)) * 1.5 } ?? 0
        }
    }

    @ViewBuilder private var bobber: some View {
        if look != .timeToStand {
            let y = 112 + bobberDip
            if look == .breakSoon {
                let grow = time.map { ($0 * 1.5).truncatingRemainder(dividingBy: 1) } ?? 0.5
                Ellipse().stroke(Color.white.opacity(0.7 * (1 - grow)), lineWidth: 1.2)
                    .frame(width: 12 + grow * 26, height: 4 + grow * 6).position(x: 204, y: 114)
            }
            ZStack {
                Circle().fill(Color.white).frame(width: 9, height: 9)
                Capsule().fill(Color(hex: 0xD9534A)).frame(width: 9, height: 5).offset(y: -2)
            }
            .position(x: 204, y: y)
        }
    }

    private var leapingFish: some View {
        let p = time.map { ($0 / 1.6).truncatingRemainder(dividingBy: 1) } ?? 0.5
        let x = 178 + p * 48
        let y = 112 - sin(p * .pi) * 46
        return ZStack {
            if p > 0.85 || p < 0.1 {
                ForEach([-1.0, 1], id: \.self) { side in
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 4, height: 4)
                        .position(x: (p < 0.1 ? 178 : 226) + side * 7, y: 104)
                }
            }
            ZStack {
                Ellipse().fill(Color(hex: 0xE08A3A)).frame(width: 20, height: 10)
                Ellipse().fill(Color(hex: 0xC4703A)).frame(width: 8, height: 11).offset(x: -11)
                Circle().fill(Color(hex: 0x2E2430)).frame(width: 2.5, height: 2.5).offset(x: 6, y: -1)
            }
            .rotationEffect(.degrees(-50 + p * 100))
            .position(x: x, y: y)
        }
    }

    private var ripples: some View {
        ForEach(0..<4, id: \.self) { index in
            let drift = CGFloat((tick * 6 + Double(index) * 70).truncatingRemainder(dividingBy: 280)) - 12
            Capsule().fill(Color.white.opacity(isNight ? 0.15 : 0.4)).frame(width: 18, height: 2)
                .position(x: drift, y: 108 + CGFloat(index % 2) * 14 + CGFloat(index) * 2)
        }
    }

    private var jetty: some View {
        ZStack {
            ForEach([14.0, 56, 100], id: \.self) { x in
                Rectangle().fill(Color(hex: isNight ? 0x3E2E22 : 0x7A5230)).frame(width: 7, height: 40).position(x: x, y: 116)
            }
            Rectangle().fill(Color(hex: isNight ? 0x5A4434 : 0xA8743F)).frame(width: 118, height: 8).position(x: 59, y: 96)
            Rectangle().fill(Color(hex: isNight ? 0x6A5240 : 0xC4925C)).frame(width: 118, height: 2).position(x: 59, y: 93)
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x8A94A6)).frame(width: 18, height: 16)
                Capsule().fill(Color(hex: 0x6A7486)).frame(width: 20, height: 3).offset(y: -8)
            }
            .position(x: 24, y: 84)
        }
    }

    @ViewBuilder private var sky: some View {
        if isNight {
            ForEach(Array([(30.0, 14.0), (70, 30), (120, 12), (160, 38), (186, 16), (246, 40)].enumerated()), id: \.offset) { index, star in
                let twinkle = time.map { sin($0 * 2 + Double(index)) > 0.6 } ?? false
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: twinkle ? 3 : 2, height: twinkle ? 3 : 2).position(x: star.0, y: star.1)
            }
            Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 16, height: 16).position(x: 220, y: 24)
            Capsule().fill(Color(hex: 0xF4E9C1, opacity: 0.35)).frame(width: 20, height: 2).position(x: 220, y: 106)
        } else {
            Circle().fill(Color(hex: 0xFFD95A)).frame(width: 22, height: 22).position(x: 222, y: 24)
            ForEach(0..<2, id: \.self) { index in
                let x = CGFloat((tick * 4 + Double(index) * 140).truncatingRemainder(dividingBy: 300)) - 20
                ZStack {
                    Capsule().fill(.white).frame(width: 34, height: 10)
                    Circle().fill(.white).frame(width: 14, height: 14).offset(x: -4, y: -5)
                }
                .position(x: x, y: 20 + CGFloat(index) * 18)
            }
        }
    }
}

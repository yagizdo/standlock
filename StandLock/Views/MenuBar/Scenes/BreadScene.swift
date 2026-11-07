import SwiftUI
import StandLockCore

/// A loaf of bread with a face on a bakery counter beside a brick oven. It grows legs and hops
/// when it is time to stand, and sleeps under a tea towel when paused.
struct BreadScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let ink = Color(hex: 0x3B2418)
    private let crust = Color(hex: 0xD38F4A)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x3A3245 : 0xF4E1C1)
            Path { path in
                for x in stride(from: 0.0, through: 256, by: 22) {
                    path.addRect(CGRect(x: x, y: 0, width: 11, height: 100))
                }
            }
            .fill(Color(hex: isNight ? 0x352E40 : 0xEFD8B4))
            window
            oven
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0xA8743F)).frame(height: 36).position(x: 128, y: 118)
            Rectangle().fill(Color(hex: isNight ? 0x5E4A3C : 0xCC9A5E)).frame(height: 6).position(x: 128, y: 102)
            Ellipse().fill(Color(hex: isNight ? 0x5A4A40 : 0xE9C99A)).frame(width: 118, height: 12).position(x: 124, y: 101)
            timer
            if look == .timeToStand {
                Ellipse().fill(Color.black.opacity(0.12)).frame(width: 70 - hop * 1.5, height: 6).position(x: 124, y: 104)
            }
            loafGroup
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 178, y: 38)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 174, y: 26)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 168, y: 26)
            case .working, .breakSoon, .timeToStand:
                EmptyView()
            }
        }
    }

    private var hop: CGFloat {
        guard look == .timeToStand else { return 0 }
        guard let time else { return 10 }
        let p = time.truncatingRemainder(dividingBy: 1.1) / 1.1
        return p < 0.5 ? sin(p / 0.5 * .pi) * 16 : 0
    }

    /// A slow rise while it proofs, anchored at the bottom.
    private var rise: CGFloat {
        guard look == .working, let time else { return 1 }
        return 1 + CGFloat(sin(time * 1.4)) * 0.035
    }

    private var loafGroup: some View {
        let standing = look == .timeToStand
        let lift = hop + (standing ? 8 : 0)
        return ZStack {
            if standing {
                HStack(spacing: 18) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(spacing: -2) {
                            Capsule().fill(ink).frame(width: 5, height: 11)
                            Ellipse().fill(ink).frame(width: 10, height: 5)
                        }
                    }
                }
                .position(x: 124, y: 102)
            }
            ZStack {
                LoafShape().fill(crust)
                LoafShape().fill(Color(hex: 0xE8B272)).frame(height: 18).frame(maxHeight: .infinity, alignment: .bottom).clipped()
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(Color(hex: 0xF5D597)).frame(width: 7, height: 22)
                        .rotationEffect(.degrees(35))
                        .position(x: 30 + CGFloat(index) * 18, y: 17 + CGFloat(index == 1 ? -3 : 0))
                }
                Capsule().fill(Color.white.opacity(0.3)).frame(width: 14, height: 4).rotationEffect(.degrees(-28)).position(x: 18, y: 18)
                if isNight {
                    towel
                }
                face.position(x: 48, y: 37)
            }
            .frame(width: 96, height: 58)
            .scaleEffect(x: 1, y: rise, anchor: .bottom)
            .position(x: 124, y: 71)
        }
        .offset(y: -lift)
    }

    private var face: SceneFace {
        let eyes: SceneFace.Eyes
        let mouth: SceneFace.Mouth
        switch look {
        case .paused: eyes = .closed; mouth = .smile
        case .timeToStand: eyes = .happy; mouth = .grin
        case .breakSoon: eyes = .open(lookingUp: true); mouth = .open
        case .working, .breakWaiting, .noSchedules:
            eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: false); mouth = .smile
        }
        return SceneFace(eyes: eyes, mouth: mouth, eyeSpacing: 20, blushSpacing: 32)
    }

    /// A checked tea towel tucked over the loaf for the night.
    private var towel: some View {
        ZStack {
            Color(hex: 0x7E9CC4)
            Path { path in
                for x in stride(from: 4.0, through: 104, by: 12) {
                    path.addRect(CGRect(x: x, y: 0, width: 5, height: 60))
                }
                for y in stride(from: 4.0, through: 60, by: 12) {
                    path.addRect(CGRect(x: 0, y: y, width: 104, height: 5))
                }
            }
            .fill(Color(hex: 0xA9C0DE, opacity: 0.8))
        }
        .clipShape(LoafShape())
        .mask(VStack(spacing: 0) {
            Rectangle().frame(height: 31)
            Spacer(minLength: 0)
        })
        .padding(.horizontal, -3)
        .padding(.top, -3)
    }

    private var oven: some View {
        ZStack {
            ArchShape().fill(Color(hex: isNight ? 0x6A3A34 : 0xB9583F)).frame(width: 66, height: 82)
            Path { path in
                for row in 0..<6 {
                    let y = CGFloat(row) * 13 + 22
                    path.addRect(CGRect(x: 2, y: y, width: 62, height: 2))
                    for column in 0..<4 {
                        let x = CGFloat(column) * 16 + (row % 2 == 0 ? 8 : 16)
                        path.addRect(CGRect(x: x, y: y + 2, width: 2, height: 11))
                    }
                }
            }
            .fill(Color(hex: isNight ? 0x5A302C : 0x9A4430))
            .frame(width: 66, height: 82)
            .clipShape(ArchShape())
            ArchShape().fill(Color(hex: 0x2E1C18)).frame(width: 34, height: 30).offset(y: 18)
            if !isNight {
                let flicker = time.map { 0.75 + sin($0 * 9) * 0.12 } ?? 0.8
                Ellipse().fill(Color(hex: 0xF29B4A, opacity: flicker)).frame(width: 24, height: 10).offset(y: 28)
                Ellipse().fill(Color(hex: 0xFFD27A, opacity: flicker)).frame(width: 12, height: 5).offset(y: 29)
            }
        }
        .position(x: 38, y: 58)
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: isNight ? 0x6A5A70 : 0xFFF6E6)).frame(width: 52, height: 42)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: isNight ? 0x1F2A48 : 0xBFE3F2)).frame(width: 44, height: 34)
            if isNight {
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 10, height: 10).offset(x: 10, y: -7)
            } else {
                Capsule().fill(.white).frame(width: 18, height: 7).offset(x: -6 + CGFloat(sin(tick * 0.3)) * 4, y: -6)
            }
            Rectangle().fill(Color(hex: isNight ? 0x6A5A70 : 0xFFF6E6)).frame(width: 3, height: 34)
            Rectangle().fill(Color(hex: isNight ? 0x6A5A70 : 0xFFF6E6)).frame(width: 44, height: 3)
        }
        .position(x: 214, y: 36)
    }

    private var timer: some View {
        let ringing = look == .breakSoon
        let wobble = ringing ? (time.map { sin($0 * 40) * 14 } ?? 10) : 0
        return ZStack {
            if ringing {
                ForEach([-1.0, 1], id: \.self) { side in
                    Path { path in
                        let center = CGPoint(x: 30, y: 20)
                        path.addArc(center: center, radius: 17, startAngle: .degrees(-30), endAngle: .degrees(30), clockwise: false)
                        path.move(to: CGPoint(x: 30 + 22 * cos(.pi / 7.2), y: 20 - 22 * sin(.pi / 7.2)))
                        path.addArc(center: center, radius: 22, startAngle: .degrees(-25), endAngle: .degrees(25), clockwise: false)
                    }
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: 60, height: 40)
                    .scaleEffect(x: side, y: 1)
                }
            }
            ZStack {
                Capsule().fill(Color(hex: 0x5B4A40)).frame(width: 8, height: 4).offset(y: -13)
                Circle().fill(Color(hex: 0xF2C94C)).frame(width: 24, height: 24)
                Circle().fill(Color(hex: 0xFFF6E0)).frame(width: 16, height: 16)
                Capsule().fill(Color(hex: 0xD9534A)).frame(width: 2, height: 7).offset(y: -3)
            }
            .rotationEffect(.degrees(wobble))
        }
        .position(x: 212, y: 92)
    }
}

/// A loaf: flat base with soft corners, domed top.
private struct LoafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corner: CGFloat = 10
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - corner), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.maxX + 2, y: rect.minY + rect.height * 0.2),
                      control2: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner),
                      control1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY),
                      control2: CGPoint(x: rect.minX - 2, y: rect.minY + rect.height * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A brick oven front: straight sides, a round top.
private struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

import SwiftUI
import StandLockCore

/// A calico cat on a sofa.
struct CatScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private let white = Color(hex: 0xFBF7F1)
    private let ginger = Color(hex: 0xDB9550)
    private let tabby = Color(hex: 0x8C7A68)
    private let dark = Color(hex: 0x3A2F28)

    /// The tail's sway, zero for a still scene.
    private var sway: CGFloat {
        guard let time else { return 0 }
        return CGFloat(sin(time * 1.7)) * 7
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xEFE7DC), Color(hex: 0xE6DBCC)], startPoint: .top, endPoint: .bottom)
            curtain
            sofa
            switch look {
            case .working: sitting(eyes: .calm)
            case .breakSoon: sitting(eyes: .wide)
            case .timeToStand: standing
            case .paused: sleeping
            case .breakWaiting: sitting(eyes: .aside)
            case .noSchedules: sitting(eyes: .calm, tilt: 10)
            }
            blanket
            switch look {
            case .paused: SceneBubble(text: "z z").position(x: 206, y: 30)
            case .breakWaiting: SceneBubble(text: "...").position(x: 44, y: 30)
            case .noSchedules: SceneBubble(text: "?").position(x: 44, y: 30)
            case .working, .breakSoon, .timeToStand: EmptyView()
            }
        }
    }

    // MARK: - Room

    private var curtain: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule().fill(.white.opacity(0.28)).frame(width: 8)
            }
        }
        .frame(height: 136)
        .position(x: 28, y: 50)
    }

    private var sofa: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(hex: 0xCFC2AE))
            .frame(width: 290, height: 70)
            .position(x: 128, y: 112)
    }

    private var blanket: some View {
        ZStack {
            Rectangle().fill(Color(hex: 0xFAF3EA)).frame(height: 18).position(x: 128, y: 127)
            ForEach(Array(flowers.enumerated()), id: \.offset) { _, flower in
                Circle().fill(flower.color).frame(width: flower.size, height: flower.size).position(x: flower.x, y: flower.y)
            }
        }
    }

    private var flowers: [(x: CGFloat, y: CGFloat, size: CGFloat, color: Color)] {
        let pink = Color(hex: 0xF4B8C8), mint = Color(hex: 0xA9DCCB), sun = Color(hex: 0xF5E29A)
        return [
            (18, 126, 9, pink), (40, 131, 6, mint), (66, 125, 7, sun), (92, 131, 9, mint), (118, 126, 6, pink),
            (146, 131, 8, sun), (172, 126, 9, pink), (198, 131, 6, mint), (222, 125, 8, sun), (244, 130, 9, pink),
        ]
    }

    // MARK: - Poses

    private func sitting(eyes: CatEyes, tilt: Double = 0) -> some View {
        ZStack {
            tail(from: CGPoint(x: 204, y: 122), to: CGPoint(x: 236, y: 76 + sway))
            flank
            CatFluff(bumps: 30, depth: 0.06).fill(white).frame(width: 122, height: 96).position(x: 126, y: 112)
            CatHead(eyes: eyes, time: time).scaleEffect(0.92).rotationEffect(.degrees(tilt)).position(x: 126, y: 63)
        }
    }

    /// Long calico fur along the side, with a dark patch by the shoulder.
    private var flank: some View {
        ZStack {
            CatFluff(bumps: 18, depth: 0.1).fill(dark).frame(width: 30, height: 34).position(x: 184, y: 70)
            CatFluff(bumps: 28, depth: 0.06).fill(ginger).frame(width: 104, height: 76).position(x: 178, y: 108)
            CatFluff(bumps: 22, depth: 0.07).fill(tabby).frame(width: 54, height: 42).position(x: 198, y: 100)
            CatFluff(bumps: 18, depth: 0.08).fill(dark).frame(width: 30, height: 22).position(x: 186, y: 112)
        }
    }

    private var standing: some View {
        ZStack {
            tail(from: CGPoint(x: 158, y: 124), to: CGPoint(x: 212, y: 84 + sway))
            CatFluff(bumps: 28, depth: 0.06).fill(white).frame(width: 82, height: 104).position(x: 126, y: 96)
            CatFluff(bumps: 14, depth: 0.1).fill(ginger).frame(width: 34, height: 44).position(x: 154, y: 108)
            raisedArm(from: CGPoint(x: 100, y: 78), to: CGPoint(x: 62, y: 34))
            raisedArm(from: CGPoint(x: 152, y: 78), to: CGPoint(x: 190, y: 34))
            CatHead(eyes: .calm, time: time).scaleEffect(0.72).position(x: 126, y: 54)
        }
    }

    private func raisedArm(from start: CGPoint, to end: CGPoint) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(white, style: StrokeStyle(lineWidth: 15, lineCap: .round))
    }

    private var sleeping: some View {
        ZStack {
            tail(from: CGPoint(x: 206, y: 114), to: CGPoint(x: 112, y: 122))
            CatFluff(bumps: 34, depth: 0.05).fill(white).frame(width: 164, height: 78).position(x: 142, y: 94)
            CatFluff(bumps: 26, depth: 0.06).fill(ginger).frame(width: 84, height: 50).position(x: 172, y: 82)
            CatFluff(bumps: 14, depth: 0.12).fill(tabby).frame(width: 44, height: 32).position(x: 196, y: 88)
            CatFluff(bumps: 12, depth: 0.12).fill(dark).frame(width: 22, height: 16).position(x: 176, y: 76)
            CatHead(eyes: .asleep, time: nil).scaleEffect(0.7).rotationEffect(.degrees(-12)).position(x: 88, y: 84)
        }
    }

    private func tail(from start: CGPoint, to end: CGPoint) -> some View {
        let path = Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: end.x + 8, y: start.y - 4))
        }
        return ZStack {
            path.stroke(ginger, style: StrokeStyle(lineWidth: 18, lineCap: .round))
            path.stroke(dark, style: StrokeStyle(lineWidth: 18, dash: [6, 15]))
        }
    }
}

/// An oval with soft tufts, deeper at the sides and bottom, like long fur.
struct CatFluff: Shape {
    let bumps: Int
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        func point(_ angle: CGFloat, _ scale: CGFloat) -> CGPoint {
            CGPoint(x: center.x + cos(angle) * rect.width / 2 * scale, y: center.y + sin(angle) * rect.height / 2 * scale)
        }
        let step = 2 * CGFloat.pi / CGFloat(bumps)
        var path = Path()
        path.move(to: point(0, 1 - depth))
        for bump in 0..<bumps {
            let angle = CGFloat(bump) * step
            // Sine is 1 at the bottom in a flipped view, so the top stays nearly smooth.
            let tuft = depth * (0.3 + 0.7 * (1 + sin(angle + step / 2)) / 2)
            path.addQuadCurve(to: point(angle + step, 1 - depth), control: point(angle + step * 0.7, 1 + tuft))
        }
        path.closeSubpath()
        return path
    }
}

private enum CatEyes {
    case calm, wide, aside, asleep
}

/// A wide furry face: ginger on one side, tabby on the other, a white blaze between them.
private struct CatHead: View {
    let eyes: CatEyes
    let time: TimeInterval?

    private let white = Color(hex: 0xFBF7F1)
    private let ginger = Color(hex: 0xDB9550)
    private let tabby = Color(hex: 0x8C7A68)
    private let dark = Color(hex: 0x3A2F28)
    private let pink = Color(hex: 0xF2BFBC)

    private let width: CGFloat = 112
    private let height: CGFloat = 90
    private var middle: CGFloat { width / 2 }

    var body: some View {
        ZStack {
            ear(tip: CGPoint(x: 15, y: -16), outer: 8, color: Color(hex: 0xC89A70))
            ear(tip: CGPoint(x: width - 15, y: -16), outer: width - 8, color: tabby)
            face
            whiskers
            features
        }
        .frame(width: width, height: height)
    }

    private func ear(tip: CGPoint, outer: CGFloat, color: Color) -> some View {
        let inward: CGFloat = outer < middle ? 1 : -1
        return ZStack {
            triangle(tip: tip, left: CGPoint(x: outer, y: 38), right: CGPoint(x: outer + inward * 42, y: 14)).fill(color)
            triangle(
                tip: CGPoint(x: tip.x + inward * 3, y: tip.y + 12),
                left: CGPoint(x: outer + inward * 7, y: 30),
                right: CGPoint(x: outer + inward * 31, y: 15)
            )
            .fill(pink)
            Path { path in
                for tuft in 0..<3 {
                    let x = outer + inward * CGFloat(9 + tuft * 6)
                    path.move(to: CGPoint(x: x, y: 28))
                    path.addLine(to: CGPoint(x: tip.x + inward * CGFloat(2 + tuft * 3), y: 4 + CGFloat(tuft) * 2))
                }
            }
            .stroke(.white.opacity(0.8), lineWidth: 0.9)
        }
    }

    private func triangle(tip: CGPoint, left: CGPoint, right: CGPoint) -> Path {
        Path { path in
            path.move(to: tip)
            path.addLine(to: left)
            path.addLine(to: right)
            path.closeSubpath()
        }
    }

    private var face: some View {
        ZStack {
            HStack(spacing: 0) {
                ginger
                tabby
            }
            ForEach(0..<4, id: \.self) { streak in
                Capsule()
                    .fill(Color(hex: 0xEDB77C))
                    .frame(width: 2.5, height: 13)
                    .rotationEffect(.degrees(Double(streak) * 8 - 18))
                    .position(x: 16 + CGFloat(streak) * 9, y: 18 + CGFloat(3 - streak) * 2)
            }
            tabbyMarks
            Ellipse().fill(dark).frame(width: 22, height: 12).position(x: 60, y: 4)
            blaze.fill(white)
            Ellipse().fill(white).frame(width: 74, height: 42).position(x: middle, y: 72)
        }
        .frame(width: width, height: height)
        .clipShape(CatFluff(bumps: 34, depth: 0.045))
    }

    /// Dark lines over the tabby side: up the forehead, and out from the eye across the cheek.
    private var tabbyMarks: some View {
        Path { path in
            for line in 0..<4 {
                let x = 68 + CGFloat(line) * 8
                path.move(to: CGPoint(x: x, y: 5 + CGFloat(line) * 2))
                path.addQuadCurve(to: CGPoint(x: x + 3, y: 22), control: CGPoint(x: x + 3, y: 13))
            }
            path.move(to: CGPoint(x: 92, y: 42))
            path.addQuadCurve(to: CGPoint(x: 110, y: 40), control: CGPoint(x: 102, y: 37))
            path.move(to: CGPoint(x: 90, y: 50))
            path.addQuadCurve(to: CGPoint(x: 108, y: 54), control: CGPoint(x: 100, y: 48))
        }
        .stroke(dark.opacity(0.8), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }

    private var blaze: Path {
        Path { path in
            path.move(to: CGPoint(x: 52, y: 4))
            path.addLine(to: CGPoint(x: 57, y: 4))
            path.addQuadCurve(to: CGPoint(x: 86, y: 66), control: CGPoint(x: 60, y: 44))
            path.addLine(to: CGPoint(x: 26, y: 66))
            path.addQuadCurve(to: CGPoint(x: 52, y: 4), control: CGPoint(x: 50, y: 44))
            path.closeSubpath()
        }
    }

    private var whiskers: some View {
        Path { path in
            for (y, end) in [(58.0, 48.0), (63.0, 62.0), (68.0, 76.0)] as [(CGFloat, CGFloat)] {
                path.move(to: CGPoint(x: 36, y: y))
                path.addLine(to: CGPoint(x: -14, y: end))
                path.move(to: CGPoint(x: width - 36, y: y))
                path.addLine(to: CGPoint(x: width + 14, y: end))
            }
        }
        .stroke(.white.opacity(0.9), lineWidth: 0.8)
    }

    private var features: some View {
        ZStack {
            eye(x: middle - 25)
            eye(x: middle + 25)
            Ellipse().fill(Color(hex: 0xA79E96).opacity(0.5)).frame(width: 16, height: 5).position(x: middle, y: 77)
            nose
            mouth
        }
    }

    private var nose: some View {
        Path { path in
            path.move(to: CGPoint(x: middle - 7, y: 56))
            path.addQuadCurve(to: CGPoint(x: middle + 7, y: 56), control: CGPoint(x: middle, y: 53))
            path.addQuadCurve(to: CGPoint(x: middle, y: 64), control: CGPoint(x: middle + 5, y: 61))
            path.addQuadCurve(to: CGPoint(x: middle - 7, y: 56), control: CGPoint(x: middle - 5, y: 61))
            path.closeSubpath()
        }
        .fill(Color(hex: 0xF0A7AC))
    }

    private var mouth: some View {
        Path { path in
            path.move(to: CGPoint(x: middle, y: 64))
            path.addLine(to: CGPoint(x: middle, y: 68))
            path.addQuadCurve(to: CGPoint(x: middle - 9, y: 69), control: CGPoint(x: middle - 4, y: 72))
            path.move(to: CGPoint(x: middle, y: 68))
            path.addQuadCurve(to: CGPoint(x: middle + 9, y: 69), control: CGPoint(x: middle + 4, y: 72))
        }
        .stroke(dark.opacity(0.6), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }

    @ViewBuilder
    private func eye(x: CGFloat) -> some View {
        if eyes == .asleep {
            Path { path in
                path.move(to: CGPoint(x: x - 9, y: 40))
                path.addQuadCurve(to: CGPoint(x: x + 9, y: 40), control: CGPoint(x: x, y: 47))
            }
            .stroke(dark, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        } else {
            let size: CGFloat = eyes == .wide ? 27 : 23
            ZStack {
                Circle().fill(dark).frame(width: size + 3, height: size + 3)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xCFE5C4), Color(hex: 0x8DB7A0)], center: .center, startRadius: 2, endRadius: size / 2))
                    .frame(width: size, height: size)
                pupil
                Circle().fill(.white).frame(width: 4, height: 4).offset(x: 4, y: -5)
            }
            .scaleEffect(y: sceneIsBlinking(time) ? 0.1 : 1)
            .position(x: x, y: 40)
        }
    }

    @ViewBuilder
    private var pupil: some View {
        let black = Color(hex: 0x1E1A17)
        switch eyes {
        case .wide: Capsule().fill(black).frame(width: 7, height: 17)
        case .aside: Capsule().fill(black).frame(width: 4.5, height: 15).offset(x: -6)
        case .calm, .asleep: Capsule().fill(black).frame(width: 4.5, height: 15)
        }
    }
}

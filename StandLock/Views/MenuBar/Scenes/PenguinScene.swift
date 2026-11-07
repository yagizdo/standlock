import SwiftUI
import StandLockCore

/// A round penguin on the ice, with snow falling.
struct PenguinScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    /// A small side to side waddle, zero for a still scene or a resting penguin.
    private var waddle: Double {
        guard let time, look == .working || look == .breakSoon else { return 0 }
        return sin(time * 2.4) * 3
    }

    /// A happy hop when it is time to stand.
    private var hop: CGFloat {
        guard look == .timeToStand else { return 0 }
        guard let time else { return 6 }
        let p = time.truncatingRemainder(dividingBy: 1.1) / 1.1
        return p < 0.45 ? sin(p / 0.45 * .pi) * 7 : 0
    }

    private var tilt: Double {
        look == .noSchedules ? 8 : 0
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x8FC3E8), Color(hex: 0xCFE8F5)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFFF1C2)).frame(width: 30, height: 30).position(x: 214, y: 30)
            mountains
            Ellipse().fill(Color(hex: 0xF4FAFD)).frame(width: 360, height: 76).position(x: 128, y: 136)
            igloo
            snow
            Ellipse().fill(Color(hex: 0x24344A, opacity: 0.12)).frame(width: 72 - hop, height: 7).position(x: 128, y: 126)
            PenguinFigure(look: look, time: time)
                .rotationEffect(.degrees(waddle + tilt), anchor: .bottom)
                .position(x: 128, y: 74 - hop)
            switch look {
            case .paused: SceneBubble(text: "z z").position(x: 74, y: 34)
            case .breakWaiting: SceneBubble(text: "...").position(x: 74, y: 34)
            case .noSchedules: SceneBubble(text: "?").position(x: 74, y: 34)
            case .working, .breakSoon, .timeToStand: EmptyView()
            }
        }
    }

    private var mountains: some View {
        Path { path in
            path.move(to: CGPoint(x: -10, y: 104))
            path.addLine(to: CGPoint(x: 42, y: 52))
            path.addLine(to: CGPoint(x: 84, y: 104))
            path.move(to: CGPoint(x: 150, y: 104))
            path.addLine(to: CGPoint(x: 206, y: 60))
            path.addLine(to: CGPoint(x: 270, y: 104))
        }
        .fill(Color(hex: 0xB4D6EA))
    }

    private var igloo: some View {
        ZStack {
            Circle().trim(from: 0.5, to: 1).fill(Color(hex: 0xFFFFFF)).frame(width: 58, height: 58)
            Circle().trim(from: 0.5, to: 1).stroke(Color(hex: 0xB9D7E8), lineWidth: 1.5).frame(width: 58, height: 58)
            Circle().trim(from: 0.5, to: 1).fill(Color(hex: 0x6E9DBB)).frame(width: 24, height: 24)
        }
        .position(x: 214, y: 118)
    }

    /// Flakes that drift down from `time`. Fixed in place in a still scene.
    private var snow: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { flake in
                let x = CGFloat((flake * 37) % 256)
                let start = Double((flake * 53) % 136)
                let y = ((time ?? 0) * (10 + Double(flake % 4) * 3) + start).truncatingRemainder(dividingBy: 136)
                Circle().fill(.white).frame(width: flake % 3 == 0 ? 3.5 : 2.4, height: flake % 3 == 0 ? 3.5 : 2.4).position(x: x, y: CGFloat(y))
            }
        }
    }
}

private struct PenguinFigure: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private let ink = Color(hex: 0x24344A)
    private let belly = Color(hex: 0xFBFBF7)
    private let beak = Color(hex: 0xF4A63B)
    private let scarf = Color(hex: 0xD9545A)

    private let width: CGFloat = 84
    private let height: CGFloat = 104

    private var flippersUp: Bool { look == .timeToStand }
    private var isWide: Bool { look == .breakSoon }

    var body: some View {
        ZStack {
            flipper(side: -1)
            flipper(side: 1)
            Ellipse().fill(ink).frame(width: width, height: height).position(x: 42, y: 52)
            Ellipse().fill(belly).frame(width: 58, height: 66).position(x: 42, y: 66)
            face
            scarfBand
            foot(x: 26)
            foot(x: 58)
        }
        .frame(width: width, height: height)
    }

    private func flipper(side: CGFloat) -> some View {
        let angle = flippersUp ? -side * 140 : -side * 22
        return Capsule()
            .fill(ink)
            .frame(width: 16, height: 46)
            .rotationEffect(.degrees(angle), anchor: .top)
            .position(x: 42 + side * 36, y: 50)
    }

    private func foot(x: CGFloat) -> some View {
        Capsule().fill(beak).frame(width: 24, height: 9).position(x: x, y: 104)
    }

    private var scarfBand: some View {
        ZStack {
            Capsule().fill(scarf).frame(width: 66, height: 9).position(x: 42, y: 50)
            Capsule().fill(scarf).frame(width: 11, height: 24).rotationEffect(.degrees(10)).position(x: 62, y: 62)
        }
    }

    private var face: some View {
        ZStack {
            Circle().fill(belly).frame(width: 30, height: 30).position(x: 28, y: 28)
            Circle().fill(belly).frame(width: 30, height: 30).position(x: 56, y: 28)
            Ellipse().fill(belly).frame(width: 34, height: 20).position(x: 42, y: 38)
            eye(x: 30)
            eye(x: 54)
            Ellipse().fill(Color(hex: 0xF29A8A, opacity: 0.75)).frame(width: 10, height: 6).position(x: 19, y: 37)
            Ellipse().fill(Color(hex: 0xF29A8A, opacity: 0.75)).frame(width: 10, height: 6).position(x: 65, y: 37)
            bill
        }
    }

    private var bill: some View {
        Path { path in
            path.move(to: CGPoint(x: 33, y: 32))
            path.addQuadCurve(to: CGPoint(x: 51, y: 32), control: CGPoint(x: 42, y: 28))
            path.addQuadCurve(to: CGPoint(x: 42, y: 42), control: CGPoint(x: 49, y: 39))
            path.addQuadCurve(to: CGPoint(x: 33, y: 32), control: CGPoint(x: 35, y: 39))
            path.closeSubpath()
        }
        .fill(beak)
    }

    @ViewBuilder
    private func eye(x: CGFloat) -> some View {
        if look == .timeToStand {
            SceneFace.eye(.happy, ink: ink).scaleEffect(1.7).position(x: x, y: 25)
        } else if look == .paused {
            Path { path in
                path.move(to: CGPoint(x: x - 6, y: 25))
                path.addQuadCurve(to: CGPoint(x: x + 6, y: 25), control: CGPoint(x: x, y: 30))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        } else {
            let size: CGFloat = isWide ? 13 : 10
            let gaze: CGFloat = look == .breakWaiting ? -2.5 : 0
            ZStack {
                Circle().fill(ink).frame(width: size, height: size).offset(x: gaze)
                Circle().fill(.white).frame(width: 3.4, height: 3.4).offset(x: gaze + 2, y: -2.5)
            }
            .scaleEffect(y: sceneIsBlinking(time) ? 0.1 : 1)
            .position(x: x, y: 25)
        }
    }
}

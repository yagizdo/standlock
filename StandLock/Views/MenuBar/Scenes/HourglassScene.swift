import SwiftUI
import StandLockCore

/// A small hourglass on a shelf. Its sand is the real progress toward the next break.
struct HourglassScene: View {
    let look: MenuSceneLook
    let progress: Double
    let time: TimeInterval?

    private var bubble: String? {
        switch look {
        case .paused: "z z"
        case .breakWaiting: "..."
        case .noSchedules: "?"
        case .working, .breakSoon, .timeToStand: nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0x2C4C86), Color(hex: 0x24406F)], startPoint: .top, endPoint: .bottom)
            WindowView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 11)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0xA8815E), Color(hex: 0x8C6A4B)], startPoint: .top, endPoint: .bottom))
                .frame(height: 30)
            PlantView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.bottom, 24)
            HourglassFigure(look: look, progress: CGFloat(progress), time: time)
                .padding(.bottom, 16)
            if let bubble {
                SceneBubble(text: bubble).offset(x: -56, y: -86)
            }
        }
    }
}

private struct HourglassFigure: View {
    let look: MenuSceneLook
    let progress: CGFloat
    let time: TimeInterval?

    private let width: CGFloat = 68
    private let height: CGFloat = 80
    private let sand = Color(hex: 0x5AA9FF)
    private let ink = Color(hex: 0x1B2437)

    private var isFlowing: Bool {
        (look == .working || look == .breakSoon) && progress > 0 && progress < 1
    }

    private var isAlarmed: Bool { look == .breakSoon || look == .breakWaiting }

    var body: some View {
        ZStack {
            arms
            ZStack(alignment: .top) {
                GlassShape().fill(Color(hex: 0xFFFFFF, opacity: 0.16))
                Rectangle()
                    .fill(sand)
                    .frame(height: height / 2 - (height / 2) * (0.20 + 0.72 * progress))
                    .offset(y: (height / 2) * (0.20 + 0.72 * progress))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(GlassShape())
                SandHeap(level: progress).fill(sand).clipShape(GlassShape())
                if isFlowing { stream }
                GlassShape().stroke(Color(hex: 0xFFFFFF, opacity: 0.75), lineWidth: 1.6)
            }
            .frame(width: width, height: height)

            face.offset(y: -height * 0.335)

            VStack {
                cap
                Spacer()
                cap
            }
            .frame(height: height + 12)

            HStack(spacing: 16) {
                foot
                foot
            }
            .offset(y: height / 2 + 9)
        }
        .frame(width: width, height: height + 18)
    }

    /// Grains that fall through the neck, or one still line.
    @ViewBuilder
    private var stream: some View {
        let length = height * 0.36
        if let time {
            ZStack(alignment: .top) {
                ForEach(0..<4, id: \.self) { grain in
                    let fall = (time * 1.1 + Double(grain) / 4).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(sand)
                        .frame(width: 2.4, height: 2.4)
                        .offset(y: length * fall)
                }
            }
            .frame(height: length, alignment: .top)
            .offset(y: height / 2)
        } else {
            Rectangle().fill(sand).frame(width: 2, height: length).offset(y: height / 2)
        }
    }

    private var arms: some View {
        Path { path in
            let y = height / 2 + 8
            let up = look == .timeToStand
            path.move(to: CGPoint(x: 16, y: y + 4))
            if up {
                path.addQuadCurve(to: CGPoint(x: -8, y: y - 30), control: CGPoint(x: -8, y: y))
            } else {
                path.addQuadCurve(to: CGPoint(x: -6, y: y + 18), control: CGPoint(x: -4, y: y + 2))
            }
            path.move(to: CGPoint(x: width - 16, y: y + 4))
            if up {
                path.addQuadCurve(to: CGPoint(x: width + 8, y: y - 30), control: CGPoint(x: width + 8, y: y))
            } else {
                path.addQuadCurve(to: CGPoint(x: width + 6, y: y + 18), control: CGPoint(x: width + 4, y: y + 2))
            }
        }
        .stroke(Color(hex: 0xE9EEF6), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        .frame(width: width, height: height)
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 3.5)
            .fill(LinearGradient(colors: [Color(hex: 0xF2F5FA), Color(hex: 0xB9C6DA)], startPoint: .top, endPoint: .bottom))
            .frame(width: width + 8, height: 7)
    }

    private var foot: some View {
        Capsule().fill(Color(hex: 0xB9C6DA)).frame(width: 13, height: 5.5)
    }

    private var face: some View {
        ZStack {
            HStack(spacing: 13) {
                if look == .paused {
                    lid
                    lid
                } else {
                    eye
                    eye
                }
            }
            HStack(spacing: 23) {
                cheek
                cheek
            }
            .offset(y: 6)
            Group {
                if isAlarmed {
                    Circle().fill(ink).frame(width: 5.5, height: 5.5)
                } else {
                    smile(width: 9)
                }
            }
            .offset(y: 8)
        }
    }

    private var cheek: some View {
        Circle().fill(Color(hex: 0xFF8FA3, opacity: 0.65)).frame(width: 6, height: 6)
    }

    private var eye: some View {
        let size: CGFloat = isAlarmed ? 9.5 : 8
        return ZStack {
            Circle().fill(ink).frame(width: size, height: size)
            Circle().fill(.white).frame(width: 2.8, height: 2.8).offset(x: 1.4, y: -1.4)
        }
        .scaleEffect(y: sceneIsBlinking(time) ? 0.12 : 1)
    }

    private var lid: some View { smile(width: 8) }

    private func smile(width: CGFloat) -> some View {
        Path { path in
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: width / 2, y: 5))
        }
        .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        .frame(width: width, height: 4)
    }
}

private struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width, height = rect.height, neck = width * 0.07, middle = width / 2
        var path = Path()
        path.move(to: CGPoint(x: width * 0.03, y: 0))
        path.addCurve(
            to: CGPoint(x: middle - neck, y: height / 2),
            control1: CGPoint(x: width * 0.03, y: height * 0.34),
            control2: CGPoint(x: middle - neck, y: height * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.03, y: height),
            control1: CGPoint(x: middle - neck, y: height * 0.62),
            control2: CGPoint(x: width * 0.03, y: height * 0.66)
        )
        path.addLine(to: CGPoint(x: width * 0.97, y: height))
        path.addCurve(
            to: CGPoint(x: middle + neck, y: height / 2),
            control1: CGPoint(x: width * 0.97, y: height * 0.66),
            control2: CGPoint(x: middle + neck, y: height * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.97, y: 0),
            control1: CGPoint(x: middle + neck, y: height * 0.38),
            control2: CGPoint(x: width * 0.97, y: height * 0.34)
        )
        path.closeSubpath()
        return path
    }
}

private struct SandHeap: Shape {
    let level: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = rect.width, height = rect.height, top = height * (1 - level * 0.40)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: top + height * 0.14 * level))
        path.addQuadCurve(
            to: CGPoint(x: width, y: top + height * 0.14 * level),
            control: CGPoint(x: width / 2, y: top - height * 0.14 * level)
        )
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

private struct PlantView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach([-34.0, -12, 12, 34], id: \.self) { angle in
                Capsule()
                    .fill(Color(hex: 0x63B58C))
                    .frame(width: 7, height: 26)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(y: -12)
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xD9A679)).frame(width: 24, height: 17)
        }
        .frame(width: 44, height: 50, alignment: .bottom)
    }
}

private struct WindowView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x9CCBF5), Color(hex: 0xD8ECFB)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFFD36B)).frame(width: 17, height: 17).offset(x: 13, y: -13)
            Ellipse().fill(Color(hex: 0x7FC39B)).frame(width: 96, height: 40).offset(x: -16, y: 26)
            Ellipse().fill(Color(hex: 0x63B58C)).frame(width: 90, height: 34).offset(x: 26, y: 30)
            Rectangle().fill(Color(hex: 0xFFFFFF, opacity: 0.8)).frame(width: 2.5)
        }
        .frame(width: 68, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0xFFFFFF, opacity: 0.8), lineWidth: 2.5))
    }
}

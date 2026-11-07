import SwiftUI
import StandLockCore

/// A coffee mug with a face on its saucer, on a café counter. It grows legs and hops when it is
/// time to stand.
struct CoffeeScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let mugColor = Color(hex: 0x5BB3B0)
    private let ink = Color(hex: 0x2E2A30)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x2E3E3A : 0x9FC1A8)
            Path { path in
                for row in 0..<7 {
                    let y = CGFloat(row) * 16 + 14
                    path.addRect(CGRect(x: 0, y: y, width: 256, height: 2))
                    for column in 0..<9 {
                        let x = CGFloat(column) * 32 + (row % 2 == 0 ? 0 : 16)
                        path.addRect(CGRect(x: x, y: y - 14, width: 2, height: 14))
                    }
                }
            }
            .fill(Color(hex: isNight ? 0x26342F : 0x8AAE94))
            shelf
            Rectangle().fill(Color(hex: isNight ? 0x4A3C30 : 0xA0703F)).frame(height: 36).position(x: 128, y: 118)
            Rectangle().fill(Color(hex: isNight ? 0x5A4A3A : 0xC4925C)).frame(height: 5).position(x: 128, y: 102)
            plate
            Ellipse().fill(Color(hex: 0xD9D0C0)).frame(width: 92, height: 14).position(x: 118, y: 100)
            Ellipse().fill(Color(hex: 0xF4EEE2)).frame(width: 84, height: 10).position(x: 118, y: 97)
            mugGroup
            switch look {
            case .breakSoon:
                let fall = time.map { ($0 * 50).truncatingRemainder(dividingBy: 56) } ?? 24
                if fall < 44 {
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 9, height: 9)
                        .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color(hex: 0xD9D0C0), lineWidth: 1))
                        .position(x: 112, y: fall)
                } else {
                    ForEach([-1.0, 1], id: \.self) { side in
                        Circle().fill(Color(hex: 0x6B4226)).frame(width: 4, height: 4).position(x: 112 + side * 10, y: 42)
                    }
                }
            case .paused:
                SceneBubble(text: "z z").position(x: 168, y: 40)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 164, y: 24)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 158, y: 24)
            case .working, .timeToStand:
                EmptyView()
            }
        }
    }

    private var hop: CGFloat {
        guard look == .timeToStand else { return 0 }
        guard let time else { return 10 }
        let p = time.truncatingRemainder(dividingBy: 1.1) / 1.1
        return p < 0.5 ? sin(p / 0.5 * .pi) * 18 : 0
    }

    private var mugGroup: some View {
        let standing = look == .timeToStand
        let lift = hop + (standing ? 8 : 0)
        return ZStack {
            if !isNight {
                ForEach(0..<3, id: \.self) { index in
                    let rise = time.map { ($0 * 14 + Double(index) * 9).truncatingRemainder(dividingBy: 30) } ?? Double(index) * 9
                    Capsule().fill(Color.white.opacity(0.85 - rise / 40)).frame(width: 4, height: 10)
                        .position(x: 104 + CGFloat(index) * 10 + CGFloat(sin(rise / 5) * 3), y: 44 - rise)
                }
            }
            if standing {
                HStack(spacing: 14) {
                    Capsule().fill(ink).frame(width: 4, height: 12)
                    Capsule().fill(ink).frame(width: 4, height: 12)
                }
                .position(x: 114, y: 103)
            }
            Circle().stroke(mugColor, lineWidth: 6).frame(width: 22, height: 22).position(x: 144, y: 72)
            MugBody().fill(mugColor).frame(width: 56, height: 48).position(x: 114, y: 72)
            Ellipse().fill(Color(hex: 0x8CD3CC)).frame(width: 56, height: 12).position(x: 114, y: 49)
            Ellipse().fill(Color(hex: isNight ? 0x3E8F8B : 0x6B4226)).frame(width: 46, height: 8).position(x: 114, y: 49)
            face.position(x: 114, y: 74)
        }
        .offset(y: -lift)
    }

    private var face: some View {
        let closed = isNight || sceneIsBlinking(time)
        let happy = look == .timeToStand
        let surprised = look == .breakSoon || happy
        return ZStack {
            HStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { _ in
                    if happy {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 4))
                            path.addQuadCurve(to: CGPoint(x: 8, y: 4), control: CGPoint(x: 4, y: -2))
                        }
                        .stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 8, height: 6)
                    } else {
                        Capsule().fill(ink).frame(width: closed ? 7 : 4.5, height: closed ? 1.8 : 6.5)
                    }
                }
            }
            .offset(y: look == .breakSoon ? -6 : -4)
            HStack(spacing: 26) {
                Circle().fill(Color(hex: 0xF0A08A)).frame(width: 6, height: 6)
                Circle().fill(Color(hex: 0xF0A08A)).frame(width: 6, height: 6)
            }
            .offset(y: 3)
            if surprised {
                Ellipse().fill(ink).frame(width: 6, height: 7).offset(y: 6)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: 5))
                }
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 10, height: 5)
                .offset(y: 6)
            }
        }
    }

    private var plate: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xF4EEE2)).frame(width: 52, height: 10).position(x: 200, y: 99)
            ForEach([186.0, 206], id: \.self) { x in
                Circle().fill(Color(hex: 0xD9A05A)).frame(width: 20, height: 20).position(x: x, y: 88)
                ForEach(0..<3, id: \.self) { chip in
                    Circle().fill(Color(hex: 0x5A3A22)).frame(width: 3.5, height: 3.5)
                        .position(x: x - 5 + CGFloat(chip) * 5, y: 85 + CGFloat(chip % 2) * 6)
                }
            }
        }
    }

    private var shelf: some View {
        ZStack {
            Rectangle().fill(Color(hex: 0x8A5E33)).frame(width: 80, height: 5).position(x: 46, y: 32)
            ForEach(Array([0x8A5E33, 0xE8C15A, 0xD9774A].enumerated()), id: \.offset) { index, color in
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.45)).frame(width: 16, height: 20)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: UInt(color))).frame(width: 12, height: 13).offset(y: 2.5)
                    Capsule().fill(Color(hex: 0x4A5A58)).frame(width: 14, height: 4).offset(y: -10)
                }
                .position(x: 20 + CGFloat(index) * 24, y: 19)
            }
        }
    }
}

/// A mug body: straight sides, a rounded base.
private struct MugBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 12
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

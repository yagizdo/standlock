import SwiftUI
import StandLockCore

/// A hamster that runs in its wheel all day and stands up on its hind legs for the break.
struct HamsterScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }
    private var isRunning: Bool { look == .working || look == .breakSoon }

    private let fur = Color(hex: 0xE8A65A)
    private let belly = Color(hex: 0xFFF4E2)
    private let pink = Color(hex: 0xF2A0A0)
    private let ink = Color(hex: 0x3B2A20)

    private let hub = CGPoint(x: 82, y: 54)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x3A4C5A : 0xBFE3D3)
            ForEach(0..<40, id: \.self) { index in
                Circle().fill(Color(hex: isNight ? 0x34444F : 0xA9D6C2)).frame(width: 3, height: 3)
                    .position(x: CGFloat(index % 10) * 26 + 10, y: CGFloat(index / 10) * 24 + 12)
            }
            Rectangle().fill(Color(hex: isNight ? 0x5A4A3A : 0xE8C88E)).frame(height: 40).position(x: 128, y: 116)
            ForEach(0..<30, id: \.self) { index in
                Capsule().fill(Color(hex: isNight ? 0x4E4032 : 0xD4AE6E)).frame(width: 7, height: 2.5)
                    .rotationEffect(.degrees(Double(index * 37 % 180)))
                    .position(x: CGFloat(index * 53 % 256), y: 100 + CGFloat(index * 17 % 34))
            }
            house
            bowl
            stand
            wheel
            switch look {
            case .working, .breakSoon, .breakWaiting, .noSchedules:
                runningHamster.position(x: hub.x, y: hub.y + 27)
                if look == .breakSoon {
                    let fall = time.map { ($0 * 24).truncatingRemainder(dividingBy: 96) } ?? 40
                    Ellipse().fill(Color(hex: 0x4A443C)).frame(width: 5, height: 9).position(x: 30, y: 12 + fall)
                }
                if look == .breakWaiting { SceneBubble(text: "...").position(x: 124, y: 22) }
                if look == .noSchedules { SceneBubble(text: "?").position(x: 120, y: 22) }
            case .timeToStand:
                let hop = time.map { phase -> Double in
                    let p = phase.truncatingRemainder(dividingBy: 1.0)
                    return p < 0.4 ? sin(p / 0.4 * .pi) * 10 : 0
                } ?? 6
                standingHamster.position(x: 152, y: 76 - hop)
            case .paused:
                sleepingHamster.position(x: 118, y: 106)
                SceneBubble(text: "z z").position(x: 144, y: 78)
            }
        }
    }

    private var wheel: some View {
        let turn = Angle.radians(tick * (isRunning ? 5 : look == .timeToStand ? 1 : 0))
        let rim = Color(hex: isNight ? 0x34507A : 0x5B8DEF)
        return ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule().fill(Color(hex: isNight ? 0x4A5A70 : 0xA8C4F4)).frame(width: 2.5, height: 80)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            .rotationEffect(turn)
            Circle().stroke(rim, lineWidth: 5).frame(width: 88, height: 88)
            Circle().fill(Color(hex: 0x3A64C0)).frame(width: 9, height: 9)
        }
        .position(hub)
    }

    private var stand: some View {
        Path { path in
            path.move(to: hub)
            path.addLine(to: CGPoint(x: hub.x - 28, y: 100))
            path.move(to: hub)
            path.addLine(to: CGPoint(x: hub.x + 28, y: 100))
        }
        .stroke(Color(hex: 0x8A94A6), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    private var house: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: isNight ? 0x5E4A3A : 0xC49A6C)).frame(width: 50, height: 32).position(x: 208, y: 86)
            Path { path in
                path.move(to: CGPoint(x: 208, y: 48))
                path.addLine(to: CGPoint(x: 238, y: 72))
                path.addLine(to: CGPoint(x: 178, y: 72))
                path.closeSubpath()
            }
            .fill(Color(hex: isNight ? 0x6A3434 : 0xD9544A))
            Capsule().fill(Color(hex: isNight ? 0x2A1E16 : 0x5A3A22)).frame(width: 20, height: 30).position(x: 208, y: 96)
        }
    }

    private var bowl: some View {
        ZStack {
            Capsule().fill(Color(hex: 0x6E6458)).frame(width: 30, height: 8).position(x: 30, y: 110)
            Ellipse().fill(Color(hex: 0x5BB3B0)).frame(width: 36, height: 14).position(x: 30, y: 116)
        }
    }

    private func eye(open: Bool) -> some View {
        Circle().fill(ink).frame(width: 5, height: 5).scaleEffect(y: open && !sceneIsBlinking(time) ? 1 : 0.15)
    }

    private var runningHamster: some View {
        let stride = isRunning ? sin(tick * 30) : 0
        return ZStack {
            Capsule().fill(pink).frame(width: 5, height: 9).rotationEffect(.degrees(stride * 30), anchor: .top).offset(x: -10, y: 12)
            Capsule().fill(pink).frame(width: 5, height: 9).rotationEffect(.degrees(-stride * 30), anchor: .top).offset(x: 10, y: 12)
            Ellipse().fill(fur).frame(width: 44, height: 28)
            Ellipse().fill(belly).frame(width: 30, height: 13).offset(x: 3, y: 8)
            Circle().fill(fur).frame(width: 12, height: 12).offset(x: 6, y: -14)
            Circle().fill(pink).frame(width: 6, height: 6).offset(x: 6, y: -14)
            eye(open: true).offset(x: 13, y: look == .breakSoon ? -6 : -3)
            Circle().fill(pink).frame(width: 5, height: 5).offset(x: 22, y: 1)
        }
    }

    private var standingHamster: some View {
        ZStack {
            Circle().fill(fur).frame(width: 13, height: 13).offset(x: -13, y: -24)
            Circle().fill(fur).frame(width: 13, height: 13).offset(x: 13, y: -24)
            Circle().fill(pink).frame(width: 7, height: 7).offset(x: -13, y: -24)
            Circle().fill(pink).frame(width: 7, height: 7).offset(x: 13, y: -24)
            Capsule().fill(fur).frame(width: 40, height: 50)
            Ellipse().fill(belly).frame(width: 26, height: 30).offset(y: 9)
            HStack(spacing: 12) { eye(open: true); eye(open: true) }.offset(y: -12)
            Circle().fill(pink).frame(width: 5, height: 4).offset(y: -6)
            HStack(spacing: 20) {
                Circle().fill(pink.opacity(0.7)).frame(width: 6, height: 6)
                Circle().fill(pink.opacity(0.7)).frame(width: 6, height: 6)
            }
            .offset(y: -6)
            HStack(spacing: 4) {
                Capsule().fill(pink).frame(width: 7, height: 6)
                Capsule().fill(pink).frame(width: 7, height: 6)
            }
            .offset(y: 2)
            HStack(spacing: 14) {
                Capsule().fill(pink).frame(width: 9, height: 5)
                Capsule().fill(pink).frame(width: 9, height: 5)
            }
            .offset(y: 26)
        }
    }

    private var sleepingHamster: some View {
        ZStack {
            Ellipse().fill(fur).frame(width: 44, height: 26)
            Ellipse().fill(belly).frame(width: 18, height: 12).offset(x: 10, y: 5)
            Circle().fill(fur).frame(width: 11, height: 11).offset(x: -8, y: -12)
            Circle().fill(pink).frame(width: 5, height: 5).offset(x: -8, y: -12)
            Capsule().fill(ink).frame(width: 6, height: 1.6).offset(x: -10, y: -1)
        }
    }
}

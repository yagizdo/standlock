import SwiftUI
import StandLockCore

/// A sprout in a pot with a face, on a greenhouse bench. It blooms when it is time to stand.
struct SproutScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var tick: TimeInterval { time ?? 0 }
    private var isNight: Bool { look == .paused }

    private let stem = Color(hex: 0x4F9A3A)
    private let leaf = Color(hex: 0x6CC24A)
    private let ink = Color(hex: 0x3B2A20)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x24344A : 0xCFEBDD)
            if !isNight {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle().fill(Color.white.opacity(0.35)).frame(width: 10, height: 200)
                        .rotationEffect(.degrees(35)).position(x: 40 + CGFloat(index) * 92, y: 50)
                }
            }
            Path { path in
                for x in stride(from: 0.0, through: 256, by: 64) { path.addRect(CGRect(x: x - 2, y: 0, width: 4, height: 104)) }
                for y in stride(from: 30.0, through: 104, by: 32) { path.addRect(CGRect(x: 0, y: y - 2, width: 256, height: 4)) }
            }
            .fill(Color(hex: isNight ? 0x4A5A70 : 0xF4FAF6))
            if isNight {
                Circle().fill(Color(hex: 0xF4E9C1)).frame(width: 16, height: 16).position(x: 222, y: 16)
            }
            Rectangle().fill(Color(hex: isNight ? 0x4A3C30 : 0xA0703F)).frame(height: 32).position(x: 128, y: 120)
            Rectangle().fill(Color(hex: isNight ? 0x5A4A3A : 0xC4925C)).frame(height: 5).position(x: 128, y: 106)
            cactus
            sprout
            pot
            switch look {
            case .breakSoon:
                can.rotationEffect(.degrees(-35)).position(x: 162, y: 34)
                ForEach(0..<3, id: \.self) { index in
                    let fall = time.map { ($0 * 40 + Double(index) * 9).truncatingRemainder(dividingBy: 22) } ?? Double(index) * 7
                    Capsule().fill(Color(hex: 0x8CCDE6)).frame(width: 3, height: 7).position(x: 140 - CGFloat(index % 2) * 4, y: 30 + fall)
                }
            case .paused:
                can.position(x: 200, y: 92)
                SceneBubble(text: "z z").position(x: 172, y: 40)
            case .breakWaiting:
                can.position(x: 200, y: 92)
                SceneBubble(text: "...").position(x: 160, y: 26)
            case .noSchedules:
                can.position(x: 200, y: 92)
                SceneBubble(text: "?").position(x: 156, y: 26)
            case .working, .timeToStand:
                can.position(x: 200, y: 92)
            }
        }
    }

    private var sway: Double {
        time.map { sin($0 * 1.8) * 6 } ?? 0
    }

    private var sprout: some View {
        let tall = look == .timeToStand
        let droop = look == .paused
        let height: CGFloat = tall ? 62 : 40
        return ZStack {
            Capsule().fill(stem).frame(width: 5, height: height).position(x: 128, y: 74 - height / 2)
            leafShape(angle: droop ? 35 : tall ? -40 : -10 + sway).position(x: 114, y: tall ? 52 : 60)
            leafShape(angle: droop ? 145 : tall ? 220 : 190 - sway).position(x: 142, y: tall ? 52 : 60)
            if tall {
                ForEach(0..<6, id: \.self) { index in
                    Ellipse().fill(Color(hex: 0xF29AB0)).frame(width: 12, height: 18)
                        .offset(y: -10).rotationEffect(.degrees(Double(index) * 60))
                }
                .position(x: 128, y: 14)
                Circle().fill(Color(hex: 0xFFD95A)).frame(width: 12, height: 12).position(x: 128, y: 14)
            } else {
                Ellipse().fill(Color(hex: droop ? 0x9A4A60 : 0xE86A8A)).frame(width: 14, height: droop ? 18 : 16).position(x: 128, y: 32)
            }
        }
    }

    private func leafShape(angle: Double) -> some View {
        Ellipse().fill(isNight ? Color(hex: 0x4A8A3A) : leaf).frame(width: 30, height: 13)
            .rotationEffect(.degrees(angle))
    }

    private var pot: some View {
        let closed = look == .paused || sceneIsBlinking(time)
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 108, y: 82))
                path.addLine(to: CGPoint(x: 148, y: 82))
                path.addLine(to: CGPoint(x: 142, y: 106))
                path.addLine(to: CGPoint(x: 114, y: 106))
                path.closeSubpath()
            }
            .fill(Color(hex: 0xC9683F))
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xD9774A)).frame(width: 50, height: 10).position(x: 128, y: 78)
            HStack(spacing: 11) {
                Capsule().fill(ink).frame(width: closed ? 6 : 4, height: closed ? 1.6 : 5)
                Capsule().fill(ink).frame(width: closed ? 6 : 4, height: closed ? 1.6 : 5)
            }
            .position(x: 128, y: look == .breakSoon ? 89 : 91)
            HStack(spacing: 20) {
                Circle().fill(Color(hex: 0xE8907A)).frame(width: 5, height: 5)
                Circle().fill(Color(hex: 0xE8907A)).frame(width: 5, height: 5)
            }
            .position(x: 128, y: 96)
            if look == .breakSoon || look == .timeToStand {
                Ellipse().fill(ink).frame(width: 5, height: 5).position(x: 128, y: 98)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 124, y: 97))
                    path.addQuadCurve(to: CGPoint(x: 132, y: 97), control: CGPoint(x: 128, y: 101))
                }
                .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }

    private var cactus: some View {
        ZStack {
            Capsule().fill(Color(hex: 0x5E9E3A)).frame(width: 14, height: 30).position(x: 42, y: 78)
            Capsule().fill(Color(hex: 0x5E9E3A)).frame(width: 7, height: 14).position(x: 34, y: 76)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xC9683F)).frame(width: 22, height: 14).position(x: 42, y: 98)
        }
    }

    private var can: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0x6E9FC9)).frame(width: 34, height: 26)
            Capsule().fill(Color(hex: 0x4A7AA6)).frame(width: 34, height: 4).offset(y: 6)
            Capsule().fill(Color(hex: 0x6E9FC9)).frame(width: 22, height: 5).rotationEffect(.degrees(-25)).offset(x: -24, y: -6)
            Circle().stroke(Color(hex: 0x4A7AA6), lineWidth: 3).frame(width: 18, height: 18).offset(x: 14, y: -14)
        }
    }
}

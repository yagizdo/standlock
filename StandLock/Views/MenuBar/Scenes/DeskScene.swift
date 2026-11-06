import SwiftUI
import StandLockCore

/// A small person at a desk who gets up for the break.
struct DeskScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private let wall = Color(hex: 0x314F4D)
    private let skin = Color(hex: 0xF4C98E)
    private let hair = Color(hex: 0x4A3428)
    private let shirt = Color(hex: 0xE8695A)
    private let eyeColor = Color(hex: 0x2B2B2B)
    private let cream = Color(hex: 0xF3EFE6)

    private var blinkScale: CGFloat { sceneIsBlinking(time) ? 0.12 : 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0x3B5D5B), wall], startPoint: .top, endPoint: .bottom)
            clock
            shelf

            switch look {
            case .working: bust().padding(.bottom, 14)
            case .breakSoon: bust(eyeShiftX: -3, eyeShiftY: -2, wide: true).padding(.bottom, 14)
            case .breakWaiting: bust(headset: true).padding(.bottom, 14)
            case .paused: RoundedRectangle(cornerRadius: 14).fill(shirt).frame(width: 58, height: 44).padding(.bottom, 24)
            case .noSchedules: chair.padding(.bottom, 26)
            case .timeToStand: chair.offset(x: 24).padding(.bottom, 26)
            }

            Rectangle().fill(Color(hex: 0xB98F66)).frame(height: 32)

            switch look {
            case .working, .breakSoon, .breakWaiting: laptop
            case .timeToStand: laptop.offset(x: 34)
            case .paused, .noSchedules:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: 0xC9CDD4))
                    .frame(width: 78, height: 6)
                    .offset(x: look == .paused ? 62 : 0)
                    .padding(.bottom, 24)
            }

            mug

            if look == .paused {
                ZStack {
                    Capsule().fill(shirt).frame(width: 74, height: 15).offset(y: 14)
                    Circle().fill(skin).frame(width: 34, height: 34)
                    Capsule().fill(hair).frame(width: 35, height: 15).offset(y: -11)
                }
                .padding(.bottom, 26)
                SceneBubble(text: "z z").offset(x: 40, y: -82)
            }
            if look == .timeToStand { standing.offset(x: -40) }
            if look == .noSchedules { SceneBubble(text: "?").offset(y: -96) }
        }
    }

    private var clock: some View {
        ZStack {
            Circle().fill(cream).frame(width: 32, height: 32)
            Capsule().fill(wall).frame(width: 2, height: 10).offset(y: -5)
            Capsule().fill(wall).frame(width: 2, height: 8).rotationEffect(.degrees(120), anchor: .bottom).offset(y: -4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 14)
        .padding(.leading, 26)
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0xE8A15C)).frame(width: 9, height: 24)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0xE4D7BE)).frame(width: 7, height: 20)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0x7FB5C9)).frame(width: 10, height: 26)
            }
            Rectangle().fill(Color(hex: 0xC9A77E)).frame(width: 62, height: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 18)
        .padding(.trailing, 24)
    }

    private var mug: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 3).fill(cream).frame(width: 15, height: 17)
            Circle().stroke(cream, lineWidth: 2).frame(width: 9, height: 9).offset(x: 5)
        }
        .frame(maxWidth: .infinity, alignment: look == .paused ? .leading : .trailing)
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private func eyes(size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Circle().fill(eyeColor).frame(width: size, height: size)
            Circle().fill(eyeColor).frame(width: size, height: size)
        }
        .scaleEffect(y: blinkScale)
    }

    private func bust(eyeShiftX: CGFloat = 0, eyeShiftY: CGFloat = 0, wide: Bool = false, headset: Bool = false) -> some View {
        VStack(spacing: -6) {
            ZStack(alignment: .top) {
                Circle().fill(skin).frame(width: 34, height: 34)
                Capsule().fill(hair).frame(width: 35, height: 15).offset(y: -2)
                eyes(size: wide ? 6 : 4.5, spacing: 11).offset(x: eyeShiftX, y: 17 + eyeShiftY)
                if headset {
                    Circle().trim(from: 0.5, to: 1).stroke(Color(hex: 0x20262E), lineWidth: 3).frame(width: 40, height: 40).offset(y: -3)
                    HStack(spacing: 32) {
                        Capsule().fill(Color(hex: 0x20262E)).frame(width: 7, height: 13)
                        Capsule().fill(Color(hex: 0x20262E)).frame(width: 7, height: 13)
                    }
                    .offset(y: 13)
                }
            }
            RoundedRectangle(cornerRadius: 14).fill(shirt).frame(width: 58, height: 52)
        }
    }

    private var laptop: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(hex: 0xE2E5EA), Color(hex: 0xB7BCC5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 74, height: 44)
                .padding(.bottom, 26)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x8D929B)).frame(width: 90, height: 4).padding(.bottom, 24)
            Circle().stroke(.white, lineWidth: 1.5).frame(width: 12, height: 12).padding(.bottom, 41)
        }
    }

    private var chair: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x24403E)).frame(width: 56, height: 56)
    }

    private var standing: some View {
        ZStack(alignment: .top) {
            Path { path in
                path.move(to: CGPoint(x: 14, y: 46))
                path.addQuadCurve(to: CGPoint(x: 4, y: 8), control: CGPoint(x: 0, y: 34))
                path.move(to: CGPoint(x: 46, y: 46))
                path.addQuadCurve(to: CGPoint(x: 56, y: 8), control: CGPoint(x: 60, y: 34))
            }
            .stroke(shirt, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: 60, height: 60)
            VStack(spacing: -4) {
                ZStack(alignment: .top) {
                    Circle().fill(skin).frame(width: 30, height: 30)
                    Capsule().fill(hair).frame(width: 31, height: 13).offset(y: -2)
                    eyes(size: 4, spacing: 10).offset(y: 15)
                }
                RoundedRectangle(cornerRadius: 11).fill(shirt).frame(width: 40, height: 46)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x33475E)).frame(width: 15, height: 38)
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x33475E)).frame(width: 15, height: 38)
                }
            }
            .padding(.top, 8)
        }
        .frame(width: 60, height: 122, alignment: .top)
    }
}

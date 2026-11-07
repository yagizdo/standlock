import SwiftUI
import StandLockCore

/// A reader in an armchair under a floor lamp, a bookshelf behind. They stand up to stretch when
/// it is time to stand, and doze off with the book on their chest when paused.
struct ReadingScene: View {
    let look: MenuSceneLook
    let time: TimeInterval?

    private var isNight: Bool { look == .paused }
    private var standing: Bool { look == .timeToStand }

    private let skin = Color(hex: 0xF2C49A)

    var body: some View {
        ZStack {
            Color(hex: isNight ? 0x2C2838 : 0xE6C2B6)
            Path { path in
                for x in stride(from: 0.0, through: 256, by: 32) {
                    path.addRect(CGRect(x: x, y: 0, width: 8, height: 112))
                }
            }
            .fill(Color(hex: isNight ? 0x312C3E : 0xEDCFC4))
            Path { path in
                path.move(to: CGPoint(x: 22, y: 36))
                path.addLine(to: CGPoint(x: 46, y: 36))
                path.addLine(to: CGPoint(x: 116, y: 112))
                path.addLine(to: CGPoint(x: -4, y: 112))
                path.closeSubpath()
            }
            .fill(Color(hex: 0xFFE7A8, opacity: isNight ? 0.22 : 0.35))
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0xB07A4A)).frame(height: 24).position(x: 128, y: 124)
            Rectangle().fill(Color(hex: isNight ? 0x3A2E26 : 0x8A5A33)).frame(height: 3).position(x: 128, y: 113)
            Ellipse().fill(Color(hex: isNight ? 0x3E4A44 : 0x8FAF8A)).frame(width: 136, height: 18).position(x: 124, y: 122)
            shelf
            lamp
            chairBack
            if standing {
                chairFront
                standingReader
            } else {
                sittingReader
                chairFront
                blanket
            }
            switch look {
            case .paused:
                SceneBubble(text: "z z").position(x: 176, y: 30)
            case .breakWaiting:
                SceneBubble(text: "...").position(x: 172, y: 22)
            case .noSchedules:
                SceneBubble(text: "?").position(x: 166, y: 22)
            case .working, .breakSoon, .timeToStand:
                EmptyView()
            }
        }
    }

    // MARK: - Reader

    private var sittingReader: some View {
        let lowered: CGFloat = look == .breakSoon ? 8 : 0
        let flipping = look == .working && (time.map { $0.truncatingRemainder(dividingBy: 5) < 0.4 } ?? false)
        return ZStack {
            SceneTop(color: 0xD9774A).frame(width: 56, height: 38).position(x: 124, y: 86)
            head.rotationEffect(.degrees(isNight ? 12 : 0), anchor: .bottom).position(x: 124, y: 46)
            if isNight {
                Path { path in
                    path.move(to: CGPoint(x: 102, y: 90))
                    path.addLine(to: CGPoint(x: 124, y: 74))
                    path.addLine(to: CGPoint(x: 146, y: 90))
                    path.closeSubpath()
                }
                .fill(Color(hex: 0x3F7FA8))
            } else {
                book.position(x: 124, y: 86 + lowered)
                if flipping {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xFBF4E6)).frame(width: 14, height: 18)
                        .rotationEffect(.degrees(-25)).position(x: 132, y: 74 + lowered)
                }
            }
        }
    }

    private var standingReader: some View {
        SceneStretch(head: head, top: 0xD9774A, pants: 0x3A4660, time: time).position(x: 124, y: 116 - 58)
    }

    private var head: SceneHead {
        let eyes: SceneHead.Eyes
        let mouth: SceneHead.Mouth
        switch look {
        case .paused: eyes = .closed; mouth = .smile
        case .timeToStand: eyes = .happy; mouth = .grin
        case .breakSoon: eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: true); mouth = .open
        case .noSchedules: eyes = sceneIsBlinking(time) ? .closed : .open(lookingUp: true); mouth = .smile
        case .working, .breakWaiting: eyes = .open(lookingUp: false); mouth = .smile
        }
        return SceneHead(hair: .bun, hairColor: 0x6B4226, skin: 0xF2C49A, glasses: true, eyes: eyes, mouth: mouth)
    }

    private var book: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x3F7FA8)).frame(width: 46, height: 28)
            Rectangle().fill(Color(hex: 0x1E3A50)).frame(width: 2.5, height: 28)
            Capsule().fill(Color(hex: 0xF2C94C)).frame(width: 12, height: 3).offset(x: -11, y: -4)
            Circle().fill(skin).frame(width: 10, height: 10).offset(x: -24, y: 2)
            Circle().fill(skin).frame(width: 10, height: 10).offset(x: 24, y: 2)
        }
    }

    private var blanket: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xF3E6D2)).frame(width: 66, height: 16)
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { _ in
                    Rectangle().fill(Color(hex: 0xC4504A, opacity: 0.8)).frame(width: 5, height: 16)
                }
            }
            Rectangle().fill(Color(hex: 0xC4504A, opacity: 0.6)).frame(width: 66, height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .position(x: 124, y: 102)
    }

    // MARK: - Room

    private var chairColor: Color { Color(hex: isNight ? 0x34503E : 0x5E8C6A) }
    private var chairShade: Color { Color(hex: isNight ? 0x2C4434 : 0x4E7A5A) }

    private var chairBack: some View {
        RoundedRectangle(cornerRadius: 20).fill(chairColor).frame(width: 96, height: 78).position(x: 124, y: 68)
    }

    private var chairFront: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                RoundedRectangle(cornerRadius: 9).fill(chairColor).frame(width: 20, height: 40).position(x: 124 + side * 46, y: 90)
                Rectangle().fill(Color(hex: 0x3B2A20)).frame(width: 4, height: 6).position(x: 124 + side * 44, y: 113)
            }
            RoundedRectangle(cornerRadius: 6).fill(chairShade).frame(width: 112, height: 12).position(x: 124, y: 106)
        }
    }

    private var lamp: some View {
        ZStack {
            Rectangle().fill(Color(hex: 0x3A3040)).frame(width: 3, height: 74).position(x: 34, y: 72)
            Ellipse().fill(Color(hex: 0x3A3040)).frame(width: 22, height: 6).position(x: 34, y: 110)
            Ellipse().fill(Color(hex: 0xFFF3B0)).frame(width: 14, height: 6).position(x: 34, y: 36)
            Path { path in
                path.move(to: CGPoint(x: 23, y: 14))
                path.addLine(to: CGPoint(x: 45, y: 14))
                path.addLine(to: CGPoint(x: 54, y: 35))
                path.addLine(to: CGPoint(x: 14, y: 35))
                path.closeSubpath()
            }
            .fill(Color(hex: 0xF2B33A))
        }
    }

    private var shelf: some View {
        let books: [[(UInt, CGFloat, CGFloat)]] = [
            [(0xC4504A, 8, 22), (0x3F7FA8, 7, 18), (0xF2C94C, 5, 22), (0x5E9E6A, 8, 20), (0x8A6AB0, 7, 14), (0xE08A3A, 8, 22)],
            [(0x3F7FA8, 8, 22), (0xE08A3A, 5, 18), (0xE08A3A, 5, 22), (0x5E9E6A, 8, 14), (0xC4504A, 8, 22), (0xF2C94C, 8, 18)],
            [(0x8A6AB0, 8, 18), (0xF2C94C, 8, 22), (0xC4504A, 5, 22), (0x3F7FA8, 8, 22), (0x5E9E6A, 8, 18), (0xE08A3A, 5, 14)],
        ]
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: isNight ? 0x4A3A30 : 0x8A5E33)).frame(width: 62, height: 90)
            ForEach(0..<3, id: \.self) { row in
                Rectangle().fill(Color(hex: isNight ? 0x221A16 : 0x4A3022)).frame(width: 54, height: 25)
                    .offset(x: 4, y: 4 + CGFloat(row) * 29)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(books[row].enumerated()), id: \.offset) { _, entry in
                        Rectangle().fill(Color(hex: entry.0).opacity(isNight ? 0.45 : 1)).frame(width: entry.1, height: entry.2)
                    }
                }
                .frame(width: 54, height: 25, alignment: .bottomLeading)
                .offset(x: 4, y: 4 + CGFloat(row) * 29)
            }
        }
        .frame(width: 62, height: 90)
        .overlay(alignment: .top) {
            ZStack {
                ForEach([-1.0, 0, 1], id: \.self) { side in
                    Ellipse().fill(Color(hex: isNight ? 0x3E6A34 : 0x6CC24A)).frame(width: 8, height: 14)
                        .rotationEffect(.degrees(side * 35)).offset(x: side * 5, y: -4)
                }
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xC9683F)).frame(width: 14, height: 10).offset(y: 6)
            }
            .offset(x: -14, y: -12)
        }
        .position(x: 220, y: 67)
    }
}

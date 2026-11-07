import SwiftUI

/// The face the shape scenes share: eyes with a highlight, soft blush and a small mouth, centred
/// between the eyes. People, mugs, loaves and pots all wear it, so they read as one family.
struct SceneFace: View {
    enum Eyes: Equatable {
        case open(lookingUp: Bool)
        case closed
        case happy
    }

    enum Mouth: Equatable {
        case smile, open, grin
    }

    var eyes: Eyes
    var mouth: Mouth
    var eyeSpacing: CGFloat = 18
    var blushSpacing: CGFloat = 26
    /// How far below the eyes the mouth sits; the blush sits halfway.
    var mouthDrop: CGFloat = 9

    private let ink = Color(hex: 0x2E2430)

    var body: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                Self.eye(eyes, ink: ink).offset(x: side * eyeSpacing / 2)
                Ellipse().fill(Color(hex: 0xF29A8A, opacity: 0.75)).frame(width: 7, height: 4.5)
                    .offset(x: side * blushSpacing / 2, y: mouthDrop * 0.8)
            }
            Self.mouth(mouth, ink: ink).offset(y: mouthDrop)
        }
    }

    @ViewBuilder static func eye(_ eyes: Eyes, ink: Color) -> some View {
        switch eyes {
        case .happy:
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3.5))
                path.addQuadCurve(to: CGPoint(x: 7, y: 3.5), control: CGPoint(x: 3.5, y: -1.5))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 7, height: 4)
        case .closed:
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 3.5, y: 3))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: 7, height: 3)
            .offset(y: 1.5)
        case .open(let lookingUp):
            ZStack {
                Ellipse().fill(ink).frame(width: 5, height: 6.5)
                Circle().fill(Color.white).frame(width: 1.8, height: 1.8).offset(x: 1, y: -1.5)
            }
            .offset(y: lookingUp ? -1.5 : 0.5)
        }
    }

    @ViewBuilder static func mouth(_ mouth: Mouth, ink: Color) -> some View {
        switch mouth {
        case .open:
            Ellipse().fill(ink).frame(width: 5, height: 6)
        case .grin:
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: 8))
                    path.closeSubpath()
                }
                .fill(ink)
                Ellipse().fill(Color(hex: 0xE8707A)).frame(width: 4.5, height: 2.5).offset(x: 0, y: 1.5)
            }
            .frame(width: 10, height: 5)
        case .smile:
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 3, y: 3.5))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: 6, height: 4)
        }
    }
}

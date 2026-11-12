import SwiftUI

/// A person's head for the people scenes: hair or a hat, a face, glasses if asked. Drawn in a
/// 52 x 52 frame; hats and buns reach above it.
struct SceneHead: View {
    enum Hair: Equatable {
        case bun, short, long
        /// Short and close, with the hairline high and the ears showing.
        case crop
        /// Long and wavy past the shoulders, parted in the middle, framing the face.
        case wavy
        case beret(UInt)
        case bucketHat(UInt)
    }

    typealias Eyes = SceneFace.Eyes
    typealias Mouth = SceneFace.Mouth

    var hair: Hair
    var hairColor: UInt
    var skin: UInt
    var glasses = false
    var eyes: Eyes
    var mouth: Mouth
    /// The bucket hat's brim pulled down over the eyes, for a nap.
    var hatOverEyes = false
    /// Stubble colour over the jaw; with it come thick brows, a moustache and a darker chin.
    var beard: UInt?
    var earring = false
    /// A tall white chef's hat over whatever hair is drawn.
    var chefHat = false

    private let ink = Color(hex: 0x2E2430)

    var body: some View {
        ZStack {
            if hair == .long {
                RoundedRectangle(cornerRadius: 18).fill(Color(hex: hairColor)).frame(width: 52, height: 54).offset(y: 10)
            }
            if hair == .wavy {
                WavyHair().fill(Color(hex: hairColor)).frame(width: 60, height: 64).offset(y: 14)
            }
            if hair == .bun {
                Circle().fill(Color(hex: hairColor)).frame(width: 18, height: 18).offset(y: -22)
            }
            if hair == .crop {
                croppedHead
            } else {
                Circle().fill(Color(hex: hairColor)).frame(width: 48, height: 48)
                Ellipse().fill(Color(hex: skin)).frame(width: 40, height: 34).offset(y: 7)
                if hair == .wavy {
                    partedHair
                } else {
                    Ellipse().fill(Color(hex: hairColor)).frame(width: 44, height: 18).offset(y: -9)
                }
            }
            Capsule().fill(Color.white.opacity(0.22)).frame(width: 12, height: 4).rotationEffect(.degrees(-28)).offset(x: -10, y: -15)
            ForEach([-1.0, 1], id: \.self) { side in
                SceneFace.eye(eyes, ink: ink).offset(x: side * 9, y: 8)
                if glasses {
                    Circle().stroke(Color(hex: 0x3A3040), lineWidth: 1.8).frame(width: 14, height: 14).offset(x: side * 9, y: 8)
                }
                if beard == nil {
                    Ellipse().fill(Color(hex: 0xF29A8A, opacity: 0.75)).frame(width: 7, height: 4.5).offset(x: side * 13, y: 16)
                } else if eyes != .closed {
                    Capsule().fill(Color(hex: hairColor)).frame(width: 10, height: 3)
                        .rotationEffect(.degrees(side * (eyes == .happy ? 14 : 8))).offset(x: side * 10, y: eyes == .open(lookingUp: true) ? -2 : 0)
                }
            }
            if glasses {
                Rectangle().fill(Color(hex: 0x3A3040)).frame(width: 4, height: 1.8).offset(y: 7)
            }
            if let beard {
                facialHair(beard)
            } else {
                SceneFace.mouth(mouth, ink: ink).offset(y: 17)
            }
            hat
        }
        .frame(width: 52, height: 52)
    }

    /// A round head with ears, close-cropped hair above a high hairline.
    @ViewBuilder private var croppedHead: some View {
        ForEach([-1.0, 1], id: \.self) { side in
            Ellipse().fill(Color(hex: skin)).frame(width: 9, height: 13).overlay(
                Ellipse().fill(Color.black.opacity(0.08)).frame(width: 5, height: 8)
            )
            .offset(x: side * 22, y: 5)
        }
        if earring {
            Circle().stroke(Color(hex: 0x2E2430), lineWidth: 1.6).frame(width: 6, height: 6).offset(x: -23, y: 13)
        }
        Ellipse().fill(Color(hex: skin)).frame(width: 44, height: 50).offset(y: 3)
        Ellipse().fill(Color(hex: hairColor)).frame(width: 44, height: 28).offset(y: -12)
        Ellipse().fill(Color(hex: skin)).frame(width: 34, height: 20).offset(y: -3)
    }

    /// Two sweeps from a centre parting, locks down both cheeks and a small silver hoop.
    @ViewBuilder private var partedHair: some View {
        ForEach([-1.0, 1], id: \.self) { side in
            Ellipse().fill(Color(hex: hairColor)).frame(width: 28, height: 18)
                .rotationEffect(.degrees(side * 24)).offset(x: side * 11, y: -9)
            Ellipse().fill(Color(hex: hairColor)).frame(width: 10, height: 32).offset(x: side * 22, y: 12)
        }
        if earring {
            Circle().stroke(Color(hex: 0xC8CDD4), lineWidth: 1.6).frame(width: 6, height: 6).offset(x: 21, y: 22)
        }
    }

    /// Stubble below the cheeks, a wide moustache, a darker chin and the mouth between them.
    private func facialHair(_ stubble: UInt) -> some View {
        ZStack {
            Ellipse().fill(Color(hex: stubble)).frame(width: 44, height: 50)
                .mask(VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().frame(height: 18)
                })
                .offset(y: 3)
            Ellipse().fill(Color(hex: 0x7A6858)).frame(width: 15, height: 8).offset(y: 23)
            Group {
                switch mouth {
                case .open:
                    Ellipse().fill(ink).frame(width: 6, height: 6)
                case .grin:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: 7))
                        path.closeSubpath()
                    }
                    .fill(ink)
                    .frame(width: 10, height: 5)
                case .smile:
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 3.5, y: 3))
                    }
                    .stroke(Color(hex: 0xB85A5A), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: 7, height: 3)
                }
            }
            .offset(y: 20)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 10))
                path.addQuadCurve(to: CGPoint(x: 30, y: 10), control: CGPoint(x: 15, y: -6))
                path.addQuadCurve(to: CGPoint(x: 0, y: 10), control: CGPoint(x: 15, y: 3))
                path.closeSubpath()
            }
            .fill(Color(hex: hairColor))
            .frame(width: 30, height: 10)
            .offset(y: 14)
        }
    }

    @ViewBuilder private var hat: some View {
        switch hair {
        case .beret(let color):
            ZStack {
                Ellipse().fill(Color(hex: color)).frame(width: 46, height: 16)
                Capsule().fill(Color(hex: color)).frame(width: 3, height: 6).offset(x: 4, y: -9)
            }
            .rotationEffect(.degrees(-10))
            .offset(x: 3, y: -20)
        case .bucketHat(let color):
            let drop: CGFloat = hatOverEyes ? 17 : 0
            ZStack {
                RoundedRectangle(cornerRadius: hatOverEyes ? 16 : 9).fill(Color(hex: color)).frame(width: hatOverEyes ? 46 : 36, height: 20 + drop * 0.5).offset(y: -20 + drop * 0.75)
                Ellipse().fill(Color(hex: color)).frame(width: 56, height: hatOverEyes ? 14 : 10).offset(y: -11 + drop)
                Capsule().fill(Color.black.opacity(0.18)).frame(width: 36, height: 3).offset(y: -13 + drop)
            }
        case .bun, .short, .long, .crop, .wavy:
            EmptyView()
        }
        if chefHat {
            ZStack {
                ForEach([-10.0, 0, 10], id: \.self) { x in
                    Circle().fill(Color(hex: 0xFBF8F2)).frame(width: 18, height: 18).offset(x: x, y: -27)
                }
                Rectangle().fill(Color(hex: 0xFBF8F2)).frame(width: 34, height: 12).offset(y: -20)
                Rectangle().fill(Color(hex: 0xE4DED2)).frame(width: 34, height: 2).offset(y: -16)
            }
        }
    }
}

/// Long hair seen from the front: a round crown, soft sides and a wavy hem.
private struct WavyHair: Shape {
    func path(in rect: CGRect) -> Path {
        let crown = rect.minY + rect.width / 2
        let hem = rect.maxY - 5
        let waves = 4
        let step = (rect.width - 4) / CGFloat(waves)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: crown))
        path.addArc(center: CGPoint(x: rect.midX, y: crown), radius: rect.width / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: hem), control: CGPoint(x: rect.maxX + 4, y: (crown + hem) / 2))
        for wave in 0..<waves {
            let start = rect.maxX - 2 - CGFloat(wave) * step
            path.addQuadCurve(to: CGPoint(x: start - step, y: hem), control: CGPoint(x: start - step / 2, y: rect.maxY + 3))
        }
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: crown), control: CGPoint(x: rect.minX - 4, y: (crown + hem) / 2))
        path.closeSubpath()
        return path
    }
}

/// A rounded, slightly pear-shaped body: narrow at the shoulders, soft at the hem.
struct SceneBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.16
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + 6))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - inset, y: rect.minY + 6), control: CGPoint(x: rect.midX, y: rect.minY - 3))
        path.addCurve(to: CGPoint(x: rect.maxX - 6, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX + 1, y: rect.minY + rect.height * 0.35),
                      control2: CGPoint(x: rect.maxX + 1, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX + inset, y: rect.minY + 6),
                      control1: CGPoint(x: rect.minX - 1, y: rect.maxY),
                      control2: CGPoint(x: rect.minX - 1, y: rect.minY + rect.height * 0.35))
        path.closeSubpath()
        return path
    }
}

/// A body in a top, with a collar and a darker hem; a neckerchief and an apron if given.
struct SceneTop: View {
    let color: UInt
    var scarf: UInt?
    var apron: UInt?

    var body: some View {
        ZStack(alignment: .bottom) {
            SceneBody().fill(Color(hex: color))
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 5)
            if let apron {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 5).fill(Color(hex: apron)).frame(width: 26, height: 24)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.18)).frame(width: 12, height: 6).offset(y: 10)
                }
            }
        }
        .clipShape(SceneBody())
        .overlay(alignment: .top) {
            if let scarf {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 18, y: 0))
                    path.addLine(to: CGPoint(x: 9, y: 11))
                    path.closeSubpath()
                }
                .fill(Color(hex: scarf))
                .frame(width: 18, height: 11)
                .offset(y: 1)
            } else {
                Ellipse().fill(Color.white.opacity(0.35)).frame(width: 16, height: 6).offset(y: 1)
            }
        }
    }
}

/// A short leg and a round shoe; the shoe sits on the bottom edge.
private struct SceneLeg: View {
    let pants: UInt
    let height: CGFloat

    var body: some View {
        VStack(spacing: -3) {
            Capsule().fill(Color(hex: pants)).frame(width: 11, height: height)
            ZStack {
                Ellipse().fill(Color(hex: 0x3B2A20)).frame(width: 15, height: 8)
                Ellipse().fill(Color.white.opacity(0.18)).frame(width: 6, height: 2.5).offset(x: -2, y: -1.5)
            }
        }
    }
}

/// A person standing with both arms up in a slow stretch, bobbing as they reach.
/// 80 x 116, feet on the bottom edge.
struct SceneStretch: View {
    let head: SceneHead
    let top: UInt
    let pants: UInt
    var scarf: UInt?
    var apron: UInt?
    let time: TimeInterval?

    var body: some View {
        let swing = time.map { (sin($0 * 3) + 1) / 2 } ?? 0.6
        let bob = CGFloat(swing) * 3
        return ZStack {
            Ellipse().fill(Color.black.opacity(0.12)).frame(width: 46, height: 6).position(x: 40, y: 114)
            ZStack {
                ForEach([-1.0, 1], id: \.self) { side in
                    SceneLeg(pants: pants, height: 16).position(x: 40 + side * 8, y: 104 + bob)
                }
                ForEach([-1.0, 1], id: \.self) { side in
                    let hand = CGPoint(x: 40 + side * (30 + swing * 5), y: 22 - swing * 5)
                    Path { path in
                        path.move(to: CGPoint(x: 40 + side * 14, y: 70))
                        path.addQuadCurve(to: hand, control: CGPoint(x: 40 + side * 27, y: 54))
                    }
                    .stroke(Color(hex: top), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    Circle().fill(Color(hex: head.skin)).frame(width: 11, height: 11).position(hand)
                }
                SceneTop(color: top, scarf: scarf, apron: apron).frame(width: 42, height: 36).position(x: 40, y: 80)
                head.position(x: 40, y: 40)
            }
            .offset(y: -bob)
        }
        .frame(width: 80, height: 116)
    }
}

/// A person sitting front on, legs down, for a stool or a ledge. 64 x 92, feet on the bottom
/// edge; the seat is 22 pt above the feet.
struct SceneSitter: View {
    let head: SceneHead
    let top: UInt
    let pants: UInt
    var scarf: UInt?
    var apron: UInt?
    /// Degrees the head leans, for a nap.
    var lean: Double = 0

    var body: some View {
        ZStack {
            ForEach([-1.0, 1], id: \.self) { side in
                SceneLeg(pants: pants, height: 18).position(x: 32 + side * 9, y: 80)
            }
            Capsule().fill(Color(hex: pants)).frame(width: 40, height: 12).position(x: 32, y: 68)
            SceneTop(color: top, scarf: scarf, apron: apron).frame(width: 44, height: 34).position(x: 32, y: 54)
            head.rotationEffect(.degrees(lean), anchor: .bottom).position(x: 32, y: 16)
        }
        .frame(width: 64, height: 92)
    }
}

/// A person standing at ease, arms down, or the right hand reaching to `rightHand` (in this
/// view's 80 x 116 frame) to hold something. Feet on the bottom edge.
struct SceneStander: View {
    let head: SceneHead
    let top: UInt
    let pants: UInt
    var scarf: UInt?
    var apron: UInt?
    var rightHand: CGPoint?

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.12)).frame(width: 46, height: 6).position(x: 40, y: 114)
            ForEach([-1.0, 1], id: \.self) { side in
                SceneLeg(pants: pants, height: 16).position(x: 40 + side * 8, y: 104)
            }
            arm(to: CGPoint(x: 22, y: 92), side: -1)
            arm(to: rightHand ?? CGPoint(x: 58, y: 92), side: 1)
            SceneTop(color: top, scarf: scarf, apron: apron).frame(width: 42, height: 36).position(x: 40, y: 80)
            head.position(x: 40, y: 40)
        }
        .frame(width: 80, height: 116)
    }

    private func arm(to hand: CGPoint, side: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 40 + side * 14, y: 70))
                path.addQuadCurve(to: hand, control: CGPoint(x: 40 + side * 24, y: 74))
            }
            .stroke(Color(hex: top), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            Circle().fill(Color(hex: head.skin)).frame(width: 11, height: 11).position(hand)
        }
    }
}

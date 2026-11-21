import SwiftUI
import StandLockCore

/// The picture at the top of the panel. `date` drives all motion, so a coordinator publish can
/// redraw a scene but never restart it. A new scene is one file and one case here.
struct MenuSceneCard: View {
    let scene: MenuScene
    let look: MenuSceneLook
    let progress: Double
    let date: Date
    let isMoving: Bool

    /// A scene draws its look-dependent parts over an opaque room in a `ZStack`, which puts a part
    /// being removed behind the room: the old pose vanished at once and the new one faded in over
    /// an empty room. So the whole new scene fades in over the old one, kept opaque until it ends.
    @State private var shown: MenuSceneLook
    @State private var previous: MenuSceneLook?
    @State private var fadeIn = 1.0
    @State private var fade = 0

    private static let fadeDuration = 0.3

    init(scene: MenuScene, look: MenuSceneLook, progress: Double, date: Date, isMoving: Bool) {
        self.scene = scene
        self.look = look
        self.progress = progress
        self.date = date
        self.isMoving = isMoving
        _shown = State(initialValue: look)
    }

    private var time: TimeInterval? {
        isMoving ? date.timeIntervalSinceReferenceDate : nil
    }

    var body: some View {
        ZStack {
            if let previous {
                sceneView(previous)
            }
            sceneView(shown)
                .opacity(fadeIn)
        }
        .frame(width: 256, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: look) { look in
            guard isMoving else {
                shown = look
                return
            }
            previous = shown
            shown = look
            fadeIn = 0
            fade += 1
            let current = fade
            withAnimation(.easeInOut(duration: Self.fadeDuration)) { fadeIn = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeDuration) {
                if fade == current { previous = nil }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func sceneView(_ look: MenuSceneLook) -> some View {
        Group {
            switch scene {
            case .hourglass: HourglassScene(look: look, progress: progress, time: time)
            case .desk: DeskScene(look: look, time: time)
            case .cat: CatScene(look: look, time: time)
            case .penguin: PenguinScene(look: look, time: time)
            case .frog: FrogScene(look: look, time: time)
            case .fox: FoxScene(look: look, time: time)
            case .capybara: CapybaraScene(look: look, time: time)
            case .robot: RobotScene(look: look, time: time)
            case .campfire: CampfireScene(look: look, time: time)
            case .hamster: HamsterScene(look: look, time: time)
            case .sprout: SproutScene(look: look, time: time)
            case .coffee: CoffeeScene(look: look, time: time)
            case .bread: BreadScene(look: look, time: time)
            case .reading: ReadingScene(look: look, time: time)
            case .fishing: FishingScene(look: look, time: time)
            case .painting: PaintingScene(look: look, time: time)
            case .cooking: CookingScene(look: look, time: time)
            case .rainyDay: RainyDayScene(look: look, time: time)
            case .hammock: HammockScene(look: look, time: time)
            case .psychologist: PsychologistScene(look: look, time: time)
            case .off: EmptyView()
            }
        }
        .frame(width: 256, height: 136)
    }
}

/// A short blink every few seconds. `time` is nil for a still scene.
func sceneIsBlinking(_ time: TimeInterval?) -> Bool {
    guard let time else { return false }
    return time.truncatingRemainder(dividingBy: 4.2) < 0.15
}

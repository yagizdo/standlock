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

    private var time: TimeInterval? {
        isMoving ? date.timeIntervalSinceReferenceDate : nil
    }

    var body: some View {
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
            case .off: EmptyView()
            }
        }
        .frame(width: 256, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(isMoving ? .easeInOut(duration: 0.3) : nil, value: look)
        .accessibilityHidden(true)
    }
}

/// A short blink every few seconds. `time` is nil for a still scene.
func sceneIsBlinking(_ time: TimeInterval?) -> Bool {
    guard let time else { return false }
    return time.truncatingRemainder(dividingBy: 4.2) < 0.15
}

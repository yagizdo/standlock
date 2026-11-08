import SwiftUI
import StandLockCore

/// The menu bar scene, picked with the same picker Settings uses, over a large live preview.
struct OnboardingSceneStep: View {
    @Binding var scene: MenuScene

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var clock: PanelClock

    init(scene: Binding<MenuScene>) {
        _scene = scene
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        _clock = StateObject(wrappedValue: PanelClock(every: Self.tickInterval(scene: scene.wrappedValue, reduceMotion: reduceMotion)))
    }

    /// Twelve frames a second for a moving scene, the panel's rate. A still one shows no
    /// countdown here, so it needs no tick at all.
    static func tickInterval(scene: MenuScene, reduceMotion: Bool) -> TimeInterval? {
        reduceMotion || scene == .off ? nil : 1.0 / 12
    }

    var body: some View {
        VStack(spacing: SettingsTokens.sectionSpacing) {
            OnboardingHeading("Pick a scene", "It sits at the top of the menu bar panel and changes as your break gets closer.")

            preview

            SettingsSection {
                MenuScenePicker(selection: $scene)
            }
        }
        .onChange(of: Self.tickInterval(scene: scene, reduceMotion: reduceMotion)) { interval in
            clock.run(every: interval)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if scene == .off {
            RoundedRectangle(cornerRadius: SettingsTokens.cardRadius)
                .fill(Color.secondary.opacity(0.12))
                .overlay(Image(systemName: "nosign").font(.title).foregroundStyle(.secondary))
                .frame(width: 256, height: 136)
                .accessibilityHidden(true)
        } else {
            MenuSceneCard(scene: scene, look: .working, progress: 0.62, date: clock.now, isMoving: !reduceMotion)
        }
    }
}

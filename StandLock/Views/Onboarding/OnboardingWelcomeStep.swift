import SwiftUI
import StandLockCore

/// What StandLock does, in one picture and three facts.
struct OnboardingWelcomeStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var clock: PanelClock

    init() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        _clock = StateObject(wrappedValue: PanelClock(every: OnboardingSceneStep.tickInterval(scene: .hourglass, reduceMotion: reduceMotion)))
    }

    var body: some View {
        VStack(spacing: SettingsTokens.sectionSpacing) {
            MenuSceneCard(scene: .hourglass, look: .working, progress: 0.62, date: clock.now, isMoving: !reduceMotion)

            OnboardingHeading(
                "Breaks you can't ignore",
                "When a break is due, StandLock covers your screen with a countdown and an exercise. You decide how hard it is to get out."
            )

            SettingsSection {
                SettingsRow("Breaks wait for meetings, calls and screen sharing.", symbol: "video") { EmptyView() }
                SettingsRowDivider()
                SettingsRow("Already away from your desk? The break counts as done.", symbol: "figure.walk") { EmptyView() }
                SettingsRowDivider()
                SettingsRow("No account and no analytics. Everything stays on this Mac.", symbol: "eye.slash") { EmptyView() }
            }
        }
        .onChange(of: reduceMotion) { reduceMotion in
            clock.run(every: OnboardingSceneStep.tickInterval(scene: .hourglass, reduceMotion: reduceMotion))
        }
    }
}

import SwiftUI
import StandLockCore

/// The first-launch window: one step at a time over a bar with the step dots and the buttons.
/// It hands the coordinator the user's choices at Done; closing the window hands nothing.
struct OnboardingView: View {
    /// Fixed so the window does not jump between steps; a taller step scrolls.
    static let size = CGSize(width: 520, height: 640)

    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var checker: PermissionChecker
    @State private var step: OnboardingStep = .welcome
    @State private var choices: OnboardingChoices
    @State private var loginError: String?

    init(scene: MenuScene) {
        _choices = State(initialValue: OnboardingChoices(scene: scene))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                page
                    .padding(.horizontal, 28)
                    .padding(.top, 34)
                    .padding(.bottom, 8)
            }
            // A new step starts at its top.
            .id(step)

            bottomBar
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome: OnboardingWelcomeStep()
        case .schedule: OnboardingScheduleStep(choices: $choices)
        case .scene: OnboardingSceneStep(scene: $choices.scene)
        case .menuBar: OnboardingMenuBarStep(launchAtLogin: $choices.launchAtLogin, loginError: loginError)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            stepDots
                .padding(.trailing, 6)
            if step == .schedule {
                Button("Set Up Later") {
                    choices.createsSchedule = false
                    step = .scene
                }
                .controlSize(.large)
            }
            Spacer()
            if let previous = step.previous {
                Button("Back") { step = previous }
                    .controlSize(.large)
            }
            Button(primaryTitle, action: primary)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { dot in
                Circle()
                    .fill(dot == step ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(step.rawValue + 1) of 4"))
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .welcome, .scene: "Continue"
        case .schedule: "Create Schedule"
        case .menuBar: "Done"
        }
    }

    private func primary() {
        switch step {
        case .schedule:
            choices.createsSchedule = true
            // A Strict schedule without the permission runs as Firm, so the flow moves on.
            if choices.asksForStrictPermission(strictAvailable: checker.strictModeAvailable) {
                checker.requestStrictPermission()
            }
            step = .scene
        case .menuBar:
            do {
                try coordinator.finishOnboarding(with: choices)
            } catch {
                loginError = error.localizedDescription
            }
        case .welcome, .scene:
            if let next = step.next { step = next }
        }
    }
}

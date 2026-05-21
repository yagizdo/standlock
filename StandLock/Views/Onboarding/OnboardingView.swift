import SwiftUI
import StandLockCore

struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentStep {
                case 0:
                    WelcomeStepView {
                        withAnimation { currentStep = 1 }
                    }
                case 1:
                    PermissionsStepView {
                        withAnimation { currentStep = 2 }
                    }
                default:
                    QuickSetupStepView(
                        onCreateDefault: { escalationEnabled in
                            if escalationEnabled {
                                appCoordinator.preferences.escalationLevel = .strict
                                appCoordinator.savePreferences()
                            }
                            appCoordinator.createDefaultSchedule()
                            appCoordinator.completeOnboarding()
                            dismiss()
                        },
                        onSkip: {
                            appCoordinator.completeOnboarding()
                            dismiss()
                        }
                    )
                }
            }
            .transition(.push(from: .trailing))

            pageIndicator
                .padding(.bottom, 16)
        }
        .frame(width: 480)
        .frame(minHeight: 420)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.35), value: currentStep)
            }
        }
    }
}

import SwiftUI
import StandLockCore

struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                WelcomeStepView {
                    withAnimation { currentStep = 1 }
                }
                .tag(0)

                PermissionsStepView {
                    withAnimation { currentStep = 2 }
                }
                .tag(1)

                QuickSetupStepView(
                    onCreateDefault: {
                        appCoordinator.createDefaultSchedule()
                        appCoordinator.completeOnboarding()
                        dismiss()
                    },
                    onSkip: {
                        appCoordinator.completeOnboarding()
                        dismiss()
                    }
                )
                .tag(2)
            }
            .tabViewStyle(.automatic)

            pageIndicator
                .padding(.bottom, 16)
        }
        .frame(width: 480)
        .frame(minHeight: 420)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

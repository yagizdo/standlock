import SwiftUI

/// The title and one-paragraph message at the top of an onboarding step.
struct OnboardingHeading: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey

    init(_ title: LocalizedStringKey, _ message: LocalizedStringKey) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: SettingsTokens.blockSpacing) {
            Text(title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

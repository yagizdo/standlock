import SwiftUI
import StandLockCore

/// One choice in an onboarding card: a checkmark marks the selected row, with no fill.
struct OnboardingChoiceRow: View {
    let title: Text
    var detail: LocalizedStringKey?
    var symbol: String?
    var tone: DisciplineLevel?
    var isRecommended = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsTokens.rowSpacing) {
                if let symbol {
                    SettingsIconChip(symbol: symbol, tone: tone, size: SettingsTokens.rowChipSize)
                }
                VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
                    HStack(spacing: SettingsTokens.listItemSpacing) {
                        title
                        if isRecommended {
                            Text("Recommended")
                                .font(SettingsTokens.pillFont)
                                .foregroundStyle(.secondary)
                                .padding(SettingsTokens.pillInsets)
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(SettingsTokens.descriptionFont)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(SettingsTokens.rowInsets)
            .frame(minHeight: SettingsTokens.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

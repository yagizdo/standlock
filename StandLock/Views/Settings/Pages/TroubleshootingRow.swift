import SwiftUI

/// `SettingsRow` with its text always shown: these lines are states and the way out of a break.
struct TroubleshootingRow<Control: View>: View {
    @Environment(\.settingsRowTone) private var tone

    private let title: LocalizedStringKey
    private let symbol: String
    private let isWarning: Bool
    private let text: Text?
    private let control: Control

    init(
        _ title: LocalizedStringKey, symbol: String, isWarning: Bool = false, text: Text? = nil,
        @ViewBuilder control: () -> Control = { EmptyView() }
    ) {
        self.title = title
        self.symbol = symbol
        self.isWarning = isWarning
        self.text = text
        self.control = control()
    }

    var body: some View {
        HStack(spacing: SettingsTokens.rowSpacing) {
            Group {
                if isWarning {
                    Image(systemName: symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .systemOrange))
                        .frame(width: SettingsTokens.rowChipSize, height: SettingsTokens.rowChipSize)
                        .background(RoundedRectangle(cornerRadius: SettingsTokens.rowChipSize / 4)
                            .fill(Color(nsColor: .systemOrange).opacity(0.26)))
                        .accessibilityHidden(true)
                } else {
                    SettingsIconChip(symbol: symbol, tone: tone, size: SettingsTokens.rowChipSize)
                }
            }

            VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
                Text(title)
                if let text {
                    text
                        .font(SettingsTokens.descriptionFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            control
        }
        .padding(SettingsTokens.rowInsets)
        .frame(minHeight: SettingsTokens.rowMinHeight)
    }
}

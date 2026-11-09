import SwiftUI

/// Title and optional description on the left, control on the right. Warnings and errors do not
/// go in `description`: Show help hides it. `symbol` is required so a new row cannot forget its
/// chip; nil is for a row that draws its own status mark.
struct SettingsRow<Control: View>: View {
    @Environment(\.settingsRowTone) private var tone

    private let title: LocalizedStringKey
    private let symbol: String?
    private let description: LocalizedStringKey?
    private let expandsTitle: Bool
    private let control: Control

    init(
        _ title: LocalizedStringKey,
        symbol: String?,
        description: LocalizedStringKey? = nil,
        expandsTitle: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.symbol = symbol
        self.description = description
        self.expandsTitle = expandsTitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: SettingsTokens.rowSpacing) {
            if let symbol {
                SettingsIconChip(symbol: symbol, tone: tone, size: SettingsTokens.rowChipSize)
            }

            VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
                Text(title)
                if let description {
                    SettingsDescription(description)
                }
            }
            .frame(maxWidth: expandsTitle ? .infinity : nil, alignment: .leading)

            control
        }
        .padding(SettingsTokens.rowInsets)
        .frame(minHeight: SettingsTokens.rowMinHeight)
    }
}

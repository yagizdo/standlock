import SwiftUI

/// Title and optional description on the left, control on the right. Warnings and errors do not
/// go in `description`: Show help hides it.
struct SettingsRow<Control: View>: View {
    private let title: LocalizedStringKey
    private let description: LocalizedStringKey?
    private let control: Control

    init(
        _ title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(spacing: SettingsTokens.rowSpacing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let description {
                    Text(description)
                        .font(SettingsTokens.descriptionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
        }
        .padding(SettingsTokens.rowInsets)
        .frame(minHeight: SettingsTokens.rowMinHeight)
    }
}

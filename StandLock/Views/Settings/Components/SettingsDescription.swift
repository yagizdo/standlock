import SwiftUI

/// Help text under a row title or below a card, the one view Show help acts on. Warnings and
/// errors do not go here.
struct SettingsDescription: View {
    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(SettingsTokens.descriptionFont)
            .foregroundStyle(.secondary)
    }
}

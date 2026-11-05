import SwiftUI

/// Help text under a row title or below a card, the one view Show help acts on. Warnings and
/// errors do not go here.
struct SettingsDescription: View {
    /// Kept out of `preferences`, like the language and theme choices, so older builds ignore it.
    static let showHelpKey = "showHelp"

    @AppStorage(showHelpKey) private var showHelp = true

    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        if showHelp {
            Text(text)
                .font(SettingsTokens.descriptionFont)
                .foregroundStyle(.secondary)
        }
    }
}

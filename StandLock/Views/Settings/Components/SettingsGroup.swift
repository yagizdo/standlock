import SwiftUI

/// An optional heading and note around one or more cards.
struct SettingsGroup<Content: View>: View {
    private let title: LocalizedStringKey?
    private let note: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, note: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.sectionTitleSpacing) {
            if let title {
                Text(title)
                    .font(SettingsTokens.sectionTitleFont)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, SettingsTokens.sectionTitleInset)
            }

            VStack(alignment: .leading, spacing: SettingsTokens.cardSpacing) {
                content
            }

            if let note {
                SettingsDescription(note)
                    .padding(.horizontal, SettingsTokens.sectionTitleInset)
            }
        }
    }
}

import SwiftUI

/// An optional heading over a card, with an optional note below it. Pages put a `Divider()` between rows: macOS 13 has no public way for
/// this view to walk its content.
struct SettingsSection<Content: View>: View {
    private let title: LocalizedStringKey?
    private let note: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, note: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        let card = RoundedRectangle(cornerRadius: SettingsTokens.cardRadius)

        VStack(alignment: .leading, spacing: SettingsTokens.sectionTitleSpacing) {
            if let title {
                Text(title)
                    .font(SettingsTokens.sectionTitleFont)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, SettingsTokens.sectionTitleInset)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: card)
            .overlay(card.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))

            if let note {
                SettingsDescription(note)
                    .padding(.horizontal, SettingsTokens.sectionTitleInset)
            }
        }
    }
}

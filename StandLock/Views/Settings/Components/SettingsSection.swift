import SwiftUI

/// A heading over a card. Pages put a `Divider()` between rows: macOS 13 has no public way for
/// this view to walk its content.
struct SettingsSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let card = RoundedRectangle(cornerRadius: SettingsTokens.cardRadius)

        VStack(alignment: .leading, spacing: SettingsTokens.sectionTitleSpacing) {
            Text(title)
                .font(SettingsTokens.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: card)
            .overlay(card.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }
}

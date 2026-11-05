import SwiftUI

/// A page title that stays put above a scrolling column of sections.
struct SettingsPageLayout<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SettingsTokens.pageTitleFont)
                .accessibilityAddTraits(.isHeader)
                .padding(SettingsTokens.pageTitleInsets)

            ScrollView {
                VStack(alignment: .leading, spacing: SettingsTokens.sectionSpacing) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SettingsTokens.pageInset)
                .padding(.bottom, SettingsTokens.pageInset)
            }
        }
    }
}

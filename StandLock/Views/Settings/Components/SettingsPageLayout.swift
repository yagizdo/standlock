import SwiftUI

/// A page title that stays put above a scrolling column of sections.
struct SettingsPageLayout<Accessory: View, Content: View>: View {
    private let title: Text
    private let accessory: Accessory
    private let content: Content

    init(title: Text, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SettingsTokens.rowSpacing) {
                title
                    .font(SettingsTokens.pageTitleFont)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                accessory
            }
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

extension SettingsPageLayout where Accessory == EmptyView {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title: Text(title), accessory: { EmptyView() }, content: content)
    }
}

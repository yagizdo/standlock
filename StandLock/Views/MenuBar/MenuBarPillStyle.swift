import SwiftUI

/// A compact action in the panel's bottom row.
struct MenuBarPillStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .foregroundStyle(.primary)
            .opacity(isEnabled ? 1 : 0.4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(isHovered && isEnabled ? 0.12 : 0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .onHover { isHovered = $0 }
    }
}

/// A pill's glyph and title. The glyph is decoration: the button reads as its title alone.
struct MenuBarPillLabel: View {
    let title: LocalizedStringKey
    let symbol: String

    init(_ title: LocalizedStringKey, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .lineLimit(1)
        }
    }
}

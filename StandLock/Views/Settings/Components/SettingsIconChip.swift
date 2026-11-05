import SwiftUI
import StandLockCore

/// A glyph on a faint square of its own hue. Nil is neutral grey.
struct SettingsIconChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let symbol: String
    let tone: DisciplineLevel?
    let isSelected: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13))
            // A sidebar `Label` enlarges its icon past the chip otherwise.
            .imageScale(.medium)
            .foregroundStyle(glyphStyle)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(fillStyle))
            .accessibilityHidden(true)
    }

    // Hierarchical styles follow the selection fill; a fixed tone does not read on it.
    private var glyphStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(color)
    }

    private var fillStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(color.opacity(0.26))
    }

    private var color: Color {
        guard let tone else { return Color(nsColor: .systemGray) }
        // `themeStore.current` is not published, so it would miss a change of appearance.
        let theme = colorScheme == .dark ? AppTheme.dark : AppTheme.light
        return theme.palette(for: tone).accent
    }
}

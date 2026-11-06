import SwiftUI
import StandLockCore

/// A glyph on a faint square of its own hue. Nil is neutral grey.
struct SettingsIconChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let symbol: String
    let tone: DisciplineLevel?
    var isSelected = false
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: max(13, size * 0.56)))
            // A sidebar `Label` enlarges its icon past the chip otherwise.
            .imageScale(.medium)
            .foregroundStyle(glyphStyle)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size / 4).fill(fillStyle))
            .accessibilityHidden(true)
    }

    // Hierarchical styles follow the selection fill; a fixed tone does not read on it.
    private var glyphStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(color)
    }

    // No fill on selection: macOS 15 drew `.quaternary` here as a solid white square over the glyph.
    private var fillStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(Color.clear) : AnyShapeStyle(color.opacity(0.26))
    }

    private var color: Color {
        guard let tone else { return Color(nsColor: .systemGray) }
        // `themeStore.current` is not published, so it would miss a change of appearance.
        let theme = colorScheme == .dark ? AppTheme.dark : AppTheme.light
        return theme.palette(for: tone).accent
    }
}

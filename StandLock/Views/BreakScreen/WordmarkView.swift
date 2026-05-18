import SwiftUI

struct WordmarkView: View {
    let palette: BreakPalette

    var body: some View {
        HStack(spacing: 0) {
            Text("STAND")
            Text("\u{00B7}")
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 2)
            Text("LOCK")
        }
        .font(BreakTypography.label(size: 11, weight: .semibold))
        .tracking(3.74)
        .foregroundStyle(palette.inkSoft)
    }
}

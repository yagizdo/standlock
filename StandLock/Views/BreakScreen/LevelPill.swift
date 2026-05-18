import SwiftUI
import StandLockCore

struct LevelPill: View {
    let level: DisciplineLevel
    let palette: BreakPalette

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(palette.accent)
                .frame(width: 6, height: 6)
            Text(level.displayName.uppercased())
                .font(BreakTypography.label(size: 11, weight: .semibold))
                .tracking(3.08)
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(palette.accent.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(palette.accent, lineWidth: 1)
        )
    }
}

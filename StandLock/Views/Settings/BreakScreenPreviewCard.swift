import SwiftUI
import StandLockCore

/// A small Gentle break screen drawn with the resolved look, so Settings shows a change
/// before the next break does.
struct BreakScreenPreviewCard: View {
    let look: BreakScreenLook
    /// Already trimmed, as `BreakScreenPreferences.displayMessage` gives it.
    let message: String
    let statistics: BreakStatistics?

    var body: some View {
        VStack(spacing: 10) {
            LevelPill(level: .gentle, palette: look.palette)

            Text(verbatim: "05:00")
                .font(BreakTypography.timerNumerals(size: 44))
                .foregroundStyle(look.palette.ink)

            if !message.isEmpty {
                Text(verbatim: message)
                    .font(BreakTypography.exerciseBody())
                    .foregroundStyle(look.palette.inkSoft)
                    .lineLimit(1)
            }

            if let statistics {
                StatsFooter(statistics: statistics, palette: look.palette)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RadialGradient(
                    colors: [look.palette.paper, look.palette.paperEdge],
                    center: .center,
                    startRadius: 0,
                    endRadius: 240
                ))
        )
        .environment(\.colorScheme, look.colorScheme)
    }
}

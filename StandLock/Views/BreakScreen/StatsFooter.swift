import SwiftUI
import StandLockCore

struct StatsFooter: View {
    let statistics: BreakStatistics
    let palette: BreakPalette

    var body: some View {
        HStack(spacing: 0) {
            Text("\(statistics.breaksCompleted) completed")
            Text("   \u{00B7}   ")
            Text("\(statistics.currentStreak)-day streak")
            Text("   \u{00B7}   ")
            Text("\(statistics.breaksSkipped) skipped today")
        }
        .font(BreakTypography.label(size: 11, weight: .medium))
        .tracking(0.12)
        .foregroundStyle(palette.inkFaint)
    }
}

import SwiftUI
import StandLockCore

/// A leaf, so the clock's publishes and the countdown's ticks stop here and never reach the
/// sidebar body.
struct NextBreakStatus: View {
    @StateObject private var clock: NextBreakClock

    init(coordinator: AppCoordinator) {
        _clock = StateObject(wrappedValue: NextBreakClock(coordinator: coordinator))
    }

    var body: some View {
        status
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        switch clock.state {
        case .breakActive:
            Text("Break in progress")
        case .paused(let until):
            Text("Paused until \(until, style: .time)")
        case .deferred(let reason):
            VStack(alignment: .leading, spacing: SettingsTokens.sidebarFooterLineSpacing) {
                Text("Break waiting")
                    .foregroundStyle(.primary)
                Text(LocalizedStringKey(reason.displayName))
            }
        case .countingDown(let nextBreak):
            HStack(alignment: .firstTextBaseline) {
                Text("Next break")
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatCountdown(secondsRemaining: breakSecondsRemaining(until: nextBreak, now: context.date)))
                        .font(BreakTypography.timerNumerals(size: SettingsTokens.countdownSize))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }
        case .noSchedules:
            Text("No schedules configured")
        case .noActiveSchedules:
            Text("No active schedules")
        }
    }
}

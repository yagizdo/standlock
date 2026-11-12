import SwiftUI
import StandLockCore

/// A leaf, so the clock's publishes stop here. Says why breaks are or are not coming, with the
/// button Kit picks for that state.
struct TroubleshootingStatusRow: View {
    @StateObject private var clock: NextBreakClock
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _clock = StateObject(wrappedValue: NextBreakClock(coordinator: coordinator))
    }

    var body: some View {
        let state = clock.state
        TroubleshootingRow(title(state), symbol: symbol(state), text: text(state)) {
            if let fix = TroubleshootingFix(state) {
                button(fix)
            }
        }
    }

    private func title(_ state: NextBreakState) -> LocalizedStringKey {
        switch state {
        case .breakActive: "Break in progress"
        case .paused(let until): "Breaks are paused until \(Text(until, style: .time))"
        case .deferred: "Break waiting"
        case .countingDown: "Breaks are on"
        case .noSchedules: "No schedules configured"
        case .noActiveSchedules: "No active schedules"
        }
    }

    private func symbol(_ state: NextBreakState) -> String {
        switch state {
        case .paused: "pause.circle"
        case .deferred: "hourglass"
        case .noSchedules, .noActiveSchedules: "calendar"
        case .breakActive, .countingDown: "clock"
        }
    }

    private func text(_ state: NextBreakState) -> Text? {
        switch state {
        case .deferred(let reason): Text(LocalizedStringKey(reason.displayName))
        case .countingDown(let next): Text("Next break at \(Text(next, style: .time))")
        case .breakActive, .paused, .noSchedules, .noActiveSchedules: nil
        }
    }

    @ViewBuilder
    private func button(_ fix: TroubleshootingFix) -> some View {
        let navigation = coordinator.settingsNavigation
        switch fix {
        case .resume:
            Button("Resume") { coordinator.resumeSchedule() }
        case .openSchedules:
            Button("Open Schedules") {
                navigation.select(.firstSchedule(in: coordinator.schedules.map(\.id)))
            }
        case .openDetection:
            Button("Open Detection") { navigation.select(.detection) }
        }
    }
}

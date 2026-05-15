import SwiftUI
import StandLockCore

struct QuickActionsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    private var activeSchedule: Schedule? {
        coordinator.schedules.first(where: \.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if coordinator.isPaused {
                Button {
                    coordinator.resumeSchedule()
                } label: {
                    Label("Resume Schedule", systemImage: "play.fill")
                }
            } else {
                Button {
                    coordinator.skipNextBreak()
                } label: {
                    Label("Skip Next Break", systemImage: "forward.end")
                }
                .disabled(coordinator.schedules.isEmpty || coordinator.isBreakActive)

                Menu {
                    Button("30 minutes") { coordinator.pauseSchedule(for: 30 * 60) }
                    Button("1 hour") { coordinator.pauseSchedule(for: 60 * 60) }
                    Button("2 hours") { coordinator.pauseSchedule(for: 2 * 60 * 60) }
                } label: {
                    Label("Pause Schedule", systemImage: "pause.circle")
                }
                .disabled(coordinator.schedules.isEmpty)
            }

            if let schedule = activeSchedule {
                Divider()
                scheduleInfo(schedule)
            }
        }
    }

    private func scheduleInfo(_ schedule: Schedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(schedule.disciplineLevel.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(levelIcon(schedule.disciplineLevel))
                .font(.caption)
        }
    }

    private func levelIcon(_ level: DisciplineLevel) -> String {
        switch level {
        case .gentle: "🟢"
        case .firm: "🟡"
        case .strict: "🔴"
        }
    }
}

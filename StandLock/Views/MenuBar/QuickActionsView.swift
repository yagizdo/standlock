import SwiftUI
import StandLockCore

struct QuickActionsView: View {
    @Environment(AppCoordinator.self) private var coordinator

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

            Divider()

            levelPicker
        }
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Discipline Level")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Level", selection: Binding(
                get: { coordinator.currentLevel },
                set: { coordinator.changeDisciplineLevel($0) }
            )) {
                ForEach(DisciplineLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

import SwiftUI
import StandLockCore

struct ScheduleEditorView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var editingSchedule: Schedule?
    @State private var showingForm = false

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.schedules.isEmpty {
                emptyState
            } else {
                scheduleList
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    editingSchedule = nil
                    showingForm = true
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
                .padding(12)
            }
        }
        .sheet(isPresented: $showingForm) {
            ScheduleFormView(
                schedule: editingSchedule,
                onSave: { schedule in
                    if editingSchedule != nil {
                        coordinator.updateSchedule(schedule)
                    } else {
                        coordinator.addSchedule(schedule)
                    }
                    showingForm = false
                },
                onCancel: { showingForm = false }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Schedules")
                .font(.headline)
            Text("Add a schedule to start taking breaks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scheduleList: some View {
        List {
            ForEach(coordinator.schedules) { schedule in
                ScheduleRow(
                    schedule: schedule,
                    onToggle: { enabled in
                        var updated = schedule
                        updated.isEnabled = enabled
                        coordinator.updateSchedule(updated)
                    },
                    onEdit: {
                        editingSchedule = schedule
                        showingForm = true
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    coordinator.deleteSchedule(coordinator.schedules[index])
                }
            }
        }
    }
}

private struct ScheduleRow: View {
    let schedule: Schedule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text(daysSummary)
                    Text("•")
                    Text(windowSummary)
                    Text("•")
                    Text(intervalSummary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            levelBadge

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var daysSummary: String {
        switch schedule.days {
        case .everyDay: return "Every day"
        case .weekdays: return "Mon-Fri"
        case .weekends: return "Sat-Sun"
        case .custom(let days):
            return days.sorted().map(\.shortName).joined(separator: ", ")
        }
    }

    private var windowSummary: String {
        guard let w = schedule.windows.first else { return "All day" }
        return String(format: "%02d:%02d-%02d:%02d", w.startHour, w.startMinute, w.endHour, w.endMinute)
    }

    private var intervalSummary: String {
        let minutes = Int(schedule.breakInterval / 60)
        return "every \(minutes)m"
    }

    private var levelBadge: some View {
        Text(schedule.disciplineLevel.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(levelColor.opacity(0.15), in: Capsule())
            .foregroundStyle(levelColor)
    }

    private var levelColor: Color {
        switch schedule.disciplineLevel {
        case .gentle: .green
        case .firm: .orange
        case .strict: .red
        }
    }
}

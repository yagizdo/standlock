import SwiftUI
import StandLockCore

struct ScheduleEditorView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var sheetMode: SheetMode?

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
                    sheetMode = .add
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
                .padding(12)
            }
        }
        .sheet(item: $sheetMode) { mode in
            ScheduleFormView(
                schedule: mode.schedule,
                onSave: { schedule in
                    switch mode {
                    case .add:
                        coordinator.addSchedule(schedule)
                    case .edit:
                        coordinator.updateSchedule(schedule)
                    }
                    sheetMode = nil
                },
                onCancel: { sheetMode = nil }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
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
                        sheetMode = .edit(schedule)
                    },
                    onDelete: {
                        coordinator.deleteSchedule(schedule)
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

private enum SheetMode: Identifiable {
    case add
    case edit(Schedule)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let schedule): schedule.id.uuidString
        }
    }

    var schedule: Schedule? {
        switch self {
        case .add: nil
        case .edit(let schedule): schedule
        }
    }
}

private struct ScheduleRow: View {
    let schedule: Schedule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .tint(.green)
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

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDeleteConfirmation) {
                DeleteConfirmationView(
                    scheduleName: schedule.name,
                    onCancel: { showDeleteConfirmation = false },
                    onDelete: {
                        showDeleteConfirmation = false
                        onDelete()
                    }
                )
            }
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
        Text(schedule.disciplineLevel.displayName + (schedule.progressiveEnforcement ? "+" : ""))
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

private struct DeleteConfirmationView: View {
    let scheduleName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Delete Schedule")
                .font(.headline)

            Text("Are you sure you want to delete \"\(scheduleName)\"?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 260)
    }
}

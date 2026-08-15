import SwiftUI
import StandLockCore

struct ScheduleFormView: View {
    let schedule: Schedule?
    let onSave: (Schedule) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var dayPreset: DayPreset = .weekdays
    @State private var customDays: Set<Weekday> = []
    @State private var windows: [TimeWindow] = [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)]
    @State private var intervalRows: [IntervalRowModel] = [IntervalRowModel(minutes: 40)]
    @State private var breakDurationMinutes: Int = 10
    @State private var useRepetition: Bool = false
    @State private var shortBreakCount: Int = 3
    @State private var shortBreakMinutes: Int = 10
    @State private var longBreakMinutes: Int = 30
    @State private var disciplineLevel: DisciplineLevel = .gentle
    @State private var progressiveEnforcement: Bool = false

    private var isEditing: Bool { schedule != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    daysSection
                    windowsSection
                    timingSection
                    repetitionSection
                    levelSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 560)
        .onAppear { loadSchedule() }
    }

    // MARK: - Header / Footer

    private var header: some View {
        Text(isEditing ? "Edit Schedule" : "New Schedule")
            .font(.headline)
            .padding(12)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button(isEditing ? "Save" : "Add Schedule") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline.weight(.medium))
            TextField("e.g. Work Hours", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Days")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                presetButton("Weekdays", preset: .weekdays)
                presetButton("Weekends", preset: .weekends)
                presetButton("Every Day", preset: .everyDay)
                presetButton("Custom", preset: .custom)
            }

            if dayPreset == .custom {
                HStack(spacing: 4) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let isSelected = customDays.contains(day)
                        Button(day.shortName) {
                            if isSelected { customDays.remove(day) }
                            else { customDays.insert(day) }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
            }
        }
    }

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Time Windows")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    windows.append(TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            // Bound by identity, not index: removing a row while indices are the identity leaves
            // SwiftUI holding a stale index and the `$windows[index]` bindings read out of range.
            ForEach($windows) { $window in
                HStack(spacing: 8) {
                    timePicker("Start", hour: $window.startHour, minute: $window.startMinute)
                    Text("to")
                        .foregroundStyle(.secondary)
                    timePicker("End", hour: $window.endHour, minute: $window.endMinute)

                    if windows.count > 1 {
                        Button {
                            windows.removeAll { $0.id == window.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timing")
                .font(.subheadline.weight(.medium))

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break every")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Bound by identity for the same reason as the windows section.
                    ForEach($intervalRows) { $row in
                        HStack(spacing: 4) {
                            TextField("", value: $row.minutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .onChange(of: row.minutes) { newValue in
                                    row.minutes = max(1, min(180, newValue))
                                }
                            Stepper("", value: $row.minutes, in: 1...180, step: 5)
                                .labelsHidden()
                            Text("min")
                                .foregroundStyle(.secondary)

                            if intervalRows.count > 1 {
                                TextField("Label (optional, e.g. Sitting)", text: $row.label)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    intervalRows.removeAll { $0.id == row.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if intervalRows.count < 6 {
                        Button {
                            intervalRows.append(IntervalRowModel(minutes: 40))
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Break duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("", value: $breakDurationMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .onChange(of: breakDurationMinutes) { newValue in
                                breakDurationMinutes = max(1, min(60, newValue))
                            }
                        Stepper("", value: $breakDurationMinutes, in: 1...60, step: 1)
                            .labelsHidden()
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if intervalRows.count > 1 {
                Text("Breaks cycle through these intervals in order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var repetitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Repetition Cycle", isOn: $useRepetition)
                .font(.subheadline.weight(.medium))

            if useRepetition {
                VStack(alignment: .leading, spacing: 6) {
                    Text("e.g. 3 short breaks, then 1 long break")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Stepper("Short breaks: \(shortBreakCount)", value: $shortBreakCount, in: 1...10)
                        Stepper("Short: \(shortBreakMinutes)m", value: $shortBreakMinutes, in: 1...30)
                    }

                    Stepper("Long break: \(longBreakMinutes)m", value: $longBreakMinutes, in: 5...60, step: 5)
                }
                .padding(.leading, 4)
            }
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discipline Level")
                .font(.subheadline.weight(.medium))
            DisciplineLevelPicker(selection: $disciplineLevel)
            Toggle("Progressive Enforcement", isOn: $progressiveEnforcement)
            Text("Makes each skipped break harder to dismiss")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func presetButton(_ label: String, preset: DayPreset) -> some View {
        Button(label) { dayPreset = preset }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(dayPreset == preset ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .foregroundStyle(dayPreset == preset ? .white : .primary)
    }

    private func timePicker(_ label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker(label, selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 60)

            Text(":")

            Picker("", selection: minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 60)
        }
    }

    private func loadSchedule() {
        guard let s = schedule else { return }
        name = s.name
        windows = s.windows
        if let cycle = s.intervalCycle, !cycle.isEmpty {
            intervalRows = cycle.map { IntervalRowModel(minutes: Int($0.duration / 60), label: $0.label ?? "") }
        } else {
            intervalRows = [IntervalRowModel(minutes: Int(s.breakInterval / 60))]
        }
        breakDurationMinutes = Int(s.breakDuration / 60)
        disciplineLevel = s.disciplineLevel
        progressiveEnforcement = s.progressiveEnforcement

        switch s.days {
        case .everyDay: dayPreset = .everyDay
        case .weekdays: dayPreset = .weekdays
        case .weekends: dayPreset = .weekends
        case .custom(let days):
            dayPreset = .custom
            customDays = days
        }

        if let rule = s.repetitionRule {
            useRepetition = true
            shortBreakCount = rule.shortBreakCount
            shortBreakMinutes = Int(rule.shortBreakDuration / 60)
            longBreakMinutes = Int(rule.longBreakDuration / 60)
        }
    }

    private func save() {
        let days: DaySelection = switch dayPreset {
        case .everyDay: .everyDay
        case .weekdays: .weekdays
        case .weekends: .weekends
        case .custom: .custom(customDays.isEmpty ? [.monday] : customDays)
        }

        let repetitionRule: RepetitionRule? = useRepetition
            ? RepetitionRule(
                shortBreakCount: shortBreakCount,
                shortBreakDuration: TimeInterval(shortBreakMinutes * 60),
                longBreakDuration: TimeInterval(longBreakMinutes * 60)
            )
            : nil

        let steps = intervalRows.map { row -> IntervalStep in
            let trimmed = row.label.trimmingCharacters(in: .whitespaces)
            return IntervalStep(duration: TimeInterval(row.minutes * 60),
                                label: trimmed.isEmpty ? nil : trimmed)
        }
        // A single row is the canonical single-interval schedule; `breakInterval` always
        // mirrors the first entry so old readers see a sane single interval. The label field
        // is hidden at one row, so a label left over from a deleted row must not persist --
        // it would be invisible, unclearable, and still drive the break screen.
        let intervalCycle: [IntervalStep]? = steps.count == 1 ? nil : steps

        let result = Schedule(
            id: schedule?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            isEnabled: schedule?.isEnabled ?? true,
            days: days,
            windows: windows,
            breakInterval: steps[0].duration,
            breakDuration: TimeInterval(breakDurationMinutes * 60),
            intervalCycle: intervalCycle,
            repetitionRule: repetitionRule,
            disciplineLevel: disciplineLevel,
            progressiveEnforcement: progressiveEnforcement
        )
        onSave(result)
    }
}

/// Session-only row identity, same non-persisted-id pattern as `TimeWindow.id`.
private struct IntervalRowModel: Identifiable {
    let id = UUID()
    var minutes: Int
    var label: String = ""
}

private enum DayPreset {
    case everyDay, weekdays, weekends, custom
}

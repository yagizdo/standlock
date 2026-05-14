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
    @State private var breakIntervalMinutes: Int = 40
    @State private var breakDurationMinutes: Int = 10
    @State private var useRepetition: Bool = false
    @State private var shortBreakCount: Int = 3
    @State private var shortBreakMinutes: Int = 10
    @State private var longBreakMinutes: Int = 30
    @State private var disciplineLevel: DisciplineLevel = .gentle

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

            ForEach(windows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    timePicker("Start", hour: $windows[index].startHour, minute: $windows[index].startMinute)
                    Text("to")
                        .foregroundStyle(.secondary)
                    timePicker("End", hour: $windows[index].endHour, minute: $windows[index].endMinute)

                    if windows.count > 1 {
                        Button {
                            windows.remove(at: index)
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

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break every")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("", value: $breakIntervalMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Stepper("", value: $breakIntervalMinutes, in: 1...180, step: 5)
                            .labelsHidden()
                        Text("min")
                            .foregroundStyle(.secondary)
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
                        Stepper("", value: $breakDurationMinutes, in: 1...60, step: 1)
                            .labelsHidden()
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
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
        breakIntervalMinutes = Int(s.breakInterval / 60)
        breakDurationMinutes = Int(s.breakDuration / 60)
        disciplineLevel = s.disciplineLevel

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

        let result = Schedule(
            id: schedule?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            isEnabled: schedule?.isEnabled ?? true,
            days: days,
            windows: windows,
            breakInterval: TimeInterval(breakIntervalMinutes * 60),
            breakDuration: TimeInterval(breakDurationMinutes * 60),
            repetitionRule: repetitionRule,
            disciplineLevel: disciplineLevel
        )
        onSave(result)
    }
}

private enum DayPreset {
    case everyDay, weekdays, weekends, custom
}

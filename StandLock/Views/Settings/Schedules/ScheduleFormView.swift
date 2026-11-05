import SwiftUI
import StandLockCore

struct ScheduleFormView: View {
    @Binding var draft: ScheduleDraft

    @Environment(\.locale) private var locale

    var body: some View {
        nameSection
        whenSection
        timingSection
        disciplineSection
    }

    // MARK: - Sections

    private var nameSection: some View {
        SettingsSection("Name") {
            SettingsRow("Name") {
                TextField("e.g. Work Hours", text: $draft.name)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SettingsTokens.textFieldWidth)
            }
        }
    }

    private var whenSection: some View {
        SettingsSection("When") {
            daysBlock
            Divider()
            windowsBlock
        }
    }

    private var daysBlock: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
            Text("Active Days")

            HStack(spacing: SettingsTokens.blockSpacing) {
                presetButton("Weekdays", preset: .weekdays)
                presetButton("Weekends", preset: .weekends)
                presetButton("Every Day", preset: .everyDay)
                presetButton("Custom", preset: .custom)
            }

            if draft.dayPreset == .custom {
                HStack(spacing: SettingsTokens.stripItemSpacing) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let isSelected = draft.customDays.contains(day)
                        Button(WeekdaySymbols(locale: locale).short(for: day)) {
                            if isSelected { draft.customDays.remove(day) }
                            else { draft.customDays.insert(day) }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .padding(SettingsTokens.dayInsets)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsTokens.chipRadius)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    private var windowsBlock: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
            HStack {
                Text("Time Windows")
                Spacer()
                Button {
                    draft.windows.append(TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Time Window")
            }

            // Bound by identity, not index: removing a row while indices are the identity leaves
            // SwiftUI holding a stale index and the `$windows[index]` bindings read out of range.
            ForEach($draft.windows) { $window in
                HStack(spacing: SettingsTokens.blockSpacing) {
                    timePicker("Start", hour: $window.startHour, minute: $window.startMinute)
                    Text("to")
                        .foregroundStyle(.secondary)
                    timePicker("End", hour: $window.endHour, minute: $window.endMinute)

                    if draft.windows.count > 1 {
                        Button {
                            draft.windows.removeAll { $0.id == window.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove Time Window")
                    }
                }
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    private var timingSection: some View {
        SettingsSection("Timing") {
            intervalsBlock
            Divider()
            SettingsRow("Break duration") {
                minutesField("Break duration", value: $draft.breakDurationMinutes, range: ScheduleDraft.breakRange)
            }
            Divider()
            SettingsToggleRow(
                "Repetition Cycle",
                description: draft.useRepetition ? "e.g. 3 short breaks, then 1 long break" : nil,
                isOn: $draft.useRepetition
            )
            if draft.useRepetition {
                Divider()
                repetitionBlock
            }
        }
    }

    private var intervalsBlock: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
            HStack {
                Text("Break every")
                Spacer()
                if draft.intervalRows.count < 6 {
                    Button {
                        draft.intervalRows.append(IntervalRow(minutes: 40))
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Interval")
                }
            }

            // Bound by identity for the same reason as the windows section.
            ForEach($draft.intervalRows) { $row in
                HStack(spacing: SettingsTokens.stripItemSpacing) {
                    TextField("", value: $row.minutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: SettingsTokens.numberFieldWidth)
                        .accessibilityLabel("Break every")
                        .onChange(of: row.minutes) { newValue in
                            row.minutes = ScheduleDraft.clamped(newValue, to: ScheduleDraft.intervalRange)
                        }
                    Stepper("Break every", value: $row.minutes, in: ScheduleDraft.intervalRange, step: 5)
                        .labelsHidden()
                    Text("min")
                        .foregroundStyle(.secondary)

                    if draft.intervalRows.count > 1 {
                        TextField("Label (optional, e.g. Sitting)", text: $row.label)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                        Button {
                            draft.intervalRows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove Interval")
                    }
                }
            }

            if draft.intervalRows.count > 1 {
                SettingsDescription("Breaks cycle through these intervals in order.")
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    private var repetitionBlock: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
            Stepper("Short breaks: \(draft.shortBreakCount)", value: $draft.shortBreakCount, in: 1...10)
            HStack(spacing: SettingsTokens.stripItemSpacing) {
                Text("Short break")
                minutesField("Short break", value: $draft.shortBreakMinutes, range: ScheduleDraft.shortBreakRange)
            }
            Stepper("Long break: \(draft.longBreakMinutes)m", value: $draft.longBreakMinutes, in: 5...60, step: 5)
        }
        .padding(SettingsTokens.rowInsets)
    }

    private var disciplineSection: some View {
        SettingsSection("Discipline") {
            DisciplineLevelPicker(selection: $draft.disciplineLevel)
                .padding(SettingsTokens.rowInsets)
            Divider()
            SettingsToggleRow(
                "Progressive Enforcement",
                description: "Makes each skipped break harder to dismiss",
                isOn: $draft.progressiveEnforcement
            )
        }
    }

    // MARK: - Helpers

    private func presetButton(_ label: LocalizedStringKey, preset: DayPreset) -> some View {
        let isSelected = draft.dayPreset == preset
        return Button(label) { draft.dayPreset = preset }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .padding(SettingsTokens.presetInsets)
            .background(
                RoundedRectangle(cornerRadius: SettingsTokens.chipRadius)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func timePicker(_ label: LocalizedStringKey, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: SettingsTokens.rowTextSpacing) {
            Picker(label, selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: SettingsTokens.timePickerWidth)

            Text(":")

            Picker(label, selection: minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: SettingsTokens.timePickerWidth)
        }
    }

    /// Minutes field with a stepper. Accepts decimals so a break can be shorter
    /// than a minute: 0.5 is thirty seconds, the floor 0.1 is six seconds.
    private func minutesField(_ label: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: SettingsTokens.numberFieldWidth)
                .accessibilityLabel(label)
                .onChange(of: value.wrappedValue) { newValue in
                    value.wrappedValue = ScheduleDraft.clamped(newValue, to: range)
                }
            // ponytail: step stays 1, so 0.5 steps to 1.5; typing is how you reach a fraction.
            Stepper(label, value: value, in: range, step: 1)
                .labelsHidden()
            Text("min")
                .foregroundStyle(.secondary)
        }
    }
}

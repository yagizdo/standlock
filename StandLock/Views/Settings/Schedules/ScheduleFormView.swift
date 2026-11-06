import SwiftUI
import StandLockCore

struct ScheduleFormView: View {
    @Binding var draft: ScheduleDraft

    var body: some View {
        nameSection
        whenSection
        rhythmSection
        disciplineSection
    }

    // MARK: - Sections

    private var nameSection: some View {
        SettingsSection {
            SettingsRow("Name", symbol: "textformat") {
                TextField("e.g. Work Hours", text: $draft.name)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SettingsTokens.textFieldWidth)
            }
        }
    }

    private var whenSection: some View {
        SettingsSection("When") {
            DayButtons(days: $draft.days)
                .padding(SettingsTokens.rowInsets)
            Divider()
            // Bound by identity, not index: removing a row while indices are the identity leaves
            // SwiftUI holding a stale index and the `$windows[index]` bindings read out of range.
            ForEach($draft.windows) { $window in
                if window.id == draft.windows.first?.id {
                    SettingsRow("Hours", symbol: "clock") {
                        windowControls($window)
                    }
                } else {
                    SettingsRowDivider()
                    windowControls($window)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(SettingsTokens.rowInsets)
                }
            }
        }
    }

    private func windowControls(_ window: Binding<TimeWindow>) -> some View {
        let id = window.wrappedValue.id
        return HStack(spacing: SettingsTokens.blockSpacing) {
            timePicker("Start", hour: window.startHour, minute: window.startMinute)
            Text("to")
                .foregroundStyle(.secondary)
            timePicker("End", hour: window.endHour, minute: window.endMinute)

            if draft.windows.count > 1 {
                Button {
                    draft.windows.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Time Window")
            }

            // Hidden, not left out, so the pickers of every row stay in line.
            if id == draft.windows.first?.id {
                addWindowButton
            } else {
                addWindowButton.hidden()
            }
        }
        // The row's title column would otherwise squeeze "to" and the colons down to nothing.
        .fixedSize()
    }

    private var addWindowButton: some View {
        Button {
            draft.windows.append(TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
        } label: {
            Image(systemName: "plus.circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Time Window")
    }

    private var rhythmSection: some View {
        SettingsGroup("Rhythm") {
            HStack(spacing: SettingsTokens.cardSpacing) {
                RhythmTile(
                    title: "Break every",
                    symbol: "timer",
                    value: firstInterval,
                    range: Self.intervalMinutes,
                    step: 5
                )
                RhythmTile(
                    title: "Break lasts",
                    symbol: "hourglass",
                    value: $draft.breakDurationMinutes,
                    range: ScheduleDraft.breakRange,
                    step: 1
                )
            }

            SettingsSection {
                intervalsBlock
                SettingsRowDivider()
                SettingsToggleRow(
                    "Repetition Cycle",
                    symbol: "repeat",
                    description: draft.useRepetition ? "e.g. 3 short breaks, then 1 long break" : nil,
                    isOn: $draft.useRepetition
                )
                if draft.useRepetition {
                    Divider()
                    repetitionBlock
                }
            }
        }
    }

    private static let intervalMinutes =
        Double(ScheduleDraft.intervalRange.lowerBound)...Double(ScheduleDraft.intervalRange.upperBound)

    /// Clamped before the conversion: a typed "NaN" or a huge number would trap `Int(_:)`.
    private var firstInterval: Binding<Double> {
        Binding(
            get: { Double(draft.intervalRows[0].minutes) },
            set: { draft.intervalRows[0].minutes = Int(ScheduleDraft.clamped($0, to: Self.intervalMinutes)) }
        )
    }

    private var intervalsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(
                "Alternating intervals",
                symbol: "arrow.2.squarepath",
                description: draft.intervalRows.count > 1 ? "Breaks cycle through these intervals in order." : nil
            ) {
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

            if draft.intervalRows.count > 1 {
                VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
                    // Bound by identity for the same reason as the windows section.
                    ForEach($draft.intervalRows) { $row in
                        intervalRow($row)
                    }
                }
                .padding(.leading, SettingsTokens.rowTextInset)
                .padding(.trailing, SettingsTokens.rowInsets.trailing)
                .padding(.bottom, SettingsTokens.rowInsets.bottom)
            }
        }
    }

    /// The first interval's number lives in the tile above, so here it is only read back.
    private func intervalRow(_ row: Binding<IntervalRow>) -> some View {
        let id = row.wrappedValue.id
        return HStack(spacing: SettingsTokens.stripItemSpacing) {
            Group {
                if id == draft.intervalRows.first?.id {
                    Text("\(row.wrappedValue.minutes) min")
                        .monospacedDigit()
                } else {
                    HStack(spacing: SettingsTokens.stripItemSpacing) {
                        TextField("", value: row.minutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: SettingsTokens.numberFieldWidth)
                            .accessibilityLabel("Break every")
                            .onChange(of: row.wrappedValue.minutes) { newValue in
                                row.wrappedValue.minutes = ScheduleDraft.clamped(newValue, to: ScheduleDraft.intervalRange)
                            }
                        Stepper("Break every", value: row.minutes, in: ScheduleDraft.intervalRange, step: 5)
                            .labelsHidden()
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: SettingsTokens.intervalValueWidth, alignment: .leading)

            TextField("Label (optional, e.g. Sitting)", text: row.label)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            Button {
                draft.intervalRows.removeAll { $0.id == id }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove Interval")
        }
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
                symbol: "chart.line.uptrend.xyaxis",
                description: "Makes each skipped break harder to dismiss",
                isOn: $draft.progressiveEnforcement
            )
        }
    }

    // MARK: - Helpers

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

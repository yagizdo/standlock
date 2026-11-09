import SwiftUI
import StandLockCore

/// The short duration has one visible editor, including when longer breaks are enabled.
struct ScheduleRhythmSection: View {
    @Binding var draft: ScheduleDraft

    var body: some View {
        SettingsSection("Rhythm") {
            VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SettingsTokens.stripItemSpacing) {
                        workClause
                        breakClause
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
                        workClause
                        breakClause
                    }
                }

                if draft.intervalRows.count == 1 {
                    addInterval("Vary work intervals")
                } else {
                    SettingsDescription("Work intervals repeat in this order.")
                    ForEach($draft.intervalRows) { $row in
                        interval($row)
                    }
                    addInterval("Add interval")
                        .disabled(draft.intervalRows.count >= 6)
                }
            }
            .padding(SettingsTokens.rowInsets)

            Divider()
            SettingsToggleRow("Add longer breaks", symbol: "hourglass", isOn: Binding(
                get: { draft.useRepetition },
                set: { draft.setLongBreaksEnabled($0) }
            ))
            if draft.useRepetition {
                Divider()
                VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: SettingsTokens.stripItemSpacing) {
                            longCountClause
                            longDurationClause
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
                            longCountClause
                            longDurationClause
                        }
                    }
                    if !draft.hasValidLongBreak {
                        Text("Longer break must be longer than the short break.")
                            .font(SettingsTokens.descriptionFont)
                            .foregroundStyle(.red)
                    }
                }
                .padding(SettingsTokens.rowInsets)
                .padding(.leading, SettingsTokens.rowChipSize + SettingsTokens.rowSpacing)
            }
        }
    }

    @ViewBuilder
    private var workClause: some View {
        if draft.intervalRows.count > 1 {
            Text("After each work interval,")
        } else {
            HStack(spacing: SettingsTokens.stripItemSpacing) {
                Text("After every")
                integer("Work duration", value: $draft.intervalRows[0].minutes, range: ScheduleDraft.intervalRange, step: 5)
                Text("min of work,")
            }
        }
    }

    private var breakClause: some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            Text("break for")
            minutes("Short break duration", value: $draft.rhythmBreakMinutes)
            Text("min.")
        }
    }

    private var longCountClause: some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            Text("After")
            integer("Short breaks before a longer break", value: $draft.shortBreakCount, range: ScheduleDraft.shortBreakCountRange)
            Text("short breaks,")
        }
    }

    private var longDurationClause: some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            Text("longer break for")
            minutes("Longer break duration", value: $draft.longBreakMinutes, range: ScheduleDraft.longBreakRange, step: 5)
            Text("min.")
        }
    }

    private func addInterval(_ title: LocalizedStringKey) -> some View {
        Button {
            guard draft.intervalRows.count < 6 else { return }
            draft.intervalRows.append(IntervalRow(minutes: 40))
        } label: {
            Label(title, systemImage: "plus")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private func interval(_ row: Binding<IntervalRow>) -> some View {
        let id = row.wrappedValue.id
        return HStack(spacing: SettingsTokens.blockSpacing) {
            integer("Work duration", value: row.minutes, range: ScheduleDraft.intervalRange, step: 5)
            Text("min")
                .foregroundStyle(.secondary)
            TextField("Name (optional)", text: row.label)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Interval name")
            Button {
                guard draft.intervalRows.count > 1 else { return }
                draft.intervalRows.removeAll { $0.id == id }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove Interval")
        }
    }

    private func integer(
        _ label: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1
    ) -> some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: SettingsTokens.numberFieldWidth)
                .accessibilityLabel(label)
                .onChange(of: value.wrappedValue) { newValue in
                    value.wrappedValue = ScheduleDraft.clamped(newValue, to: range)
                }
            Stepper(label, value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.mini)
        }
        .fixedSize()
    }

    private func minutes(
        _ label: LocalizedStringKey, value: Binding<Double>,
        range: ClosedRange<Double> = ScheduleDraft.breakRange, step: Double = 1
    ) -> some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: SettingsTokens.numberFieldWidth)
                .accessibilityLabel(label)
                .onChange(of: value.wrappedValue) { newValue in
                    value.wrappedValue = ScheduleDraft.clamped(newValue, to: range)
                }
            Stepper(label, value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.mini)
        }
        .fixedSize()
    }
}

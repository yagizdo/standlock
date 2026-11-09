import SwiftUI
import StandLockCore

/// Shared columns keep every time window aligned with the first row's Hours label.
struct ScheduleHoursEditor: View {
    @Binding var draft: ScheduleDraft
    @Environment(\.settingsRowTone) private var tone

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: SettingsTokens.rowSpacing, verticalSpacing: SettingsTokens.blockSpacing) {
            ForEach($draft.windows) { $window in
                let first = window.id == draft.windows.first?.id
                if !first {
                    GridRow { Divider().gridCellColumns(3) }
                }
                GridRow {
                    SettingsIconChip(symbol: "clock", tone: tone, size: SettingsTokens.rowChipSize)
                        .opacity(first ? 1 : 0)
                    Text("Hours")
                        .opacity(first ? 1 : 0)
                        .accessibilityHidden(!first)
                    controls($window, first: first)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    private func controls(_ window: Binding<TimeWindow>, first: Bool) -> some View {
        let id = window.wrappedValue.id
        return HStack(spacing: SettingsTokens.blockSpacing) {
            time("Start hour", "Start minute", hour: window.startHour, minute: window.startMinute)
            Text("to")
                .foregroundStyle(.secondary)
                .fixedSize()
            time("End hour", "End minute", hour: window.endHour, minute: window.endMinute)
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
            Button {
                draft.windows.append(TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .opacity(first ? 1 : 0)
            .disabled(!first)
            .accessibilityHidden(!first)
            .accessibilityLabel("Add Time Window")
        }
        .fixedSize()
    }

    private func time(
        _ hourLabel: LocalizedStringKey, _ minuteLabel: LocalizedStringKey,
        hour: Binding<Int>, minute: Binding<Int>
    ) -> some View {
        HStack(spacing: SettingsTokens.stripItemSpacing) {
            Picker(hourLabel, selection: hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: SettingsTokens.timePickerWidth)
            Text(":")
                .foregroundStyle(.secondary)
                .fixedSize()
            Picker(minuteLabel, selection: minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: SettingsTokens.timePickerWidth)
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .monospacedDigit()
        .fixedSize()
    }
}

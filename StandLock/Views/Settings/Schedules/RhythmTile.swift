import SwiftUI
import StandLockCore

/// One number of a schedule's rhythm, large enough to read at a glance. A plain field, so typing
/// is still how a break gets shorter than a minute: 0.5 is thirty seconds, the floor 0.1 is six.
struct RhythmTile: View {
    let title: LocalizedStringKey
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @Environment(\.settingsRowTone) private var tone

    var body: some View {
        SettingsSection {
            VStack(alignment: .leading, spacing: SettingsTokens.listItemSpacing) {
                HStack(spacing: SettingsTokens.tileHeaderSpacing) {
                    SettingsIconChip(symbol: symbol, tone: tone)
                    Text(title)
                        .font(SettingsTokens.tileTitleFont)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: SettingsTokens.stripItemSpacing) {
                    TextField("", value: $value, format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.plain)
                        .font(SettingsTokens.tileNumberFont)
                        .monospacedDigit()
                        .fixedSize()
                        .accessibilityLabel(title)
                        .onChange(of: value) { newValue in
                            value = ScheduleDraft.clamped(newValue, to: range)
                        }
                    unit
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    // ponytail: step stays whole, so 0.5 steps to 1.5; typing is how you reach a fraction.
                    Stepper(title, value: $value, in: range, step: step)
                        .labelsHidden()
                }
            }
            .padding(SettingsTokens.previewInsets)
        }
    }

    /// Clamped first: the body can run on a typed value before `onChange` has held it in range.
    @ViewBuilder
    private var unit: some View {
        let minutes = ScheduleDraft.clamped(value, to: range)
        if minutes < 1 {
            Text("min, \(Int((minutes * 60).rounded())) sec")
        } else {
            Text("min")
        }
    }
}

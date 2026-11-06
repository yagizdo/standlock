import SwiftUI
import StandLockCore

/// Seven toggles, Monday first. Short names on screen, full names for VoiceOver.
struct DayButtons: View {
    private static let order: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    @Binding var days: Set<Weekday>

    @Environment(\.locale) private var locale

    var body: some View {
        let symbols = WeekdaySymbols(locale: locale)

        HStack(spacing: SettingsTokens.dayButtonSpacing) {
            ForEach(Self.order, id: \.self) { day in
                let isSelected = days.contains(day)
                Button {
                    if isSelected { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(symbols.short(for: day))
                        .font(SettingsTokens.dayButtonFont)
                        .frame(maxWidth: .infinity)
                        .padding(SettingsTokens.dayButtonInsets)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsTokens.chipRadius)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        )
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbols.full(for: day))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

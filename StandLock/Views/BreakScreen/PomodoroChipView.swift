import SwiftUI
import StandLockCore

/// Marks a Pomodoro break beside `LevelPill`: the same metrics, outline only, a `timer` glyph
/// in place of the dot.
struct PomodoroChipView: View {
    let chip: PomodoroChip
    let palette: BreakPalette
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .semibold))
            Text(text.uppercased(with: locale))
                .font(BreakTypography.label(size: 11, weight: .semibold))
                .tracking(3.08)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .overlay(
            Capsule()
                .strokeBorder(palette.accent.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(spokenLabel)
    }

    private var text: String {
        let detail = chip.isLong ? languageStore.string("Long break") : "\(chip.round)/\(chip.rounds)"
        return languageStore.string("Pomodoro") + " · " + detail
    }

    private var spokenLabel: String {
        chip.isLong
            ? languageStore.string("Pomodoro, long break")
            : languageStore.string("Pomodoro, round \(chip.round) of \(chip.rounds)")
    }
}

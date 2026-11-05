import SwiftUI
import StandLockCore

struct ScheduleSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let schedule: Schedule

    var body: some View {
        Label {
            HStack {
                Text(verbatim: schedule.name)
                    .lineLimit(1)
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)
                Spacer(minLength: 0)
                if schedule.isEnabled {
                    dot(Color(nsColor: .systemGreen))
                }
            }
        } icon: {
            dot(levelColor)
                .frame(width: 20, height: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: schedule.name))
        .accessibilityValue(Text(schedule.isEnabled ? "Enabled" : "Disabled"))
        .accessibilityHint(Text(LocalizedStringKey(schedule.disciplineLevel.displayName)))
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: SettingsTokens.statusDotSize, height: SettingsTokens.statusDotSize)
    }

    private var levelColor: Color {
        guard schedule.isEnabled else { return Color(nsColor: .systemGray) }
        // `themeStore.current` is not published, so it would miss a change of appearance.
        let theme = colorScheme == .dark ? AppTheme.dark : AppTheme.light
        return theme.palette(for: schedule.disciplineLevel).accent
    }
}

import SwiftUI
import StandLockCore

struct ScheduleSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let schedule: Schedule
    let isSelected: Bool

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
            // A fixed hue does not read on the selection fill.
            dot(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(levelColor))
                .frame(width: 20, height: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: schedule.name))
        .accessibilityValue(
            Text(schedule.isEnabled ? "Enabled" : "Disabled")
                + Text(verbatim: ", ")
                + Text(LocalizedStringKey(schedule.disciplineLevel.displayName))
        )
    }

    private func dot(_ style: some ShapeStyle) -> some View {
        Circle()
            .fill(style)
            .frame(width: SettingsTokens.statusDotSize, height: SettingsTokens.statusDotSize)
    }

    private var levelColor: Color {
        guard schedule.isEnabled else { return Color(nsColor: .systemGray) }
        // `themeStore.current` is not published, so it would miss a change of appearance.
        let theme = colorScheme == .dark ? AppTheme.dark : AppTheme.light
        return theme.palette(for: schedule.disciplineLevel).accent
    }
}

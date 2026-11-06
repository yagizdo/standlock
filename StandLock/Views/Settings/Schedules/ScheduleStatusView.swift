import SwiftUI
import StandLockCore

/// What the stored schedule does now, as opposed to the draft below it. A leaf, so the checker's
/// publishes stop here.
struct ScheduleStatusView: View {
    let schedule: Schedule
    @EnvironmentObject private var checker: PermissionChecker
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.listItemSpacing) {
            HStack(spacing: 8) {
                Text(daysSummary)
                Text("•")
                Text(windowSummary)
                Text("•")
                Text(intervalSummary)
                Spacer(minLength: 0)
                levelBadge
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // The stored level stays Strict and the badge keeps saying so; what changes is
            // how the break is enforced. Without this row the settings window claims Strict
            // while the break behaves as Firm, with nothing on screen explaining the gap.
            if checker.strictIsInactive(for: schedule) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Strict inactive, running as Firm")
                    Button("Grant") {
                        checker.requestStrictPermission()
                    }
                    .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .help(LocalizedStringKey(checker.strictModeBlockedReason ?? ""))
            }
        }
    }

    private var daysSummary: String {
        let symbols = WeekdaySymbols(locale: locale)
        switch schedule.days {
        case .everyDay: return languageStore.string("Every day")
        case .weekdays: return "\(symbols.short(for: .monday))-\(symbols.short(for: .friday))"
        case .weekends: return "\(symbols.short(for: .saturday))-\(symbols.short(for: .sunday))"
        case .custom(let days):
            return days.sorted().map(symbols.short(for:)).joined(separator: ", ")
        }
    }

    private var windowSummary: String {
        guard let w = schedule.windows.first else { return languageStore.string("All day") }
        return String(format: "%02d:%02d-%02d:%02d", w.startHour, w.startMinute, w.endHour, w.endMinute)
    }

    private var intervalSummary: String {
        // One key covers both branches: the minutes are built first, then interpolated.
        let minutes: String
        if let cycle = schedule.intervalCycle, cycle.count >= 2 {
            minutes = cycle.map { String(Int($0.duration / 60)) }.joined(separator: "/")
        } else {
            minutes = String(Int(schedule.breakInterval / 60))
        }
        return languageStore.string("every \(minutes)m")
    }

    private var levelBadge: some View {
        Text(languageStore.string(key: schedule.disciplineLevel.displayName)
            + (schedule.progressiveEnforcement ? "+" : ""))
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(levelColor.opacity(0.15), in: Capsule())
            .foregroundStyle(levelColor)
    }

    private var levelColor: Color {
        switch schedule.disciplineLevel {
        case .gentle: .green
        case .firm: .orange
        case .strict: .red
        }
    }
}

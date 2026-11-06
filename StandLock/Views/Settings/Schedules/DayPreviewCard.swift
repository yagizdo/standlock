import SwiftUI
import Scheduling
import StandLockCore

/// The day the form's values add up to. Equatable on the draft, because `AppCoordinator` publishes
/// every second in the last minute before a break and the walk should not rerun for that.
struct DayPreviewCard: View, Equatable {
    /// Every time is listed: cutting them at ten breaks read worse than showing them. This limit
    /// is for a one-minute interval, which would fill the window.
    private static let listLimit = 48

    let draft: ScheduleDraft
    let schedule: Schedule?

    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.locale) private var locale
    @Environment(\.settingsRowTone) private var tone

    nonisolated static func == (lhs: DayPreviewCard, rhs: DayPreviewCard) -> Bool {
        lhs.draft == rhs.draft
    }

    var body: some View {
        let built = draft.build(existing: schedule)
        let preview = DayPreview.make(for: built, from: Date())

        SettingsSection("Your day") {
            VStack(alignment: .leading, spacing: SettingsTokens.cardSpacing) {
                if draft.days.isEmpty {
                    stateText("Pick at least one day")
                } else if preview.items.isEmpty {
                    stateText("No breaks in these hours")
                } else {
                    header(preview, built)
                    ForEach(groups(of: preview), id: \.symbol) { group in
                        groupRow(group)
                    }
                    if preview.items.count > Self.listLimit {
                        Text("and \(preview.items.count - Self.listLimit) more")
                            .font(SettingsTokens.descriptionFont)
                            .foregroundStyle(.secondary)
                    }
                    SettingsDescription("Times shift if you skip or postpone a break.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SettingsTokens.previewInsets)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary(preview, built))
            .accessibilityValue(preview.items.prefix(Self.listLimit).map(clock).joined(separator: ", "))
        }
    }

    // MARK: - Pieces

    /// A state, not help: Show help must leave it visible.
    private func stateText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .fontWeight(.medium)
    }

    private func header(_ preview: DayPreview, _ built: Schedule) -> some View {
        HStack(spacing: SettingsTokens.cardSpacing) {
            SettingsIconChip(symbol: "cup.and.saucer", tone: tone, size: SettingsTokens.rowChipSize)
            VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
                Text(sentence(preview))
                    .fontWeight(.medium)
                Text(whenLine(built))
                    .font(SettingsTokens.descriptionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct TimeGroup {
        let title: LocalizedStringKey
        let symbol: String
        let items: ArraySlice<DayPreview.Item>
    }

    /// Empty groups drop out, and the list limit is spent from the morning on.
    private func groups(of preview: DayPreview) -> [TimeGroup] {
        var remaining = Self.listLimit
        func take(_ items: [DayPreview.Item]) -> ArraySlice<DayPreview.Item> {
            let taken = items.prefix(remaining)
            remaining -= taken.count
            return taken
        }
        return [
            TimeGroup(title: "Morning", symbol: "sunrise", items: take(preview.morning)),
            TimeGroup(title: "Afternoon", symbol: "sun.max", items: take(preview.afternoon)),
            TimeGroup(title: "Evening", symbol: "moon", items: take(preview.evening)),
        ].filter { !$0.items.isEmpty }
    }

    private func groupRow(_ group: TimeGroup) -> some View {
        HStack(alignment: .top, spacing: SettingsTokens.cardSpacing) {
            HStack(spacing: SettingsTokens.listItemSpacing) {
                Image(systemName: group.symbol)
                    .frame(width: SettingsTokens.statusMarkWidth)
                Text(group.title)
            }
            .foregroundStyle(.secondary)
            .frame(width: SettingsTokens.timeGroupLabelWidth, alignment: .leading)
            .padding(.top, SettingsTokens.timeChipInset)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: SettingsTokens.timeChipMinWidth), spacing: SettingsTokens.listItemSpacing)],
                alignment: .leading,
                spacing: SettingsTokens.listItemSpacing
            ) {
                ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                    Text(clock(item))
                        .font(SettingsTokens.timeChipFont)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SettingsTokens.timeChipInset)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: SettingsTokens.chipRadius))
                }
            }
        }
    }

    // MARK: - Text

    /// Not `DateFormatter`: `LanguageStore.locale` can give an English reader 12-hour text, and
    /// the time pickers above always read 24-hour.
    private func clock(_ item: DayPreview.Item) -> String {
        clock(hour: item.hour, minute: item.minute)
    }

    private func clock(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func sentence(_ preview: DayPreview) -> String {
        let count = preview.items.count
        let lengths: String
        if let shortest = preview.shortestBreak, let longest = preview.longestBreak, shortest != longest {
            if shortest >= 60 {
                let from = minutes(shortest), to = minutes(longest)
                lengths = languageStore.string("\(from) to \(to) min")
            } else {
                let from = length(shortest), to = length(longest)
                lengths = languageStore.string("\(from) to \(to)")
            }
        } else {
            let each = length(preview.shortestBreak ?? 0)
            lengths = languageStore.string("\(each) each")
        }
        return languageStore.string("\(count) breaks a day, \(lengths)")
    }

    /// Below a minute a break reads in seconds, since that is how it was typed.
    private func length(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return languageStore.string("\(Int(seconds)) sec")
        }
        let text = minutes(seconds)
        return languageStore.string("\(text) min")
    }

    private func minutes(_ seconds: TimeInterval) -> String {
        (seconds / 60).formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    private func whenLine(_ built: Schedule) -> String {
        let days = daysText(built.days)
        let hours: String
        if built.windows.count == 1, let window = built.windows.first {
            let from = clock(hour: window.startHour, minute: window.startMinute)
            let to = clock(hour: window.endHour, minute: window.endMinute)
            hours = languageStore.string("between \(from) and \(to)")
        } else {
            hours = languageStore.string("in \(built.windows.count) time windows")
        }
        return languageStore.string("\(days), \(hours)")
    }

    private func daysText(_ days: DaySelection) -> String {
        let symbols = WeekdaySymbols(locale: locale)
        switch days {
        case .everyDay:
            return languageStore.string("Every day")
        case .weekdays:
            let from = symbols.full(for: .monday), to = symbols.full(for: .friday)
            return languageStore.string("\(from) to \(to)")
        case .weekends:
            let from = symbols.full(for: .saturday), to = symbols.full(for: .sunday)
            return languageStore.string("\(from) to \(to)")
        case .custom(let selected):
            return DayButtons.order.filter(selected.contains).map(symbols.short(for:)).joined(separator: ", ")
        }
    }

    private func accessibilitySummary(_ preview: DayPreview, _ built: Schedule) -> String {
        if draft.days.isEmpty { return languageStore.string("Pick at least one day") }
        if preview.items.isEmpty { return languageStore.string("No breaks in these hours") }
        return sentence(preview) + ". " + whenLine(built)
    }
}

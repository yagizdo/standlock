import SwiftUI
import StandLockCore

struct ScheduleFormView: View {
    @Binding var draft: ScheduleDraft
    /// The stored schedule, nil for a new one.
    let schedule: Schedule?

    var body: some View {
        nameSection
        if schedule == nil {
            TemplateRow(draft: $draft)
        }
        whenSection
        rhythmSection
        DayPreviewCard(draft: draft, schedule: schedule)
            .equatable()
        disciplineSection
    }

    // MARK: - Sections

    private var nameSection: some View {
        SettingsSection {
            SettingsRow("Name", symbol: "textformat", expandsTitle: false) {
                TextField("e.g. Work Hours", text: $draft.name)
                    .labelsHidden()
                    .accessibilityLabel("Name")
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var whenSection: some View {
        SettingsSection("When") {
            DayButtons(days: $draft.days)
                .padding(SettingsTokens.rowInsets)
            Divider()
            ScheduleHoursEditor(draft: $draft)
        }
    }

    private var rhythmSection: some View {
        ScheduleRhythmSection(draft: $draft)
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

}

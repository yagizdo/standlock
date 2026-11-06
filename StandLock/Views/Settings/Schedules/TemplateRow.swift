import SwiftUI
import StandLockCore

/// One click fills the rhythm of a new schedule; the Your day card shows what that means.
struct TemplateRow: View {
    @Binding var draft: ScheduleDraft

    var body: some View {
        HStack(spacing: SettingsTokens.blockSpacing) {
            Text("Start from")
                .font(SettingsTokens.descriptionFont)
                .foregroundStyle(.secondary)
            ForEach(ScheduleTemplate.allCases, id: \.self) { template in
                Button {
                    template.apply(to: &draft)
                } label: {
                    Text(verbatim: template.title)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, SettingsTokens.sectionTitleInset)
    }
}

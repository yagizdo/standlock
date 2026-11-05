import SwiftUI
import StandLockCore

/// Finds the stored schedule. A nil `id` is a new one.
struct ScheduleDetailView: View {
    let id: UUID?
    let navigation: SettingsNavigation
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        let schedule = coordinator.schedules.first { $0.id == id }
        // A deleted schedule is on screen for the moment before the sidebar moves the selection.
        if schedule != nil || id == nil {
            SchedulePage(schedule: schedule, navigation: navigation)
        }
    }
}

/// Holds the draft. Enforcement restarts on every `updateSchedule`, so edits stay here until Save.
private struct SchedulePage: View {
    /// The latest stored value. The draft loads from it once and does not follow it.
    let schedule: Schedule?
    @ObservedObject var navigation: SettingsNavigation

    @EnvironmentObject private var coordinator: AppCoordinator
    // Captured here, not read inside the sheet: a presentation starts a fresh root, so
    // the chosen locale has to be re-applied on the other side of it.
    @EnvironmentObject private var languageStore: LanguageStore
    @State private var draft: ScheduleDraft
    @State private var baseline: ScheduleDraft
    @State private var showDeleteConfirmation = false

    init(schedule: Schedule?, navigation: SettingsNavigation) {
        self.schedule = schedule
        self.navigation = navigation
        let loaded = ScheduleDraft(schedule: schedule)
        _draft = State(initialValue: loaded)
        _baseline = State(initialValue: loaded)
    }

    private var isDirty: Bool { draft.hasChanges(from: baseline) }

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageLayout(title: title, accessory: { enableToggle }) {
                if let schedule {
                    ScheduleStatusView(schedule: schedule)
                } else if coordinator.schedules.isEmpty {
                    emptyNote
                }
                ScheduleFormView(draft: $draft)
                    // Not `.keyboardShortcut`: in a pane that reaches the whole window, sidebar
                    // and search included. These two need focus inside the form.
                    .onSubmit { saveAndStay() }
                    .onExitCommand { cancel() }
            }
            Divider()
            footer
        }
        .onAppear { navigation.unsavedEdits = { draft.hasChanges(from: baseline) } }
        .alert(
            "Unsaved Changes",
            isPresented: promptIsPresented,
            presenting: navigation.pendingLeave
        ) { leave in
            // Left out, not disabled: an alert button cannot explain why it is dimmed.
            if draft.canSave {
                Button("Save") {
                    saveAndStay()
                    navigation.finish(leave)
                }
            }
            Button("Discard", role: .destructive) {
                draft = baseline
                navigation.finish(leave)
            }
            Button("Cancel", role: .cancel) { navigation.cancelPending() }
        } message: { _ in
            Text(draft.canSave
                ? "Your changes to this schedule have not been saved."
                : "Name this schedule to save it, or discard your changes.")
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            LocalizedRoot(store: languageStore) {
                DeleteConfirmationView(
                    scheduleName: schedule?.name ?? "",
                    onCancel: { showDeleteConfirmation = false },
                    onDelete: {
                        showDeleteConfirmation = false
                        if let schedule { coordinator.deleteSchedule(schedule) }
                    }
                )
            }
        }
    }

    private var title: Text {
        schedule.map { Text(verbatim: $0.name) } ?? Text("New Schedule")
    }

    @ViewBuilder
    private var enableToggle: some View {
        if let schedule {
            Toggle("Enabled", isOn: Binding(
                get: { schedule.isEnabled },
                set: { enabled in
                    var updated = schedule
                    updated.isEnabled = enabled
                    coordinator.updateSchedule(updated)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(.green)
            .controlSize(.small)
        }
    }

    private var emptyNote: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
            Text("No Schedules")
                .font(.headline)
            Text("Add a schedule to start taking breaks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if schedule != nil {
                Button("Delete", role: .destructive) { showDeleteConfirmation = true }
                    .foregroundStyle(.red)
            }
            Spacer()
            Button("Cancel") { cancel() }
                .disabled(!isDirty && (schedule != nil || coordinator.schedules.isEmpty))
            Button(schedule == nil ? "Add Schedule" : "Save") { saveAndStay() }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canSubmit(from: baseline))
        }
        .padding(SettingsTokens.footerInsets)
    }

    private var promptIsPresented: Binding<Bool> {
        let navigation = navigation
        return Binding(
            get: { navigation.pendingLeave != nil },
            set: { if !$0 { navigation.cancelPending() } }
        )
    }

    /// Return lands here too, so nothing the Save button would refuse goes through: a nameless
    /// schedule, or a restart of enforcement with nothing changed.
    private func saveAndStay() {
        guard draft.canSubmit(from: baseline) else { return }
        let saved = draft.build(existing: schedule)
        // Reloaded because the pane stays open: the form must show what was stored, such as
        // Monday for an empty custom selection.
        draft = ScheduleDraft(schedule: saved)
        baseline = draft
        if schedule == nil {
            coordinator.addSchedule(saved)
            navigation.leave(to: .schedule(saved.id))
        } else {
            coordinator.updateSchedule(saved)
        }
    }

    private func cancel() {
        draft = baseline
        if schedule == nil {
            navigation.leave(to: .firstSchedule(in: coordinator.schedules.map(\.id)))
        }
    }
}

import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false

    var body: some View {
        Form {
            Section("Video & Audio") {
                detectionRow(
                    title: "Camera Detection",
                    description: "Defer breaks when camera is active (video calls)",
                    systemImage: "camera",
                    behavior: $coordinator.preferences.cameraDetection
                )

                detectionRow(
                    title: "Microphone Detection",
                    description: "Defer breaks when microphone is active (audio calls)",
                    systemImage: "mic",
                    behavior: $coordinator.preferences.microphoneDetection
                )
            }

            Section("Calendar") {
                Toggle(isOn: permissionChecker.gatedToggle(
                    for: $coordinator.preferences.calendarDetectionEnabled,
                    available: permissionChecker.calendarIntegrationAvailable,
                    onDenied: { showCalendarPermissionAlert = true }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Integration")
                            Text("Defer breaks during calendar events")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }

                if permissionChecker.calendarIntegrationAvailable
                    && coordinator.preferences.calendarDetectionEnabled {
                    Stepper(
                        "Look-ahead: \(coordinator.preferences.calendarLookAheadMinutes) min",
                        value: $coordinator.preferences.calendarLookAheadMinutes,
                        in: 1...15
                    )
                    .padding(.leading, 24)

                    Picker("Calendars", selection: $coordinator.preferences.calendarSelectionMode) {
                        Text("All calendars").tag(CalendarSelectionMode.all)
                        Text("Specific calendars").tag(CalendarSelectionMode.selected)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.leading, 24)

                    if coordinator.preferences.calendarSelectionMode == .selected {
                        calendarSelection
                    }
                }

                Toggle(isOn: $coordinator.preferences.screenSharingDetectionEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Sharing")
                            Text("Defer breaks during screen sharing or recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.inset.filled.and.person.filled")
                    }
                }

                if coordinator.preferences.screenSharingDetectionEnabled {
                    Picker("After sharing ends", selection: $coordinator.preferences.screenSharingPostDeferral) {
                        Text("Start break").tag(PostDeferralBehavior.triggerBreak)
                        Text("Skip break").tag(PostDeferralBehavior.skipBreak)
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 24)
                }
            }

            Section("Media & Idle") {
                Toggle(isOn: $coordinator.preferences.pauseMediaDuringBreak) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause Media")
                            Text("Pause audio playback when a break starts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speaker.slash")
                    }
                }

                Toggle(isOn: $coordinator.preferences.idleDetectionEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Idle as Break")
                            Text("Count inactivity as a break taken")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "zzz")
                    }
                }
            }

        }
        .formStyle(.grouped)
        .onChange(of: coordinator.preferences) { _ in
            coordinator.savePreferences()
        }
        .alert("Calendar Permission Required", isPresented: $showCalendarPermissionAlert) {
            Button("Open System Settings") {
                permissionChecker.openSystemSettings(for: .calendar)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Calendar Integration requires calendar access. Grant it in System Settings to enable this feature.")
        }
    }

    private func detectionRow(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        systemImage: String,
        behavior: Binding<DetectionBehavior>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }

            Picker("Behavior", selection: behavior) {
                Text("Defer break").tag(DetectionBehavior.deferBreak)
                Text("Reduce to Gentle").tag(DetectionBehavior.reduceToGentle)
                Text("Ignore").tag(DetectionBehavior.ignore)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.leading, 24)
        }
    }

    @ViewBuilder
    private var calendarSelection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Only checked calendars defer breaks")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.availableCalendars.isEmpty {
                Text("No calendars found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coordinator.availableCalendars) { calendar in
                    Toggle(isOn: calendarBinding(for: calendar)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: calendar.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !calendar.source.isEmpty {
                                Text(verbatim: calendar.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.leading, 24)
        .task {
            coordinator.refreshAvailableCalendars()
            // Pre-check every calendar so switching to a specific selection changes nothing
            // until something is unticked. An existing choice is left alone when reopened.
            if coordinator.preferences.selectedCalendarIdentifiers.isEmpty {
                coordinator.preferences.selectedCalendarIdentifiers =
                    coordinator.availableCalendars.map(\.id)
            }
        }
    }

    private func calendarBinding(for calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { coordinator.preferences.selectedCalendarIdentifiers.contains(calendar.id) },
            set: { selected in
                var identifiers = coordinator.preferences.selectedCalendarIdentifiers
                if selected {
                    if !identifiers.contains(calendar.id) { identifiers.append(calendar.id) }
                } else {
                    identifiers.removeAll { $0 == calendar.id }
                }
                coordinator.preferences.selectedCalendarIdentifiers = identifiers
            }
        )
    }
}

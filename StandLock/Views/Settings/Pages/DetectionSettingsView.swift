import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false

    var body: some View {
        SettingsPageLayout("Detection") {
            SettingsSection("Calls") {
                behaviorRow(
                    "Camera Detection",
                    symbol: "video",
                    description: "Defer breaks when camera is active (video calls)",
                    behavior: $coordinator.preferences.cameraDetection
                )

                SettingsRowDivider()

                behaviorRow(
                    "Microphone Detection",
                    symbol: "mic",
                    description: "Defer breaks when microphone is active (audio calls)",
                    behavior: $coordinator.preferences.microphoneDetection
                )

                SettingsRowDivider()

                minutesRow(
                    "Return after call",
                    description: "A postponed break comes back this long after the microphone and camera are free",
                    value: postponeReturnMinutes,
                    in: 1...10
                )
            }

            SettingsSection("Calendar") {
                SettingsToggleRow(
                    "Calendar Integration",
                    symbol: "calendar",
                    description: "Defer breaks during calendar events",
                    isOn: permissionChecker.gatedToggle(
                        for: $coordinator.preferences.calendarDetectionEnabled,
                        available: permissionChecker.calendarIntegrationAvailable,
                        onDenied: { showCalendarPermissionAlert = true }
                    )
                )

                if permissionChecker.calendarIntegrationAvailable
                    && coordinator.preferences.calendarDetectionEnabled {
                    SettingsRowDivider()

                    minutesRow(
                        "Look-ahead",
                        value: $coordinator.preferences.calendarLookAheadMinutes,
                        in: 1...15
                    )

                    SettingsRowDivider()

                    SettingsRow("Calendars", symbol: "arrow.turn.down.right") {
                        Picker("Calendars", selection: $coordinator.preferences.calendarSelectionMode) {
                            Text("All calendars").tag(CalendarSelectionMode.all)
                            Text("Specific calendars").tag(CalendarSelectionMode.selected)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    if coordinator.preferences.calendarSelectionMode == .selected {
                        Divider()
                        calendarSelection
                    }
                }
            }

            SettingsSection("Screen sharing") {
                SettingsToggleRow(
                    "Screen Sharing",
                    symbol: "rectangle.on.rectangle",
                    description: "Defer breaks during screen sharing or recording",
                    isOn: $coordinator.preferences.screenSharingDetectionEnabled
                )

                if coordinator.preferences.screenSharingDetectionEnabled {
                    SettingsRowDivider()

                    SettingsRow("After sharing ends", symbol: "arrow.turn.down.right") {
                        Picker("After sharing ends", selection: $coordinator.preferences.screenSharingPostDeferral) {
                            Text("Start break").tag(PostDeferralBehavior.triggerBreak)
                            Text("Skip break").tag(PostDeferralBehavior.skipBreak)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }

            SettingsSection("Idle") {
                SettingsToggleRow(
                    "Idle as Break",
                    symbol: "moon.zzz",
                    description: "Count inactivity as a break taken",
                    isOn: $coordinator.preferences.idleDetectionEnabled
                )
            }
        }
        .onChange(of: coordinator.preferences.calendarSelectionMode) { _ in
            // Pre-check every calendar when the choice flips to a specific selection, so it
            // starts as a no-op the user then narrows down. Leaving this in the list's task
            // would re-tick everything each time the page is reopened.
            guard coordinator.preferences.needsCalendarPreCheck else { return }
            coordinator.refreshAvailableCalendars()
            coordinator.preferences.selectedCalendarIdentifiers =
                coordinator.availableCalendars.map(\.id)
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

    private func behaviorRow(
        _ title: LocalizedStringKey,
        symbol: String,
        description: LocalizedStringKey,
        behavior: Binding<DetectionBehavior>
    ) -> some View {
        SettingsRow(title, symbol: symbol, description: description) {
            Picker(title, selection: behavior) {
                Text("Defer break").tag(DetectionBehavior.deferBreak)
                Text("Reduce to Gentle").tag(DetectionBehavior.reduceToGentle)
                Text("Ignore").tag(DetectionBehavior.ignore)
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    /// The value sits beside the stepper because Show help can hide the description.
    private func minutesRow(
        _ title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        value: Binding<Int>,
        in range: ClosedRange<Int>
    ) -> some View {
        SettingsRow(title, symbol: "arrow.turn.down.right", description: description) {
            HStack(spacing: SettingsTokens.rowSpacing) {
                Text("\(value.wrappedValue) min")
                    .monospacedDigit()
                    .accessibilityHidden(true)
                Stepper(title, value: value, in: range)
                    .labelsHidden()
                    .accessibilityValue(Text("\(value.wrappedValue) min"))
            }
        }
    }

    private var calendarSelection: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.listItemSpacing) {
            SettingsDescription("Only checked calendars defer breaks")

            if coordinator.availableCalendars.isEmpty {
                // A state, not help text: Show help must leave it visible.
                Text("No calendars found")
                    .font(SettingsTokens.descriptionFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coordinator.availableCalendars) { calendar in
                    Toggle(isOn: calendarBinding(for: calendar)) {
                        VStack(alignment: .leading, spacing: SettingsTokens.rowTextSpacing) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SettingsTokens.rowInsets)
        .task { coordinator.refreshAvailableCalendars() }
    }

    private var postponeReturnMinutes: Binding<Int> {
        Binding(
            get: { Int(coordinator.preferences.postponeReturnDelay / 60) },
            set: { coordinator.preferences.postponeReturnDelay = TimeInterval($0 * 60) }
        )
    }

    private func calendarBinding(for calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { coordinator.preferences.selectedCalendarIdentifiers.contains(calendar.id) },
            set: { coordinator.preferences.setCalendar(calendar.id, isSelected: $0) }
        )
    }
}

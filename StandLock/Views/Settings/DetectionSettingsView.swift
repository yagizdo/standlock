import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false
    @State private var showAccessibilityAlert = false
    @State private var showInputMonitoringAlert = false

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

            Section("Calendar & Focus") {
                Toggle(isOn: permissionChecker.gatedToggle(
                    for: $coordinator.preferences.calendarDetectionEnabled,
                    requires: .calendar,
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

                detectionRow(
                    title: "Focus Mode",
                    description: "Defer breaks when Focus mode is active",
                    systemImage: "moon",
                    behavior: $coordinator.preferences.focusModeDetection
                )
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

                if coordinator.preferences.pauseMediaDuringBreak {
                    Toggle(isOn: $coordinator.preferences.resumeMediaAfterBreak) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resume After Break")
                                Text("Automatically resume playback when the break ends")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "speaker.wave.2")
                        }
                    }
                    .padding(.leading, 24)
                }

                Toggle(isOn: permissionChecker.gatedToggle(
                    for: $coordinator.preferences.idleDetectionEnabled,
                    requires: .inputMonitoring,
                    onDenied: { showInputMonitoringAlert = true }
                )) {
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

            Section {
                Toggle(isOn: Binding(
                    get: { coordinator.preferences.escalationLevel != .off },
                    set: { coordinator.preferences.escalationLevel = $0 ? .gentle : .off }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Progressive Friction")
                            Text("Makes each skipped break harder to dismiss")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                    }
                }

                if coordinator.preferences.escalationLevel != .off {
                    Picker("Level", selection: $coordinator.preferences.escalationLevel) {
                        Text("Gentle").tag(EscalationLevel.gentle)
                        Text("Firm").tag(EscalationLevel.firm)
                        Text("Strict").tag(EscalationLevel.strict)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.leading, 24)

                    escalationPathView
                        .padding(.leading, 24)
                }
            } header: {
                Text("Behavior")
            } footer: {
                if coordinator.preferences.escalationLevel != .off {
                    Text("Taking a break resets the progression.")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: coordinator.preferences.escalationLevel) { newLevel in
            if newLevel == .strict && !permissionChecker.strictModeAvailable {
                coordinator.preferences.escalationLevel = .firm
                showAccessibilityAlert = true
            }
        }
        .onChange(of: coordinator.preferences) { _ in
            coordinator.savePreferences()
        }
        .alert("Calendar Permission Required", isPresented: $showCalendarPermissionAlert) {
            Button("Open System Settings") {
                for url in PermissionType.calendar.settingsURLs {
                    if NSWorkspace.shared.open(url) { break }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Calendar Integration requires calendar access. Grant it in System Settings to enable this feature.")
        }
        .alert("Input Monitoring Required", isPresented: $showInputMonitoringAlert) {
            Button("Open System Settings") {
                for url in PermissionType.inputMonitoring.settingsURLs {
                    if NSWorkspace.shared.open(url) { break }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This feature requires Input Monitoring permission. Grant it in System Settings to enable.")
        }
        .alert("Accessibility Permission Required", isPresented: $showAccessibilityAlert) {
            Button("Open System Settings") {
                for url in PermissionType.accessibility.settingsURLs {
                    if NSWorkspace.shared.open(url) { break }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Strict mode requires Accessibility permission to block input during breaks.")
        }
    }

    @ViewBuilder
    private var escalationPathView: some View {
        let selected = coordinator.preferences.escalationLevel
        VStack(alignment: .leading, spacing: 6) {
            Text("Each skip advances to the next stage:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                stagePill("Delay", active: selected >= .gentle)
                stageArrow(active: selected >= .firm)
                stagePill("Phrase", active: selected >= .firm)
                stageArrow(active: selected >= .strict)
                stagePill("Key hold", active: selected >= .strict)
            }
        }
    }

    private func stagePill(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(active ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(active ? Color.accentColor : Color.secondary.opacity(0.3))
    }

    private func stageArrow(active: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(active ? .secondary : Color.secondary.opacity(0.3))
    }

    private func detectionRow(
        title: String,
        description: String,
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
}

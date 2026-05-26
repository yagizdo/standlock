import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false
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

        }
        .formStyle(.grouped)
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

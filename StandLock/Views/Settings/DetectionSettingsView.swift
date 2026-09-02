import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false
    @State private var showAccessibilityAlert = false

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
                }

                Toggle(isOn: permissionChecker.gatedToggle(
                    for: $coordinator.preferences.screenSharingDetectionEnabled,
                    available: permissionChecker.accessibilityGranted,
                    onDenied: { showAccessibilityAlert = true }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Sharing")
                            Text("Defer breaks while an app captures your screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Sharing with the microphone live is deferred as a call instead.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.inset.filled.and.person.filled")
                    }
                }

                if permissionChecker.accessibilityGranted
                    && coordinator.preferences.screenSharingDetectionEnabled {
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
        .alert("Accessibility Permission Required", isPresented: $showAccessibilityAlert) {
            Button("Open System Settings") {
                permissionChecker.openSystemSettings(for: .accessibility)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Screen Sharing detection reads the macOS privacy indicator, which requires Accessibility access. Grant it in System Settings to enable this feature.")
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

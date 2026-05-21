import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
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
                Toggle(isOn: $coordinator.preferences.calendarDetectionEnabled) {
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

                if coordinator.preferences.calendarDetectionEnabled {
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

                detectionRow(
                    title: "Focus Mode",
                    description: "Defer breaks when Focus mode is active",
                    systemImage: "moon",
                    behavior: $coordinator.preferences.focusModeDetection
                )
            }

            Section("Media") {
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
            }

            Section("Idle Recognition") {
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

            Section {
                Toggle(isOn: $coordinator.preferences.gentleEscalationEnabled) {
                    Text("Gentle")
                }
                Toggle(isOn: $coordinator.preferences.firmEscalationEnabled) {
                    Text("Firm")
                }
                Toggle(isOn: $coordinator.preferences.strictEscalationEnabled) {
                    Text("Strict")
                }
            } header: {
                Text("Progressive Friction")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Each skipped break makes the next skip harder. Resets when you complete a break.")
                    if coordinator.preferences.firmEscalationEnabled {
                        Text("Firm escalation is active — daily skip limit is replaced by escalating friction.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: coordinator.preferences) { _, _ in
            coordinator.savePreferences()
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

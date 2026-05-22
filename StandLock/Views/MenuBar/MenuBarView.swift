import SwiftUI
import StandLockCore

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var updateObserver: UpdateObserver

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
                updateBanner
                statusSection
                statsBar
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            Divider()
                .padding(.vertical, 6)

            QuickActionsView()

            Divider()
                .padding(.vertical, 6)

            bottomActions
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("StandLock")
                .font(.headline)
            Spacer()
            if coordinator.isPaused {
                Text("Paused")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if coordinator.isBreakActive {
            Label("Break in progress", systemImage: "figure.stand")
                .font(.subheadline)
                .foregroundStyle(.green)
        } else if coordinator.isPaused, let until = coordinator.pausedUntil {
            Label {
                Text("Paused until \(until, style: .time)")
            } icon: {
                Image(systemName: "pause.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let reason = coordinator.deferralReason {
            VStack(alignment: .leading, spacing: 2) {
                Label("Break waiting", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(reason.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if let nextBreak = coordinator.nextBreakTime {
            Label {
                Text("Next break \(nextBreak, style: .relative)")
            } icon: {
                Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if coordinator.schedules.isEmpty {
            Label("No schedules configured", systemImage: "calendar.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("No active schedules", systemImage: "moon.zzz")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 16) {
            statItem(
                icon: "checkmark.circle",
                value: "\(coordinator.todayStats.breaksCompleted)",
                label: "Breaks"
            )
            statItem(
                icon: "flame",
                value: "\(coordinator.todayStats.currentStreak)",
                label: "Streak"
            )
            statItem(
                icon: "forward.end",
                value: "\(coordinator.todayStats.breaksSkipped)",
                label: "Skipped"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Update Banner

    @ViewBuilder
    private var updateBanner: some View {
        if updateObserver.updateAvailable {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(updateObserver.availableVersion.map { "v\($0) available" } ?? "Update available")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button("Update") {
                    (NSApp.delegate as? AppDelegate)?.updaterController.updater.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.25)))
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            if #available(macOS 14, *) {
                SettingsRowButton(tab: .general)
                SettingsRowButton(tab: .about)
            } else {
                Button {
                    coordinator.selectedSettingsTab = .general
                    openSettingsLegacy()
                } label: {
                    settingsLabel
                }
                .buttonStyle(MenuBarRowStyle())

                Button {
                    coordinator.selectedSettingsTab = .about
                    openSettingsLegacy()
                } label: {
                    aboutLabel
                }
                .buttonStyle(MenuBarRowStyle())
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                    Text("Quit StandLock")
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(MenuBarRowStyle())
        }
    }

    private func openSettingsLegacy() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private var settingsLabel: some View {
    HStack(spacing: 8) {
        Image(systemName: "gearshape")
            .frame(width: 18)
            .foregroundStyle(.secondary)
        Text("Settings...")
        Spacer()
        Text("\u{2318},")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

private var aboutLabel: some View {
    HStack(spacing: 8) {
        Image(systemName: "info.circle")
            .frame(width: 18)
            .foregroundStyle(.secondary)
        Text("About StandLock")
        Spacer()
    }
}

@available(macOS 14, *)
private struct SettingsRowButton: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var coordinator: AppCoordinator
    let tab: AppCoordinator.SettingsTab

    var body: some View {
        Button {
            coordinator.selectedSettingsTab = tab
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            if tab == .about {
                aboutLabel
            } else {
                settingsLabel
            }
        }
        .buttonStyle(MenuBarRowStyle())
    }
}

struct MenuBarRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .onHover { isHovered = $0 }
    }
}

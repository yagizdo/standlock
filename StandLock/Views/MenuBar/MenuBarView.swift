import SwiftUI
import StandLockCore

struct MenuBarView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            statusSection
            Divider()
            statsBar
            Divider()
            QuickActionsView()
            Divider()
            bottomActions
        }
        .padding(12)
        .frame(width: 280)
        .task {
            if !coordinator.hasCompletedOnboarding {
                openWindow(id: "onboarding")
            }
        }
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

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLink {
                Text("Settings...")
            }
            Button("Quit StandLock") {
                NSApp.terminate(nil)
            }
        }
    }
}

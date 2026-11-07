import SwiftUI
import StandLockCore

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var updateObserver: UpdateObserver
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                updateBanner
                MenuBarStatusView(
                    state: coordinator.nextBreakState,
                    progress: coordinator.breakProgress,
                    scene: coordinator.preferences.menuScene,
                    schedule: coordinator.schedules.first(where: \.isEnabled)
                )
                statsBar
            }
            .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 10)

            QuickActionsView()
        }
        .padding(12)
        .frame(width: 280)
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
                value: "\(coordinator.breakHistory.currentStreak())",
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

    private func statItem(icon: String, value: String, label: LocalizedStringKey) -> some View {
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
                    .fill(bannerTint)
                    .frame(width: 6, height: 6)
                bannerTitle
                    .font(.caption)
                    .foregroundStyle(bannerTint)
                    .lineLimit(1)
                Spacer()
                bannerAction
            }
            .padding(10)
            .background(bannerTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(bannerTint.opacity(0.25)))
        }
    }

    private var bannerTint: Color {
        updateObserver.homebrewUpgrade == .failed ? .orange : .green
    }

    @ViewBuilder
    private var bannerTitle: some View {
        switch updateObserver.homebrewUpgrade {
        case .idle:
            if let version = updateObserver.availableVersion {
                Text("v\(version) available")
            } else {
                Text("Update available")
            }
        case .running:
            Text("Updating with Homebrew…")
        case .waitingToRestart:
            Text("Waiting to restart")
        case .blocked:
            Text("Can't update right now")
        case .failed:
            Text("Update failed")
        }
    }

    /// The hidden button holds the banner's height: panel height stays steady across its states.
    @ViewBuilder
    private var bannerAction: some View {
        switch updateObserver.homebrewUpgrade {
        case .idle, .blocked:
            updateButton
        case .running:
            updateButton
                .hidden()
                .overlay(ProgressView().controlSize(.small))
        case .waitingToRestart:
            updateButton
                .hidden()
        case .failed:
            Button("Details") {
                coordinator.settingsNavigation.open(.about, using: openWindow)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var updateButton: some View {
        Button("Update") {
            if let homebrew = updateObserver.homebrew {
                homebrew.upgrade()
            } else {
                NSApp.activate(ignoringOtherApps: true)
                (NSApp.delegate as? AppDelegate)?.updaterController.updater.checkForUpdates()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

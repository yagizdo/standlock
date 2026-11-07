import SwiftUI
import Combine
import StandLockCore
@preconcurrency import Sparkle

@MainActor
final class UpdateObserver: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published var updateAvailable = false
    @Published var availableVersion: String?
    /// True only after a check reached the feed and found nothing newer that this Mac can run,
    /// apart from a version the user chose to skip: Sparkle reports that the same way.
    @Published var onLatestVersion = false
    /// When the last check ended. `lastUpdateCheckDate` already moves as a check starts, which
    /// would put a running check's time beside the previous check's result.
    @Published var finishedCheckDate: Date?
    @Published var homebrewUpgrade = HomebrewUpgradeState.idle
    /// Set on a copy Homebrew owns. Sparkle is not started there, so every check and install
    /// goes through this instead.
    var homebrew: HomebrewUpdater?

    nonisolated override init() {
        super.init()
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            self.updateAvailable = true
            self.availableVersion = version
            self.onLatestVersion = false
        }
    }

    /// Sparkle calls this form instead of `updaterDidNotFindUpdate(_:)`, not as well. A newer
    /// version this Mac cannot run lands here too, under its own reason.
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? OSStatus
        let onLatest = reason == SPUNoUpdateFoundReason.onLatestVersion.rawValue
            || reason == SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue
        Task { @MainActor in
            self.updateAvailable = false
            self.availableVersion = nil
            self.onLatestVersion = onLatest
        }
    }

    /// A failed or cancelled check moves `lastUpdateCheckDate` too, so anything but a no-update
    /// end drops the claim. The write also redraws the status row, with or without a change.
    nonisolated func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        let foundNothing = (error as NSError?)?.code == Int(SUError.noUpdateError.rawValue)
        let finished = updater.lastUpdateCheckDate
        Task { @MainActor in
            self.onLatestVersion = self.onLatestVersion && foundNothing
            self.finishedCheckDate = finished
        }
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    @State private var automaticallyChecksForUpdates: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    var body: some View {
        SettingsToggleRow("Automatic Updates", symbol: "arrow.down.circle", isOn: $automaticallyChecksForUpdates)
            .onChange(of: automaticallyChecksForUpdates) { newValue in
                updater.automaticallyChecksForUpdates = newValue
            }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

/// A state, not help: it stays outside `SettingsDescription`.
struct UpdateStatusRow: View {
    @EnvironmentObject private var updateObserver: UpdateObserver

    let updater: SPUUpdater

    var body: some View {
        let lastCheck = updateObserver.finishedCheckDate ?? updater.lastUpdateCheckDate
        let status = UpdateStatus(
            availableVersion: updateObserver.availableVersion,
            onLatestVersion: updateObserver.onLatestVersion,
            lastCheckDate: lastCheck
        )
        let mark = mark(for: status)

        HStack(spacing: 0) {
            Image(systemName: mark.symbol)
                .foregroundStyle(mark.color)
                .frame(width: SettingsTokens.statusMarkWidth)
                .padding(.leading, SettingsTokens.rowInsets.leading)
                .accessibilityHidden(true)

            SettingsRow(title(for: status), symbol: nil) {
                if let lastCheck {
                    Text(lastCheck, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                        .font(SettingsTokens.descriptionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func title(for status: UpdateStatus) -> LocalizedStringKey {
        switch status {
        case .available(let version): "v\(version) available"
        case .upToDate: "StandLock is up to date"
        case .checked: "Last checked"
        case .neverChecked: "Not checked yet"
        case .upgrading: "Updating with Homebrew…"
        case .upgradeWaiting: "Update ready, waiting to restart"
        case .upgradeBlocked: "Can't update right now"
        case .upgradeFailed: "Update failed"
        }
    }

    private func mark(for status: UpdateStatus) -> (symbol: String, color: Color) {
        switch status {
        case .available: ("arrow.down.circle.fill", .green)
        case .upToDate: ("checkmark.circle.fill", .green)
        case .checked, .neverChecked, .upgradeWaiting: ("clock", .secondary)
        case .upgrading: ("arrow.triangle.2.circlepath", .secondary)
        case .upgradeBlocked: ("pause.circle", .secondary)
        case .upgradeFailed: ("exclamationmark.triangle.fill", .orange)
        }
    }
}

import Foundation

/// Where a Homebrew upgrade started from the app has got to. Sparkle copies stay `idle`.
public enum HomebrewUpgradeState: Equatable, Sendable {
    case idle
    case running
    /// The new version is on disk, and a break or a Settings edit holds the relaunch back.
    case waitingToRestart
    case blocked
    case failed
}

/// What the About page may say about updates. A date alone proves a check was attempted, not
/// that this is the newest version, so `upToDate` needs a result from a finished check.
public enum UpdateStatus: Equatable, Sendable {
    case available(version: String)
    case upToDate
    case checked
    case neverChecked
    case upgrading
    case upgradeWaiting
    case upgradeBlocked
    case upgradeFailed

    public init(
        availableVersion: String?,
        onLatestVersion: Bool,
        lastCheckDate: Date?,
        homebrewUpgrade: HomebrewUpgradeState = .idle
    ) {
        switch homebrewUpgrade {
        case .running:
            self = .upgrading
            return
        case .waitingToRestart:
            self = .upgradeWaiting
            return
        case .blocked:
            self = .upgradeBlocked
            return
        case .failed:
            self = .upgradeFailed
            return
        case .idle:
            break
        }

        if let availableVersion {
            self = .available(version: availableVersion)
        } else if onLatestVersion {
            self = .upToDate
        } else if lastCheckDate != nil {
            self = .checked
        } else {
            self = .neverChecked
        }
    }
}

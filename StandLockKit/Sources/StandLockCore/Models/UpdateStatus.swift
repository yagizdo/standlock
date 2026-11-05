import Foundation

/// What the About page may say about updates. A date alone proves a check was attempted, not
/// that this is the newest version, so `upToDate` needs a result from a finished check.
public enum UpdateStatus: Equatable, Sendable {
    case available(version: String?)
    case upToDate
    case checked
    case neverChecked

    public init(updateAvailable: Bool, availableVersion: String?, onLatestVersion: Bool, lastCheckDate: Date?) {
        if updateAvailable {
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

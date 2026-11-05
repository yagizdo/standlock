import Foundation

public enum SettingsPage: Hashable, Sendable {
    case general, menuBar, breakScreen, discipline, detection, permissions, statistics, about
    case schedule(UUID), newSchedule

    /// This page, or where to go instead when it names a schedule that no longer exists.
    public func resolved(scheduleIDs: [UUID]) -> SettingsPage {
        guard case .schedule(let id) = self, !scheduleIDs.contains(id) else { return self }
        return Self.firstSchedule(in: scheduleIDs)
    }

    public static func firstSchedule(in scheduleIDs: [UUID]) -> SettingsPage {
        scheduleIDs.first.map(SettingsPage.schedule) ?? .newSchedule
    }
}

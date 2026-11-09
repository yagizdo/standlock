import Foundation

/// What a selection does to the current page.
public enum LeaveDecision: Sendable {
    case stay, go, ask
}

public enum SettingsPage: Hashable, Sendable {
    case general, menuBar, breakScreen, discipline, detection, pomodoro, permissions, statistics, about
    case schedule(UUID), newSchedule

    /// This page, or where to go instead when it names a schedule that no longer exists.
    public func resolved(scheduleIDs: [UUID]) -> SettingsPage {
        guard case .schedule(let id) = self, !scheduleIDs.contains(id) else { return self }
        return Self.firstSchedule(in: scheduleIDs)
    }

    public func leaving(to target: SettingsPage, hasUnsavedEdits: Bool) -> LeaveDecision {
        if target == self { return .stay }
        return hasUnsavedEdits ? .ask : .go
    }

    public static func firstSchedule(in scheduleIDs: [UUID]) -> SettingsPage {
        scheduleIDs.first.map(SettingsPage.schedule) ?? .newSchedule
    }
}

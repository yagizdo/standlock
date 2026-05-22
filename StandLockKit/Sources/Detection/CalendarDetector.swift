import EventKit

public final class CalendarDetector: @unchecked Sendable {
    private let eventStore: EKEventStore
    private let lookAheadMinutes: Int

    public init(lookAheadMinutes: Int = 5) {
        self.eventStore = EKEventStore()
        self.lookAheadMinutes = lookAheadMinutes
    }

    public var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAccess() async -> Bool {
        do {
            if #available(macOS 14, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    public func hasActiveEvent(at date: Date = Date()) -> Bool {
        let hasAccess: Bool
        if #available(macOS 14, *) {
            hasAccess = authorizationStatus == .fullAccess
        } else {
            hasAccess = authorizationStatus == .authorized
        }
        guard hasAccess else { return false }
        let end = date.addingTimeInterval(TimeInterval(lookAheadMinutes * 60))
        let predicate = eventStore.predicateForEvents(withStart: date, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events.contains { !$0.isAllDay && $0.startDate <= date && $0.endDate > date }
    }
}

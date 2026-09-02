import EventKit
import os

public final class CalendarDetector: @unchecked Sendable {
    private let eventStore: EKEventStore
    /// Written from the main actor when the setting changes and read on the detector actor
    /// during a poll, so it cannot be a plain stored property. Baking the value in at init made
    /// the stepper inert until the next coordinator restart.
    private let lookAhead: OSAllocatedUnfairLock<Int>

    public var lookAheadMinutes: Int {
        get { lookAhead.withLock { $0 } }
        set { lookAhead.withLock { $0 = newValue } }
    }

    public init(lookAheadMinutes: Int = 5) {
        self.eventStore = EKEventStore()
        self.lookAhead = OSAllocatedUnfairLock(initialState: lookAheadMinutes)
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

    public static func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    /// True when the event is still running at `date` or starts before the look-ahead window
    /// closes. Deferring only for an already-running event would make the look-ahead setting
    /// inert, since a break triggered minutes before a meeting is exactly what it exists to stop.
    /// The upper bound repeats what the fetch predicate already enforces so the decision stays
    /// testable on its own and does not rely on EventKit's boundary semantics.
    static func overlapsWindow(start: Date, end: Date, isAllDay: Bool,
                               from date: Date, windowEnd: Date) -> Bool {
        !isAllDay && end > date && start < windowEnd
    }

    public func hasActiveEvent(at date: Date = Date()) -> Bool {
        guard Self.isAuthorized(authorizationStatus) else { return false }
        let windowEnd = date.addingTimeInterval(TimeInterval(lookAheadMinutes * 60))
        let predicate = eventStore.predicateForEvents(withStart: date, end: windowEnd, calendars: nil)
        return eventStore.events(matching: predicate).contains {
            Self.overlapsWindow(start: $0.startDate, end: $0.endDate,
                                isAllDay: $0.isAllDay, from: date, windowEnd: windowEnd)
        }
    }
}

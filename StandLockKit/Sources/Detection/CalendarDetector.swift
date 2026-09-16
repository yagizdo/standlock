import EventKit
import os
import StandLockCore

public final class CalendarDetector: @unchecked Sendable {
    private let eventStore: EKEventStore
    /// Written from the main actor when the setting changes and read on the detector actor
    /// during a poll, so it cannot be a plain stored property. Baking the value in at init made
    /// the stepper inert until the next coordinator restart.
    private let lookAhead: OSAllocatedUnfairLock<Int>
    /// Whether every calendar defers breaks or only the ones picked in Settings. Pushed from
    /// the main actor when the setting changes, read on the detector actor during a poll.
    private let selectionMode: OSAllocatedUnfairLock<CalendarSelectionMode>
    private let selectedCalendars: OSAllocatedUnfairLock<Set<String>>

    public var lookAheadMinutes: Int {
        get { lookAhead.withLock { $0 } }
        set { lookAhead.withLock { $0 = newValue } }
    }

    public var calendarSelectionMode: CalendarSelectionMode {
        get { selectionMode.withLock { $0 } }
        set { selectionMode.withLock { $0 = newValue } }
    }

    public var selectedCalendarIdentifiers: Set<String> {
        get { selectedCalendars.withLock { $0 } }
        set { selectedCalendars.withLock { $0 = newValue } }
    }

    public init(lookAheadMinutes: Int = 5,
                calendarSelectionMode: CalendarSelectionMode = .all,
                selectedCalendarIdentifiers: Set<String> = []) {
        self.eventStore = EKEventStore()
        self.lookAhead = OSAllocatedUnfairLock(initialState: lookAheadMinutes)
        self.selectionMode = OSAllocatedUnfairLock(initialState: calendarSelectionMode)
        self.selectedCalendars = OSAllocatedUnfairLock(initialState: selectedCalendarIdentifiers)
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

    /// In the all-calendars mode everything counts. In the selected mode only the picked
    /// calendars do, and an event without a calendar is left out because it cannot be matched.
    static func isCalendarIncluded(_ identifier: String?, mode: CalendarSelectionMode,
                                   selected: Set<String>) -> Bool {
        switch mode {
        case .all:
            return true
        case .selected:
            guard let identifier else { return false }
            return selected.contains(identifier)
        }
    }

    public func hasActiveEvent(at date: Date = Date()) -> Bool {
        guard Self.isAuthorized(authorizationStatus) else { return false }
        let windowEnd = date.addingTimeInterval(TimeInterval(lookAheadMinutes * 60))
        let mode = calendarSelectionMode
        let selected = selectedCalendarIdentifiers
        let predicate = eventStore.predicateForEvents(withStart: date, end: windowEnd, calendars: nil)
        return eventStore.events(matching: predicate).contains { event in
            Self.isCalendarIncluded(event.calendar?.calendarIdentifier, mode: mode, selected: selected)
                && Self.overlapsWindow(start: event.startDate, end: event.endDate,
                                       isAllDay: event.isAllDay, from: date, windowEnd: windowEnd)
        }
    }

    /// Apple: a store that existed before calendar access was granted returns no data until it
    /// is reset, which is why the calendar list stayed empty until the app was restarted.
    public func resetStore() {
        eventStore.reset()
    }

    /// The event calendars a break can be deferred for, for the Settings list. Reminders are
    /// left out: a break cannot be deferred for one.
    public func availableCalendars() -> [CalendarInfo] {
        guard Self.isAuthorized(authorizationStatus) else { return [] }
        return eventStore.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title) }
            .sorted { ($0.title, $0.source) < ($1.title, $1.source) }
    }
}

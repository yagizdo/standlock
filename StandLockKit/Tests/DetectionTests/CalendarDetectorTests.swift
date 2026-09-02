import Testing
@testable import Detection
import EventKit

@Suite("CalendarDetector.isAuthorized")
struct CalendarDetectorAuthorizationTests {

    @Test func notDeterminedIsNotAuthorized() {
        #expect(!CalendarDetector.isAuthorized(.notDetermined))
    }

    @Test func deniedIsNotAuthorized() {
        #expect(!CalendarDetector.isAuthorized(.denied))
    }

    @Test func restrictedIsNotAuthorized() {
        #expect(!CalendarDetector.isAuthorized(.restricted))
    }

    @Test func authorizedIsAuthorized() {
        #expect(CalendarDetector.isAuthorized(.authorized))
    }

    @available(macOS 14, *)
    @Test func fullAccessIsAuthorized() {
        #expect(CalendarDetector.isAuthorized(.fullAccess))
    }

    @available(macOS 14, *)
    @Test func writeOnlyIsNotAuthorized() {
        #expect(!CalendarDetector.isAuthorized(.writeOnly))
    }
}

@Suite("CalendarDetector.overlapsWindow")
struct CalendarDetectorWindowTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var windowEnd: Date { now.addingTimeInterval(5 * 60) }

    private func overlaps(start: TimeInterval, end: TimeInterval, isAllDay: Bool = false) -> Bool {
        CalendarDetector.overlapsWindow(
            start: now.addingTimeInterval(start),
            end: now.addingTimeInterval(end),
            isAllDay: isAllDay,
            from: now,
            windowEnd: windowEnd
        )
    }

    @Test func runningEventOverlaps() {
        #expect(overlaps(start: -10 * 60, end: 10 * 60))
    }

    @Test func eventStartingInsideWindowOverlaps() {
        #expect(overlaps(start: 3 * 60, end: 33 * 60))
    }

    @Test func eventStartingAfterWindowDoesNotOverlap() {
        #expect(!overlaps(start: 10 * 60, end: 40 * 60))
    }

    @Test func eventStartingExactlyAtWindowEndDoesNotOverlap() {
        #expect(!overlaps(start: 5 * 60, end: 35 * 60))
    }

    @Test func finishedEventDoesNotOverlap() {
        #expect(!overlaps(start: -30 * 60, end: -60))
    }

    @Test func eventEndingExactlyNowDoesNotOverlap() {
        #expect(!overlaps(start: -30 * 60, end: 0))
    }

    @Test func allDayEventDoesNotOverlap() {
        #expect(!overlaps(start: -6 * 3600, end: 18 * 3600, isAllDay: true))
    }
}

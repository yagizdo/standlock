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

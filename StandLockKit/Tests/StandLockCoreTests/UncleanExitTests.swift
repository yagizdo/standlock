import Foundation
import Testing
@testable import StandLockCore

@Suite("Unclean exit guard")
struct UncleanExitTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func noMarkerNoGuard() {
        #expect(UncleanExit.launchGuard(breakOnScreenSince: nil, now: now) == nil)
    }

    @Test func markerGivesGentleAfterGrace() {
        let launchGuard = UncleanExit.launchGuard(breakOnScreenSince: now.addingTimeInterval(-60), now: now)
        #expect(launchGuard == LaunchGuard(notBefore: now.addingTimeInterval(TimeInterval(15 * 60)), level: .gentle))
    }

    /// A clock change or a marker months old still means that run never ended its break.
    @Test(arguments: [86_400.0 * 30, -86_400.0 * 400, 1e300, -1e300])
    func markerDateIsNotTrusted(offset: TimeInterval) {
        let marker = Date(timeIntervalSinceReferenceDate: 800_000_000 + offset)
        #expect(UncleanExit.launchGuard(breakOnScreenSince: marker, now: now)
            == UncleanExit.launchGuard(breakOnScreenSince: now, now: now))
    }
}

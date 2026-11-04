import Testing
@testable import StandLockCore

@Suite("SettingsPage Tests")
struct SettingsPageTests {

    @Test func casesAreDistinct() {
        let pages: Set<SettingsPage> = [.general, .schedules, .detection, .permissions, .statistics, .about]
        #expect(pages.count == 6)
    }
}

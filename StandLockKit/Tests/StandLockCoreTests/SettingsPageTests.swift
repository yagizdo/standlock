import Testing
@testable import StandLockCore

@Suite("SettingsPage Tests")
struct SettingsPageTests {

    @Test func casesAreDistinct() {
        let pages: Set<SettingsPage> = [.general, .menuBar, .schedules, .detection, .permissions, .statistics, .about]
        #expect(pages.count == 7)
    }
}

import Foundation
import Testing
@testable import StandLockCore

@Suite("Stored data")
struct StoredDataTests {

    /// A newer build's level and day rule, and one damaged schedule, used to drop every schedule
    /// and every preference; the next save then wrote the empty state over the stored blob.
    @Test func unreadableValueCostsOnlyThatValueAndKeepsACopy() throws {
        let domain = "com.yagizdokumaci.standlock.tests.stored-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer {
            defaults.removePersistentDomain(forName: domain)
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/\(domain).plist")
            try? FileManager.default.removeItem(at: plist)
        }

        let schedules = Data("""
        [
          {"id":"6F1E2B3C-0000-4000-8000-000000000001","name":"Work","days":{"weekdays":{}},
           "windows":[],"breakInterval":1800,"breakDuration":300,"disciplineLevel":"strict"},
          {"id":"6F1E2B3C-0000-4000-8000-000000000002","name":"Later","days":{"alternateWeeks":{}},
           "windows":[],"breakInterval":1800,"breakDuration":300,"disciplineLevel":"extreme"},
          {"name":"Damaged","days":{"everyDay":{}},
           "windows":[],"breakInterval":1800,"breakDuration":300}
        ]
        """.utf8)
        let preferences = Data(#"{"gentleDailySkipLimit":9,"cameraDetection":"blurCamera"}"#.utf8)
        defaults.set(schedules, forKey: "schedules")
        defaults.set(preferences, forKey: "preferences")

        let loaded = try #require(StoredData.loadEach(Schedule.self, forKey: "schedules", in: defaults))
        #expect(loaded.map(\.name) == ["Work", "Later"])
        #expect(loaded.map(\.disciplineLevel) == [.strict, .gentle])
        #expect(loaded.map(\.days) == [.weekdays, .everyDay])
        #expect(loaded.map(\.isEnabled) == [true, true])
        #expect(defaults.data(forKey: "schedules.unreadable") == schedules)

        let prefs = try #require(StoredData.load(AppPreferences.self, forKey: "preferences", in: defaults))
        #expect(prefs.gentleDailySkipLimit == 9)
        #expect(prefs.cameraDetection == .deferBreak)
        #expect(defaults.data(forKey: "preferences.unreadable") == preferences)
    }
}

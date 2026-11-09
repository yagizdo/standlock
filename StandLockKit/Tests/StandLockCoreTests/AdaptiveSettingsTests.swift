import Foundation
import Testing
@testable import StandLockCore

@Suite("Adaptive settings")
struct AdaptiveSettingsTests {
    @Test func legacyIdleSettingIsIgnoredAndThresholdDefaultsToFive() throws {
        let preferences = try JSONDecoder().decode(AppPreferences.self,
            from: Data("{\"idleDetectionEnabled\":true}".utf8))
        #expect(preferences.naturalBreakThresholdMinutes == 5)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        #expect(encoded["idleDetectionEnabled"] == nil)
    }

    @Test func capAndThresholdRoundTripAndAppearInImportSummary() throws {
        var draft = ScheduleDraft(schedule: nil)
        draft.name = "Work"
        draft.progressiveEnforcement = true
        draft.consecutiveSkipLimit = 2
        let schedule = draft.build(existing: nil)
        #expect(ScheduleDraft(schedule: schedule).consecutiveSkipLimit == 2)
        let original = SettingsExport(preferences: AppPreferences(), schedules: [schedule], theme: nil, language: nil, showHelp: true)
        var changed = original
        changed.preferences.naturalBreakThresholdMinutes = 10
        let decoded = try SettingsExport.decode(changed.encoded())
        #expect(decoded == changed)
        #expect(SettingsImportSummary(current: original, imported: decoded).changedPages == [.detection])
    }

    @Test(arguments: [0, 31]) func invalidThresholdCannotBeImported(_ minutes: Int) throws {
        var export = SettingsExport(preferences: AppPreferences(), schedules: [], theme: nil, language: nil, showHelp: true)
        export.preferences.naturalBreakThresholdMinutes = minutes
        let data = try export.encoded()
        #expect(throws: SettingsImportError.unreadable) { try SettingsExport.decode(data) }
    }

    @Test(arguments: [0, 21]) func invalidCapCannotBeImported(_ cap: Int) throws {
        var draft = ScheduleDraft(schedule: nil)
        draft.name = "Work"
        var schedule = draft.build(existing: nil)
        schedule.consecutiveSkipLimit = cap
        let export = SettingsExport(preferences: AppPreferences(), schedules: [schedule], theme: nil, language: nil, showHelp: true)
        let data = try export.encoded()
        #expect(throws: SettingsImportError.unreadable) { try SettingsExport.decode(data) }
    }
}

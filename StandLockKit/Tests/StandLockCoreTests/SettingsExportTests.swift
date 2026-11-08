import Foundation
import Testing
@testable import StandLockCore

@Suite("Settings Export")
struct SettingsExportTests {

    // MARK: - Fixtures

    static let workID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let eveningID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    static func fullSchedules() -> [Schedule] {
        [
            Schedule(
                id: workID,
                name: "Work",
                days: .custom([.monday, .wednesday, .friday]),
                windows: [
                    TimeWindow(startHour: 9, startMinute: 0, endHour: 12, endMinute: 30),
                    TimeWindow(startHour: 22, startMinute: 0, endHour: 2, endMinute: 0),
                ],
                breakInterval: 25 * 60, breakDuration: 5 * 60,
                intervalCycle: [IntervalStep(duration: 1500, label: "Focus"), IntervalStep(duration: 900)],
                repetitionRule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 300, longBreakDuration: 900),
                disciplineLevel: .strict,
                dailyBreakCap: 8,
                progressiveEnforcement: true
            ),
            Schedule(
                id: eveningID,
                name: "Evening",
                isEnabled: false,
                days: .weekends,
                windows: [TimeWindow(startHour: 18, startMinute: 15, endHour: 21, endMinute: 45)],
                breakInterval: 6, breakDuration: 3,
                disciplineLevel: .firm
            ),
        ]
    }

    static func fullPreferences() -> AppPreferences {
        AppPreferences(
            gentleDailySkipLimit: 2,
            firmSkipDelay: 30,
            firmEscapePhrase: "let me out",
            firmDailySkipLimit: 1,
            strictEscapeHoldDuration: 15,
            cameraDetection: .ignore,
            microphoneDetection: .reduceToGentle,
            calendarDetectionEnabled: false,
            calendarLookAheadMinutes: 10,
            screenSharingDetectionEnabled: false,
            screenSharingPostDeferral: .skipBreak,
            postponeReturnDelay: 60,
            idleDetectionEnabled: false,
            pauseMediaDuringBreak: false,
            soundBeforeBreak: true,
            soundAfterBreak: true,
            resetIntervalOnSkip: false,
            showFullWorkTimer: true,
            menuBarCountdownMinutes: 3,
            menuScene: .off,
            breakScreen: BreakScreenPreferences(backgroundHex: "#112233", textHex: "#EEEEEE", showsStatistics: false, message: "Stretch")
        )
    }

    static func full() -> SettingsExport {
        SettingsExport(
            preferences: fullPreferences(),
            schedules: fullSchedules(),
            theme: "dark",
            language: "tr",
            showHelp: false
        )
    }

    /// Encodes `export`, lets `change` edit the JSON object, and returns the edited bytes.
    static func edited(_ export: SettingsExport = full(), _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: export.encoded()) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Edits the first schedule of the encoded fixture.
    static func editedSchedule(_ change: @escaping (inout [String: Any]) -> Void) throws -> Data {
        try edited { object in
            var schedules = object["schedules"] as! [[String: Any]]
            change(&schedules[0])
            object["schedules"] = schedules
        }
    }

    static func decodeError(_ data: Data) -> SettingsImportError? {
        do {
            _ = try SettingsExport.decode(data)
            return nil
        } catch let error as SettingsImportError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: - Round trip

    @Test func fullValueRoundTrips() throws {
        let export = Self.full()
        #expect(try SettingsExport.decode(export.encoded()) == export)
    }

    @Test func emptyScheduleListRoundTrips() throws {
        let export = SettingsExport(preferences: AppPreferences(), schedules: [], theme: nil, language: nil, showHelp: true)
        let decoded = try SettingsExport.decode(export.encoded())
        #expect(decoded == export)
        #expect(decoded.schedules.isEmpty)
        #expect(decoded.theme == nil)
        #expect(decoded.language == nil)
    }

    @Test func encodedCarriesFormatAndVersion() throws {
        let object = try #require(JSONSerialization.jsonObject(with: Self.full().encoded()) as? [String: Any])
        #expect(object["format"] as? String == SettingsExport.formatIdentifier)
        #expect(object["version"] as? Int == 1)
        #expect(object["preferences"] != nil)
        #expect(object["schedules"] != nil)
        #expect(object["showHelp"] as? Bool == false)
    }

    // MARK: - Newer files

    @Test func unknownKeysAreIgnored() throws {
        let data = try Self.edited { object in
            object["addedLater"] = ["anything": 1]
            var preferences = object["preferences"] as! [String: Any]
            preferences["somePreferenceFromLater"] = true
            object["preferences"] = preferences
        }
        #expect(try SettingsExport.decode(data) == Self.full())
    }

    @Test func newerVersionIsRefused() throws {
        let data = try Self.edited { $0["version"] = 2 }
        #expect(Self.decodeError(data) == .newerVersion)
    }

    @Test func unknownDisciplineLevelFailsTheWholeImport() throws {
        let data = try Self.editedSchedule { $0["disciplineLevel"] = "monk" }
        #expect(Self.decodeError(data) == .unreadable)
    }

    // MARK: - Not a settings file

    @Test func garbageIsNotASettingsFile() {
        #expect(Self.decodeError(Data([0xFF, 0x00, 0x13, 0x37])) == .notSettingsFile)
    }

    @Test func emptyObjectIsNotASettingsFile() {
        #expect(Self.decodeError(Data("{}".utf8)) == .notSettingsFile)
    }

    @Test func otherFormatIsNotASettingsFile() throws {
        let data = try Self.edited { $0["format"] = "com.example.other" }
        #expect(Self.decodeError(data) == .notSettingsFile)
    }

    @Test func missingVersionIsNotASettingsFile() throws {
        let data = try Self.edited { $0.removeValue(forKey: "version") }
        #expect(Self.decodeError(data) == .notSettingsFile)
    }

    @Test func jsonArrayIsNotASettingsFile() {
        #expect(Self.decodeError(Data("[1, 2]".utf8)) == .notSettingsFile)
    }

    // MARK: - Values the app cannot run

    @Test func duplicateScheduleIDsAreUnreadable() throws {
        let data = try Self.edited { object in
            var schedules = object["schedules"] as! [[String: Any]]
            schedules[1]["id"] = schedules[0]["id"]
            object["schedules"] = schedules
        }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test func negativeShortBreakCountIsUnreadable() throws {
        let data = try Self.editedSchedule { schedule in
            var rule = schedule["repetitionRule"] as! [String: Any]
            rule["shortBreakCount"] = -1
            schedule["repetitionRule"] = rule
        }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test(arguments: [0.0, -60.0])
    func nonPositiveBreakIntervalIsUnreadable(value: Double) throws {
        let data = try Self.editedSchedule { $0["breakInterval"] = value }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test(arguments: [0.0, -1.0])
    func nonPositiveBreakDurationIsUnreadable(value: Double) throws {
        let data = try Self.editedSchedule { $0["breakDuration"] = value }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test func nonPositiveCycleStepIsUnreadable() throws {
        let data = try Self.editedSchedule { schedule in
            var steps = schedule["intervalCycle"] as! [[String: Any]]
            steps[1]["duration"] = 0
            schedule["intervalCycle"] = steps
        }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test(arguments: ["shortBreakDuration", "longBreakDuration"])
    func nonPositiveRepetitionDurationIsUnreadable(key: String) throws {
        let data = try Self.editedSchedule { schedule in
            var rule = schedule["repetitionRule"] as! [String: Any]
            rule[key] = -5
            schedule["repetitionRule"] = rule
        }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test(arguments: [("startHour", 24), ("endHour", -1), ("startMinute", 60), ("endMinute", -1)])
    func windowOutsideTheClockIsUnreadable(key: String, value: Int) throws {
        let data = try Self.editedSchedule { schedule in
            var windows = schedule["windows"] as! [[String: Any]]
            windows[0][key] = value
            schedule["windows"] = windows
        }
        #expect(Self.decodeError(data) == .unreadable)
    }

    @Test func subMinuteValuesStayReadable() throws {
        // Older stored schedules can sit below the form's ranges; the file must still load.
        let data = try Self.editedSchedule { schedule in
            schedule["breakInterval"] = 6.0
            schedule["breakDuration"] = 3.0
        }
        let decoded = try SettingsExport.decode(data)
        #expect(decoded.schedules[0].breakInterval == TimeInterval(6))
    }

    // MARK: - Calendar selection

    @Test func encodedDropsCalendarSelection() throws {
        var export = Self.full()
        export.preferences.calendarSelectionMode = .selected
        export.preferences.selectedCalendarIdentifiers = ["A", "B"]
        let object = try #require(JSONSerialization.jsonObject(with: export.encoded()) as? [String: Any])
        let preferences = try #require(object["preferences"] as? [String: Any])
        #expect(preferences["calendarSelectionMode"] as? String == "all")
        #expect((preferences["selectedCalendarIdentifiers"] as? [String]) == [])
    }

    @Test func decodeDropsCalendarSelection() throws {
        let data = try Self.edited { object in
            var preferences = object["preferences"] as! [String: Any]
            preferences["calendarSelectionMode"] = "selected"
            preferences["selectedCalendarIdentifiers"] = ["A", "B"]
            object["preferences"] = preferences
        }
        let decoded = try SettingsExport.decode(data)
        #expect(decoded.preferences.calendarSelectionMode == .all)
        #expect(decoded.preferences.selectedCalendarIdentifiers.isEmpty)
    }

    // MARK: - Theme and language

    @Test func knownChoicesAreKept() {
        let current = SettingsExport(preferences: AppPreferences(), schedules: [], theme: "light", language: "en", showHelp: true)
        let result = Self.full().keepingKnownChoices(languages: ["en", "tr"], themes: ["light", "dark"], current: current)
        #expect(result.theme == "dark")
        #expect(result.language == "tr")
    }

    @Test func unknownChoicesKeepTheCurrentOnes() {
        var imported = Self.full()
        imported.theme = "solarized"
        imported.language = "fr"
        let current = SettingsExport(preferences: AppPreferences(), schedules: [], theme: "light", language: nil, showHelp: true)
        let result = imported.keepingKnownChoices(languages: ["en", "tr"], themes: ["light", "dark"], current: current)
        #expect(result.theme == "light")
        #expect(result.language == nil)
        #expect(result.schedules == imported.schedules)
    }

    @Test func nilChoicesPassThrough() {
        var imported = Self.full()
        imported.theme = nil
        imported.language = nil
        let current = SettingsExport(preferences: AppPreferences(), schedules: [], theme: "light", language: "en", showHelp: true)
        let result = imported.keepingKnownChoices(languages: ["en"], themes: ["light"], current: current)
        #expect(result.theme == nil)
        #expect(result.language == nil)
    }
}

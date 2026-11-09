import Foundation
import Testing
@testable import StandLockCore

@Suite("Settings Import Limits")
struct SettingsImportLimitsTests {
    @Test func oversizedDataIsRejectedBeforeDecoding() throws {
        var data = try SettingsExportTests.full().encoded()
        data.append(Data(repeating: 0x20, count: 1_048_577))
        #expect(SettingsExportTests.decodeError(data) != nil)
    }

    @Test func tooManySchedulesAreRejected() throws {
        var export = SettingsExportTests.full()
        export.schedules = (0..<101).map { index in
            Schedule(name: "Schedule \(index)", days: .everyDay,
                     windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
                     breakInterval: 60, breakDuration: 5)
        }
        #expect(SettingsExportTests.decodeError(try export.encoded()) != nil)
    }

    @Test func tooManyWindowsAreRejected() throws {
        var export = SettingsExportTests.full()
        export.schedules[0].windows = Array(repeating: export.schedules[0].windows[0], count: 33)
        #expect(SettingsExportTests.decodeError(try export.encoded()) != nil)
    }

    @Test func tooManyCycleStepsAreRejected() throws {
        var export = SettingsExportTests.full()
        export.schedules[0].intervalCycle = Array(repeating: IntervalStep(duration: 60), count: 101)
        #expect(SettingsExportTests.decodeError(try export.encoded()) != nil)
    }

    @Test(arguments: ["name", "label", "message", "phrase", "theme", "language"])
    func oversizedTextIsRejected(field: String) throws {
        var export = SettingsExportTests.full()
        switch field {
        case "name": export.schedules[0].name = String(repeating: "x", count: 257)
        case "label": export.schedules[0].intervalCycle?[0].label = String(repeating: "x", count: 257)
        case "message": export.preferences.breakScreen.message = String(repeating: "x", count: 4097)
        case "phrase": export.preferences.firmEscapePhrase = String(repeating: "x", count: 1025)
        case "theme": export.theme = String(repeating: "x", count: 129)
        default: export.language = String(repeating: "x", count: 129)
        }
        #expect(SettingsExportTests.decodeError(try export.encoded()) != nil)
    }

    @Test func calendarIdentifiersAreCheckedBeforeNormalization() throws {
        let data = try SettingsExportTests.edited { object in
            var preferences = object["preferences"] as! [String: Any]
            preferences["selectedCalendarIdentifiers"] = Array(repeating: "calendar", count: 257)
            object["preferences"] = preferences
        }
        #expect(SettingsExportTests.decodeError(data) != nil)
    }

    @Test func unicodeTextUsesAByteBudget() throws {
        var export = SettingsExportTests.full()
        export.preferences.breakScreen.message = String(repeating: "🙂", count: 1100)
        #expect(SettingsExportTests.decodeError(try export.encoded()) != nil)
    }

    @Test func exactByteBudgetRemainsReadable() throws {
        let export = SettingsExportTests.full()
        var data = try export.encoded()
        data.append(Data(repeating: 0x20, count: SettingsExport.maximumFileSize - data.count))
        #expect(try SettingsExport.decode(data) == export)
        data.append(0x20)
        #expect(SettingsExportTests.decodeError(data) == .tooLarge)
    }

    @Test func collectionAndTextBoundaryValuesRemainReadable() throws {
        var export = SettingsExportTests.full()
        export.schedules[0].windows = Array(repeating: export.schedules[0].windows[0], count: 32)
        export.schedules[0].intervalCycle = Array(repeating: IntervalStep(duration: 60), count: 100)
        export.schedules[0].name = String(repeating: "x", count: 256)
        export.schedules[0].intervalCycle?[0].label = String(repeating: "x", count: 256)
        export.preferences.firmEscapePhrase = String(repeating: "x", count: 1024)
        export.preferences.breakScreen.message = String(repeating: "x", count: 4096)
        export.theme = String(repeating: "x", count: 128)
        export.language = String(repeating: "x", count: 128)
        #expect(try SettingsExport.decode(export.encoded()) == export)
    }

    @Test func scheduleCountBoundaryRemainsReadable() throws {
        var export = SettingsExportTests.full()
        export.schedules = (0..<100).map { index in
            Schedule(name: "Schedule \(index)", days: .everyDay, windows: [], breakInterval: 60, breakDuration: 5)
        }
        #expect(try SettingsExport.decode(export.encoded()) == export)
    }

    @Test func calendarIdentifierByteBudgetIsCheckedBeforeNormalization() throws {
        let data = try SettingsExportTests.edited { object in
            var preferences = object["preferences"] as! [String: Any]
            preferences["selectedCalendarIdentifiers"] = [String(repeating: "x", count: 1025)]
            object["preferences"] = preferences
        }
        #expect(SettingsExportTests.decodeError(data) == .tooLarge)
    }
}

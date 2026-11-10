import Foundation
import Testing
@testable import StandLockCore

@Suite("Settings Import Summary")
struct SettingsImportSummaryTests {

    static let workID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let readingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let eveningID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static func schedule(_ id: UUID, _ name: String, interval: TimeInterval = 1500) -> Schedule {
        Schedule(
            id: id, name: name, days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: interval, breakDuration: 300
        )
    }

    static func base(_ change: (inout SettingsExport) -> Void = { _ in }) -> SettingsExport {
        var export = SettingsExport(
            preferences: AppPreferences(),
            schedules: [schedule(workID, "Work"), schedule(readingID, "Reading")],
            theme: "light", language: "en", showHelp: true
        )
        change(&export)
        return export
    }

    static func pages(_ change: (inout SettingsExport) -> Void) -> [SettingsPage] {
        SettingsImportSummary(current: base(), imported: base(change)).changedPages
    }

    @Test func identicalValuesChangeNothing() {
        let summary = SettingsImportSummary(current: Self.base(), imported: Self.base())
        #expect(summary.isEmpty)
        #expect(summary.changedPages.isEmpty)
    }

    @Test func themeAndLanguageAreGeneral() {
        #expect(Self.pages { $0.theme = "dark" } == [.general])
        #expect(Self.pages { $0.language = "tr" } == [.general])
        #expect(Self.pages { $0.theme = nil } == [.general])
    }

    @Test func showHelpIsNotAPage() {
        let summary = SettingsImportSummary(current: Self.base(), imported: Self.base { $0.showHelp = false })
        #expect(summary.changesShowHelp)
        #expect(summary.changedPages.isEmpty)
        #expect(!summary.isEmpty)
    }

    @Test func preferenceFieldsMapToTheirPages() {
        #expect(Self.pages { $0.preferences.menuScene = .off } == [.menuBar])
        #expect(Self.pages { $0.preferences.soundBeforeBreak = true } == [.breakScreen])
        #expect(Self.pages { $0.preferences.breakScreen.message = "Hi" } == [.breakScreen])
        #expect(Self.pages { $0.preferences.firmEscapePhrase = "out" } == [.discipline])
        #expect(Self.pages { $0.preferences.resetIntervalOnSkip = false } == [.discipline])
        #expect(Self.pages { $0.preferences.idleDetectionEnabled = false } == [.detection])
    }

    @Test func importChangingPomodoroListsPomodoroPage() {
        #expect(Self.pages { $0.preferences.pomodoro.rounds = 6 } == [.pomodoro])
    }

    @Test func pagesComeInSidebarOrder() {
        let pages = Self.pages { export in
            export.preferences.idleDetectionEnabled = false
            export.preferences.gentleDailySkipLimit = 1
            export.preferences.pauseMediaDuringBreak = false
            export.preferences.showFullWorkTimer = true
            export.preferences.pomodoro.focus = 3000
            export.theme = "dark"
        }
        #expect(pages == [.general, .menuBar, .breakScreen, .discipline, .detection, .pomodoro])
    }

    @Test func schedulesAreMatchedByID() {
        let imported = Self.base { export in
            export.schedules = [
                Self.schedule(Self.workID, "Work", interval: 3000),
                Self.schedule(Self.eveningID, "Evening"),
            ]
        }
        let summary = SettingsImportSummary(current: Self.base(), imported: imported)
        #expect(summary.addedSchedules == ["Evening"])
        #expect(summary.removedSchedules == ["Reading"])
        #expect(summary.changedSchedules == ["Work"])
        #expect(summary.changedPages.isEmpty)
        #expect(!summary.isEmpty)
    }

    @Test func renamedScheduleIsChanged() {
        let imported = Self.base { $0.schedules[1].name = "Books" }
        let summary = SettingsImportSummary(current: Self.base(), imported: imported)
        #expect(summary.changedSchedules == ["Books"])
        #expect(summary.addedSchedules.isEmpty)
        #expect(summary.removedSchedules.isEmpty)
    }

    @Test func selectedCalendarsAreDropped() {
        let current = Self.base { export in
            export.preferences.calendarSelectionMode = .selected
            export.preferences.selectedCalendarIdentifiers = ["A"]
        }
        let summary = SettingsImportSummary(current: current, imported: Self.base())
        #expect(summary.dropsCalendarSelection)
        #expect(summary.changedPages == [.detection])
    }

    @Test func leftoverCalendarIDsInAllModeChangeNothing() throws {
        // The Detection page never clears the list when the user goes back to all calendars.
        let current = Self.base { $0.preferences.selectedCalendarIdentifiers = ["A", "B"] }
        let imported = try SettingsExport.decode(current.encoded())
        let summary = SettingsImportSummary(current: current, imported: imported)
        #expect(summary.isEmpty)
        #expect(!summary.dropsCalendarSelection)
    }

    @Test func everyPreferenceIsMapped() {
        let stored = Set(Mirror(reflecting: AppPreferences()).children.compactMap(\.label))
        let mapped = Set(SettingsImportSummary.preferenceFields().map(\.name))
        #expect(stored == mapped)
    }
}

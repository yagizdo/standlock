import Testing
@testable import StandLockCore

@Suite("Calendar selection")
struct CalendarSelectionTests {
    @Test func addingAppendsAfterTheOthers() {
        var preferences = AppPreferences(selectedCalendarIdentifiers: ["a"])
        preferences.setCalendar("b", isSelected: true)
        #expect(preferences.selectedCalendarIdentifiers == ["a", "b"])
    }

    @Test func addingTwiceKeepsOneEntry() {
        var preferences = AppPreferences(selectedCalendarIdentifiers: ["a"])
        preferences.setCalendar("a", isSelected: true)
        #expect(preferences.selectedCalendarIdentifiers == ["a"])
    }

    @Test func removingKeepsTheOrderOfTheOthers() {
        var preferences = AppPreferences(selectedCalendarIdentifiers: ["a", "b", "c"])
        preferences.setCalendar("b", isSelected: false)
        #expect(preferences.selectedCalendarIdentifiers == ["a", "c"])
    }

    @Test func removingAnAbsentCalendarChangesNothing() {
        var preferences = AppPreferences(selectedCalendarIdentifiers: ["a"])
        preferences.setCalendar("z", isSelected: false)
        #expect(preferences.selectedCalendarIdentifiers == ["a"])
    }

    @Test func preCheckRunsOnlyForAnEmptySpecificSelection() {
        #expect(AppPreferences(calendarSelectionMode: .selected).needsCalendarPreCheck)
        #expect(!AppPreferences(calendarSelectionMode: .all).needsCalendarPreCheck)
        #expect(!AppPreferences(
            calendarSelectionMode: .selected,
            selectedCalendarIdentifiers: ["a"]
        ).needsCalendarPreCheck)
    }
}

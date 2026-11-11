import Foundation
import Testing
@testable import StandLockCore

private func schedule(
    _ name: String, days: Set<Weekday> = [.monday], from start: Int, to end: Int, enabled: Bool = true
) -> Schedule {
    Schedule(
        name: name, isEnabled: enabled, days: .custom(days),
        windows: [TimeWindow(startHour: start, startMinute: 0, endHour: end, endMinute: 0)],
        breakInterval: 1200, breakDuration: 20
    )
}

struct ScheduleOverlapTests {
    @Test func sameDaysAndIntersectingHoursOverlap() {
        #expect(schedule("a", from: 9, to: 17).overlaps(schedule("b", from: 16, to: 18)))
    }

    @Test func sameHoursOnDifferentDaysDoNotOverlap() {
        #expect(!schedule("a", days: [.monday], from: 9, to: 17)
            .overlaps(schedule("b", days: [.tuesday], from: 9, to: 17)))
    }

    @Test func backToBackWindowsDoNotOverlap() {
        // A window ends before its end minute: 9-12 and 12-17 never run together.
        #expect(!schedule("a", from: 9, to: 12).overlaps(schedule("b", from: 12, to: 17)))
    }

    @Test func midnightWindowCoversTheEarlyHoursOfItsOwnDays() {
        let night = schedule("night", days: [.monday], from: 22, to: 2)
        // The engine reads a time against its own date's weekday: Monday 01:00 is active.
        #expect(night.overlaps(schedule("early", days: [.monday], from: 0, to: 1)))
        #expect(night.overlaps(schedule("late", days: [.monday], from: 23, to: 24)))
        // Tuesday 01:00 is not, so the window does not reach into Tuesday.
        #expect(!night.overlaps(schedule("tuesday", days: [.tuesday], from: 0, to: 1)))
        #expect(!night.overlaps(schedule("evening", days: [.monday], from: 18, to: 22)))
    }

    @Test func emptyWindowOverlapsNothing() {
        #expect(!schedule("a", from: 9, to: 9).overlaps(schedule("b", from: 0, to: 24)))
    }

    @Test func outOfRangeStoredHoursDoNotTrap() {
        #expect(!schedule("a", from: 10, to: -1).overlaps(schedule("b", from: 0, to: 9)))
        #expect(!schedule("a", from: 30, to: 2).overlaps(schedule("b", from: 3, to: 9)))
    }

    @Test func anyPairOfWindowsCounts() {
        var split = schedule("split", from: 8, to: 9)
        split.windows.append(TimeWindow(startHour: 14, startMinute: 0, endHour: 15, endMinute: 0))
        #expect(split.overlaps(schedule("afternoon", from: 13, to: 16)))
        #expect(!split.overlaps(schedule("noon", from: 10, to: 13)))
    }

    @Test func overlappingListsOnlyOtherEnabledSchedules() {
        let a = schedule("a", from: 9, to: 17)
        let off = schedule("off", from: 9, to: 17, enabled: false)
        let apart = schedule("apart", days: [.sunday], from: 9, to: 17)
        let candidate = schedule("new", from: 10, to: 11)
        #expect([a, off, apart, candidate].overlapping(candidate).map(\.name) == ["a"])
    }

    @Test func keptScheduleTurnsOffTheOnesItOverlaps() {
        let a = schedule("a", from: 9, to: 17)
        let b = schedule("b", from: 10, to: 12)
        let c = schedule("c", days: [.friday], from: 9, to: 17)
        let result = [a, b, c].turningOffOverlaps(keeping: b.id)
        #expect(result.map(\.name) == ["a", "b", "c"])
        #expect(result.map(\.isEnabled) == [false, true, true])
    }

    @Test func withoutAWinnerTheFirstEnabledStays() {
        let off = schedule("off", from: 9, to: 17, enabled: false)
        let a = schedule("a", from: 9, to: 17)
        let b = schedule("b", from: 10, to: 12)
        #expect([off, a, b].turningOffOverlaps().map(\.isEnabled) == [false, true, false])
    }

    @Test func aDisabledWinnerTurnsNothingOff() {
        let a = schedule("a", from: 9, to: 17)
        let b = schedule("b", from: 10, to: 12, enabled: false)
        #expect([a, b].turningOffOverlaps(keeping: b.id).map(\.isEnabled) == [true, false])
    }

    @Test func noteNamesWhatAddingTurnsOff() {
        let work = schedule("work", from: 9, to: 17)
        let draft = schedule("new", from: 10, to: 11)
        #expect(ScheduleOverlapNote(schedules: [work], stored: nil, draft: draft, isDirty: false) == .adding([work]))
    }

    @Test func disabledScheduleNoteUsesTheStoredHours() {
        let work = schedule("work", from: 9, to: 17)
        let stored = schedule("evening", from: 10, to: 11, enabled: false)
        var draft = stored
        draft.windows = [TimeWindow(startHour: 18, startMinute: 0, endHour: 22, endMinute: 0)]
        // The switch turns on what is stored, so unsaved hours do not clear the note.
        #expect(ScheduleOverlapNote(schedules: [work, stored], stored: stored, draft: draft, isDirty: true)
            == .turningOn([work]))
    }

    @Test func enabledScheduleNoteFollowsUnsavedHours() {
        let work = schedule("work", from: 9, to: 12)
        let stored = schedule("evening", from: 18, to: 22)
        var draft = stored
        draft.windows = [TimeWindow(startHour: 11, startMinute: 0, endHour: 22, endMinute: 0)]
        #expect(ScheduleOverlapNote(schedules: [work, stored], stored: stored, draft: draft, isDirty: true)
            == .saving([work]))
        #expect(ScheduleOverlapNote(schedules: [work, stored], stored: stored, draft: stored, isDirty: false) == nil)
    }
}

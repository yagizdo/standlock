import Foundation
import Testing
@testable import StandLockCore

@Suite("Schedule rhythm")
struct ScheduleRhythmTests {
    private func stored(duration: TimeInterval = 600, rule: RepetitionRule? = nil) -> Schedule {
        Schedule(name: "Work", days: .weekdays,
                 windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
                 breakInterval: 3000, breakDuration: duration, repetitionRule: rule)
    }

    @Test func longerBreakMustBeStrictlyLonger() {
        let baseline = ScheduleDraft(schedule: stored())
        var draft = baseline
        draft.useRepetition = true
        draft.shortBreakMinutes = 10
        for (minutes, valid) in [(9, false), (10, false), (11, true)] {
            draft.longBreakMinutes = Double(minutes)
            #expect(draft.canSave == valid)
            #expect(draft.canSubmit(from: baseline) == valid)
        }
        draft.useRepetition = false
        draft.longBreakMinutes = 5
        #expect(draft.canSave)
    }

    @Test func comparisonUsesSavedSeconds() {
        var draft = ScheduleDraft(schedule: stored())
        draft.useRepetition = true
        draft.shortBreakMinutes = 29.999
        draft.longBreakMinutes = 30
        #expect(!draft.canSave)
        draft.shortBreakMinutes = 29.9
        #expect(draft.canSave)
    }

    @Test func togglingLongerBreaksPreservesTheFirstLinesDuration() {
        var draft = ScheduleDraft(schedule: stored(duration: 450))
        draft.setLongBreaksEnabled(true)
        #expect(draft.rhythmBreakMinutes == 7.5)
        #expect(draft.build(existing: nil).repetitionRule?.shortBreakDuration == 450)
        draft.rhythmBreakMinutes = 6.25
        #expect(draft.build(existing: nil).repetitionRule?.shortBreakDuration == 375)
        draft.setLongBreaksEnabled(false)
        #expect(draft.rhythmBreakMinutes == 6.25)
        #expect(draft.build(existing: nil).breakDuration == 375)
    }

    @Test func anExistingRuleShowsItsEffectiveShortDurationWithoutChangingTheSchedule() {
        let stored = stored(rule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 120, longBreakDuration: 900))
        let draft = ScheduleDraft(schedule: stored)
        #expect(draft.rhythmBreakMinutes == 2)
        #expect(draft.build(existing: stored) == stored)
        #expect(!draft.hasChanges(from: ScheduleDraft(schedule: stored)))
    }

    @Test func legacyLongBreaksKeepSecondPrecision() {
        let schedule = stored(rule: RepetitionRule(shortBreakCount: 3, shortBreakDuration: 600, longBreakDuration: 601))
        let baseline = ScheduleDraft(schedule: schedule)
        #expect(baseline.canSave)
        #expect(baseline.build(existing: schedule).repetitionRule?.longBreakDuration == 601)
        var renamed = baseline
        renamed.name = "Renamed"
        #expect(renamed.canSubmit(from: baseline))
        #expect(renamed.build(existing: schedule).repetitionRule?.longBreakDuration == 601)
    }

    @Test func enablingLongerBreaksDoesNotClampARegularBreakToThirtyMinutes() {
        var draft = ScheduleDraft(schedule: stored(duration: 42 * 60))
        draft.setLongBreaksEnabled(true)
        draft.longBreakMinutes = 45
        #expect(draft.rhythmBreakMinutes == 42)
        #expect(draft.canSave)
        #expect(draft.build(existing: nil).repetitionRule?.shortBreakDuration == 2520)
    }

    @Test func outOfRangeLongDurationsCannotBeSavedOrOverflowThePreview() {
        var draft = ScheduleDraft(schedule: stored())
        draft.useRepetition = true
        draft.longBreakMinutes = .greatestFiniteMagnitude
        #expect(!draft.canSave)
        // build is called by the preview even before an invalid edit can be saved.
        #expect(draft.build(existing: nil).repetitionRule?.longBreakDuration == 3600)
    }
}

import Foundation
import Testing
@testable import StandLockCore

@Suite("ScheduleDraft Tests")
struct ScheduleDraftTests {

    private func stored(
        breakInterval: TimeInterval = 40 * 60,
        breakDuration: TimeInterval = 10 * 60,
        days: DaySelection = .weekdays,
        cycle: [IntervalStep]? = nil,
        rule: RepetitionRule? = nil
    ) -> Schedule {
        Schedule(
            name: "Work", isEnabled: false, days: days,
            windows: [TimeWindow(startHour: 8, startMinute: 30, endHour: 12, endMinute: 0)],
            breakInterval: breakInterval, breakDuration: breakDuration,
            intervalCycle: cycle, repetitionRule: rule,
            disciplineLevel: .firm, dailyBreakCap: 7, progressiveEnforcement: true
        )
    }

    @Test func roundTripKeepsEveryStoredValue() {
        let schedule = stored(
            days: .custom([.tuesday, .friday]),
            cycle: [IntervalStep(duration: 1500, label: "Sitting"), IntervalStep(duration: 600)],
            rule: RepetitionRule(shortBreakCount: 2, shortBreakDuration: 90, longBreakDuration: 900)
        )
        var expected = schedule
        expected.breakInterval = 1500
        #expect(ScheduleDraft(schedule: schedule).build(existing: schedule) == expected)
    }

    /// The enable toggle stays live while a draft is open, so the draft must not freeze what it
    /// does not edit.
    @Test func buildTakesUneditedValuesFromTheLatestSchedule() {
        let loaded = stored()
        var latest = loaded
        latest.isEnabled = true
        latest.dailyBreakCap = 3

        let built = ScheduleDraft(schedule: loaded).build(existing: latest)

        #expect(built.id == loaded.id)
        #expect(built.isEnabled)
        #expect(built.dailyBreakCap == 3)
    }

    @Test func emptyCustomDaysBecomeMonday() {
        var draft = ScheduleDraft(schedule: stored())
        draft.dayPreset = .custom
        draft.customDays = []
        #expect(draft.build(existing: nil).days == .custom([.monday]))
    }

    @Test func oneIntervalRowHasNoCycleAndDropsItsLabel() {
        var draft = ScheduleDraft(schedule: stored())
        draft.intervalRows = [IntervalRow(minutes: 25, label: "Left over")]
        let built = draft.build(existing: nil)
        #expect(built.intervalCycle == nil)
        #expect(built.breakInterval == TimeInterval(25 * 60))
    }

    @Test func breakIntervalMirrorsTheFirstRow() {
        var draft = ScheduleDraft(schedule: stored())
        draft.intervalRows = [IntervalRow(minutes: 25, label: " Sitting "), IntervalRow(minutes: 10)]
        let built = draft.build(existing: nil)
        #expect(built.breakInterval == TimeInterval(25 * 60))
        #expect(built.intervalCycle == [
            IntervalStep(duration: TimeInterval(25 * 60), label: "Sitting"),
            IntervalStep(duration: TimeInterval(10 * 60)),
        ])
    }

    @Test func nameIsTrimmed() {
        var draft = ScheduleDraft(schedule: stored())
        draft.name = "  Focus  "
        #expect(draft.build(existing: nil).name == "Focus")
    }

    @Test func repetitionOffStoresNoRule() {
        var draft = ScheduleDraft(schedule: stored(
            rule: RepetitionRule(shortBreakCount: 2, shortBreakDuration: 90, longBreakDuration: 900)
        ))
        draft.useRepetition = false
        #expect(draft.build(existing: nil).repetitionRule == nil)
    }

    @Test func newDraftDefaults() {
        let built = ScheduleDraft(schedule: nil).build(existing: nil)
        #expect(built.isEnabled)
        #expect(built.days == .weekdays)
        #expect(built.windows == [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)])
        #expect(built.breakInterval == TimeInterval(40 * 60))
        #expect(built.breakDuration == TimeInterval(10 * 60))
        #expect(built.intervalCycle == nil)
        #expect(built.repetitionRule == nil)
        #expect(built.disciplineLevel == .gentle)
        #expect(built.dailyBreakCap == nil)
        #expect(!built.progressiveEnforcement)
    }

    @Test func aLoadedDraftEqualsItsBaseline() {
        let schedule = stored(cycle: [IntervalStep(duration: 1500), IntervalStep(duration: 600)])
        #expect(ScheduleDraft(schedule: schedule) == ScheduleDraft(schedule: schedule))
    }

    /// Stored values the form cannot show exactly must not read as an edit.
    @Test func aFieldShowingTheRoundedValueIsNotAnEdit() {
        let baseline = ScheduleDraft(schedule: stored(breakDuration: 67))
        var draft = baseline
        draft.breakDurationMinutes = 1.12
        #expect(!draft.hasChanges(from: baseline))
    }

    @Test func aStoredValueTheFormTruncatesIsNotAnEdit() {
        let draft = ScheduleDraft(schedule: stored(breakInterval: 90, breakDuration: 66))
        #expect(!draft.hasChanges(from: ScheduleDraft(schedule: stored(breakInterval: 90, breakDuration: 66))))
    }

    /// Return can save before the field's own clamp has run, so `build` holds the ranges itself.
    @Test func buildKeepsValuesInRange() {
        var draft = ScheduleDraft(schedule: stored())
        draft.intervalRows = [IntervalRow(minutes: 0), IntervalRow(minutes: 999)]
        draft.breakDurationMinutes = 0
        draft.useRepetition = true
        draft.shortBreakMinutes = 500

        let built = draft.build(existing: nil)

        #expect(built.intervalCycle?.map(\.duration) == [TimeInterval(60), TimeInterval(180 * 60)])
        #expect(built.breakInterval == TimeInterval(60))
        #expect(built.breakDuration == TimeInterval(6))
        #expect(built.repetitionRule?.shortBreakDuration == TimeInterval(30 * 60))
    }

    /// A number field parses "NaN". It would stop the whole schedule list encoding.
    @Test func notANumberBecomesTheUpperBound() {
        var draft = ScheduleDraft(schedule: stored())
        draft.breakDurationMinutes = .nan
        #expect(draft.build(existing: nil).breakDuration == TimeInterval(60 * 60))
    }

    /// The change check builds on every body pass, so a pasted number must not trap the multiply.
    @Test func aHugeIntervalDoesNotTrap() {
        let baseline = ScheduleDraft(schedule: stored())
        var draft = baseline
        draft.intervalRows = [IntervalRow(minutes: .max)]
        #expect(draft.hasChanges(from: baseline))
        #expect(draft.build(existing: nil).breakInterval == TimeInterval(180 * 60))
    }

    @Test func submitNeedsANameAndAChange() {
        let baseline = ScheduleDraft(schedule: stored())
        var draft = baseline
        #expect(!draft.canSubmit(from: baseline))
        draft.windows[0].endHour = 13
        #expect(draft.canSubmit(from: baseline))
        draft.name = "  "
        #expect(!draft.canSubmit(from: baseline))
    }

    @Test func hiddenFieldsAreNotChanges() {
        let baseline = ScheduleDraft(schedule: stored())
        var draft = baseline
        draft.customDays = [.sunday]
        draft.shortBreakCount = 9
        draft.intervalRows[0].label = "Hidden at one row"
        draft.name = " Work "
        #expect(!draft.hasChanges(from: baseline))
    }

    @Test func aRealEditIsAChange() {
        let baseline = ScheduleDraft(schedule: stored())
        var draft = baseline
        draft.windows[0].endHour = 13
        #expect(draft.hasChanges(from: baseline))
    }

    @Test func untouchedNewDraftHasNoChangesAndCannotSave() {
        let baseline = ScheduleDraft(schedule: nil)
        var draft = baseline
        #expect(!draft.hasChanges(from: baseline))
        #expect(!draft.canSave)
        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "Focus"
        #expect(draft.hasChanges(from: baseline))
        #expect(draft.canSave)
    }
}

import Foundation
import Testing
@testable import StandLockCore

@Suite("ScheduleTemplate Tests")
struct ScheduleTemplateTests {

    private func applied(_ template: ScheduleTemplate, to draft: ScheduleDraft = ScheduleDraft(schedule: nil)) -> ScheduleDraft {
        var draft = draft
        template.apply(to: &draft)
        return draft
    }

    @Test func twentyTwentyTwentyBuildsTwentySecondsExactly() {
        let built = applied(.twentyTwentyTwenty).build(existing: nil)
        #expect(built.breakInterval == TimeInterval(20 * 60))
        #expect(built.breakDuration == TimeInterval(20))
    }

    @Test func pomodoro() {
        let built = applied(.pomodoro).build(existing: nil)
        #expect(built.breakInterval == TimeInterval(25 * 60))
        #expect(built.breakDuration == TimeInterval(5 * 60))
    }

    @Test func fiftyTwoSeventeen() {
        let built = applied(.fiftyTwoSeventeen).build(existing: nil)
        #expect(built.breakInterval == TimeInterval(52 * 60))
        #expect(built.breakDuration == TimeInterval(17 * 60))
    }

    @Test func oneIntervalRowAndNoRepetition() {
        var draft = ScheduleDraft(schedule: nil)
        draft.intervalRows = [IntervalRow(minutes: 10), IntervalRow(minutes: 20)]
        draft.useRepetition = true

        let result = applied(.fiftyTwoSeventeen, to: draft)

        #expect(result.intervalRows.map(\.minutes) == [52])
        #expect(!result.useRepetition)
        #expect(result.build(existing: nil).intervalCycle == nil)
    }

    @Test func pomodoroTemplateTurnsRepetitionOnThreeShortFifteenLong() {
        var draft = ScheduleDraft(schedule: nil)
        draft.intervalRows = [IntervalRow(minutes: 10), IntervalRow(minutes: 20)]

        let built = applied(.pomodoro, to: draft).build(existing: nil)

        #expect(built.intervalCycle == nil)
        #expect(built.repetitionRule == RepetitionRule(shortBreakCount: 3, shortBreakDuration: 5 * 60, longBreakDuration: 15 * 60))
    }

    @Test func twentyTwentyTwentyLeavesRepetitionOff() {
        var draft = ScheduleDraft(schedule: nil)
        draft.useRepetition = true
        #expect(applied(.twentyTwentyTwenty, to: draft).build(existing: nil).repetitionRule == nil)
    }

    @Test func leavesDaysWindowsAndDisciplineAlone() {
        var draft = ScheduleDraft(schedule: nil)
        draft.days = [.saturday]
        draft.windows = [TimeWindow(startHour: 6, startMinute: 0, endHour: 8, endMinute: 0)]
        draft.disciplineLevel = .strict
        draft.progressiveEnforcement = true

        let result = applied(.fiftyTwoSeventeen, to: draft)

        #expect(result.days == [.saturday])
        #expect(result.windows == draft.windows)
        #expect(result.disciplineLevel == .strict)
        #expect(result.progressiveEnforcement)
    }

    @Test func fillsOnlyABlankName() {
        var draft = ScheduleDraft(schedule: nil)
        draft.name = "   "
        #expect(applied(.pomodoro, to: draft).name == "Pomodoro")

        draft.name = "Focus"
        #expect(applied(.pomodoro, to: draft).name == "Focus")
    }

    @Test func aSecondTemplateReplacesTheFirstOnesName() {
        let result = applied(.fiftyTwoSeventeen, to: applied(.pomodoro))
        #expect(result.name == "52/17")
    }
}

import Foundation
import Testing
@testable import StandLockCore

@Suite("OnboardingChoices Tests")
struct OnboardingChoicesTests {

    private func built(_ rhythm: OnboardingRhythm, level: DisciplineLevel = .gentle, name: String = "Work Hours") -> Schedule? {
        var choices = OnboardingChoices(scene: .hourglass)
        choices.rhythm = rhythm
        choices.level = level
        return choices.schedule(named: name)
    }

    @Test func defaultsAreStandardGentleWithSchedule() {
        let choices = OnboardingChoices(scene: .hourglass)
        #expect(choices.rhythm == .standard)
        #expect(choices.level == .gentle)
        #expect(choices.createsSchedule)
        #expect(choices.scene == .hourglass)
        #expect(!choices.launchAtLogin)
    }

    @Test func standardRhythmIsFortyFiveAndFive() throws {
        let schedule = try #require(built(.standard))
        #expect(schedule.name == "Work Hours")
        #expect(schedule.breakInterval == TimeInterval(45 * 60))
        #expect(schedule.breakDuration == TimeInterval(5 * 60))
        #expect(schedule.days == .weekdays)
        #expect(schedule.windows == [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)])
        #expect(schedule.disciplineLevel == .gentle)
        #expect(!schedule.progressiveEnforcement)
        #expect(schedule.intervalCycle == nil)
        #expect(schedule.repetitionRule == nil)
        #expect(schedule.isEnabled)
    }

    @Test func templatesKeepTheirRhythm() throws {
        let pomodoro = try #require(built(.pomodoro))
        #expect(pomodoro.breakInterval == TimeInterval(25 * 60))
        #expect(pomodoro.breakDuration == TimeInterval(5 * 60))

        let fiftyTwo = try #require(built(.fiftyTwoSeventeen))
        #expect(fiftyTwo.breakInterval == TimeInterval(52 * 60))
        #expect(fiftyTwo.breakDuration == TimeInterval(17 * 60))

        let twenty = try #require(built(.twentyTwentyTwenty))
        #expect(twenty.breakInterval == TimeInterval(20 * 60))
        #expect(twenty.breakDuration == TimeInterval(20))
        #expect(twenty.days == .weekdays)
    }

    /// `ScheduleTemplate.apply` renames a blank draft to the template title.
    @Test func nameIsTheGivenNameEvenWithATemplate() {
        #expect(built(.pomodoro, name: "Çalışma Saatleri")?.name == "Çalışma Saatleri")
    }

    @Test func levelIsCarried() {
        #expect(built(.standard, level: .strict)?.disciplineLevel == .strict)
        #expect(built(.pomodoro, level: .firm)?.disciplineLevel == .firm)
    }

    @Test func setUpLaterBuildsNothing() {
        var choices = OnboardingChoices(scene: .hourglass)
        choices.createsSchedule = false
        #expect(choices.schedule(named: "Work Hours") == nil)
    }

    @Test func strictPermissionAskedOnlyWhenNeeded() {
        var choices = OnboardingChoices(scene: .hourglass)
        choices.level = .strict
        #expect(choices.asksForStrictPermission(strictAvailable: false))
        #expect(!choices.asksForStrictPermission(strictAvailable: true))

        choices.createsSchedule = false
        #expect(!choices.asksForStrictPermission(strictAvailable: false))

        choices.createsSchedule = true
        choices.level = .firm
        #expect(!choices.asksForStrictPermission(strictAvailable: false))
    }

    @Test func stepsRunInOrder() {
        #expect(OnboardingStep.allCases == [.welcome, .schedule, .scene, .menuBar])
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.welcome.next == .schedule)
        #expect(OnboardingStep.schedule.next == .scene)
        #expect(OnboardingStep.scene.previous == .schedule)
        #expect(OnboardingStep.menuBar.next == nil)
    }
}

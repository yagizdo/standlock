import Foundation
import Testing
@testable import StandLockCore

@Suite("Troubleshooting")
struct TroubleshootingTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: Unclean exit status

    @Test func noRecordShowsNothing() {
        #expect(UncleanExitStatus.make(reopenedAt: nil, now: now) == nil)
    }

    @Test func firstBreakStillAheadIsPending() {
        let reopened = now.addingTimeInterval(-6 * 60)
        let status = UncleanExitStatus.make(reopenedAt: reopened, now: now)
        #expect(status == UncleanExitStatus(
            reopenedAt: reopened, firstBreakNotBefore: reopened.addingTimeInterval(UncleanExit.grace),
            isFirstBreakPending: true
        ))
    }

    @Test func daysOldRecordIsShownAsPast() {
        let status = UncleanExitStatus.make(reopenedAt: now.addingTimeInterval(-3 * 86_400), now: now)
        #expect(status?.isFirstBreakPending == false)
    }

    @Test func recordAWeekOldIsDropped() {
        #expect(UncleanExitStatus.make(reopenedAt: now.addingTimeInterval(-UncleanExitStatus.shownFor), now: now) == nil)
    }

    /// The clock moved back after the launch: the record is still this week's.
    @Test func recordInTheFutureIsShown() {
        #expect(UncleanExitStatus.make(reopenedAt: now.addingTimeInterval(3_600), now: now) != nil)
    }

    // MARK: Fix for the current state

    @Test func pauseIsFixedByResume() {
        #expect(TroubleshootingFix(.paused(until: now)) == .resume)
    }

    @Test(arguments: [NextBreakState.noActiveSchedules, .noSchedules])
    func noRunningScheduleOpensSchedules(state: NextBreakState) {
        #expect(TroubleshootingFix(state) == .openSchedules)
    }

    @Test(arguments: [DeferralReason.cameraActive, .microphoneActive, .calendarEvent, .screenSharing])
    func detectionWaitOpensDetection(reason: DeferralReason) {
        #expect(TroubleshootingFix(.deferred(reason)) == .openDetection)
    }

    /// A postponed break was the user's choice, and a running or counting state needs no fix.
    @Test(arguments: [NextBreakState.deferred(.postponed), .breakActive, .countingDown(to: Date(timeIntervalSinceReferenceDate: 0))])
    func nothingToFix(state: NextBreakState) {
        #expect(TroubleshootingFix(state) == nil)
    }

    // MARK: Turn off Strict

    private func schedule(_ level: DisciplineLevel, enabled: Bool = true) -> Schedule {
        Schedule(name: "Work", isEnabled: enabled, days: .everyDay, windows: [],
                 breakInterval: 3600, breakDuration: 300, disciplineLevel: level)
    }

    @Test func strictBecomesFirmAndNothingElseChanges() {
        let schedules = [schedule(.strict), schedule(.gentle), schedule(.strict, enabled: false), schedule(.firm)]
        let lowered = schedules.strictLoweredToFirm()

        #expect(lowered.map(\.disciplineLevel) == [.firm, .gentle, .firm, .firm])
        #expect(lowered.map(\.id) == schedules.map(\.id))
        #expect(lowered.map(\.isEnabled) == schedules.map(\.isEnabled))
    }

    /// A schedule turned off now still brings Strict back when it is turned on.
    @Test func disabledStrictScheduleCounts() {
        #expect([schedule(.gentle), schedule(.strict, enabled: false)].containsStrict)
        #expect(![schedule(.gentle), schedule(.firm)].containsStrict)
    }
}

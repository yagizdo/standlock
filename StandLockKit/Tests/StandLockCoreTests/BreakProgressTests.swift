import Foundation
import Testing
@testable import StandLockCore

@Suite("Break Progress Calculation Tests")
struct BreakProgressTests {

    // MARK: - calculateBreakProgress

    @Test func breakActiveReturnsOne() {
        let result = calculateBreakProgress(
            scheduledAt: Date(), nextBreak: Date().addingTimeInterval(100),
            isBreakActive: true, now: Date()
        )
        #expect(result == 1.0)
    }

    @Test func nilDatesReturnZero() {
        #expect(calculateBreakProgress(scheduledAt: nil, nextBreak: nil, isBreakActive: false) == 0)
        #expect(calculateBreakProgress(scheduledAt: Date(), nextBreak: nil, isBreakActive: false) == 0)
        #expect(calculateBreakProgress(scheduledAt: nil, nextBreak: Date(), isBreakActive: false) == 0)
    }

    @Test func zeroTotalReturnZero() {
        let now = Date()
        let result = calculateBreakProgress(
            scheduledAt: now, nextBreak: now,
            isBreakActive: false, now: now
        )
        #expect(result == 0)
    }

    @Test func negativeTotalReturnsZero() {
        let now = Date()
        let result = calculateBreakProgress(
            scheduledAt: now, nextBreak: now.addingTimeInterval(-100),
            isBreakActive: false, now: now
        )
        #expect(result == 0)
    }

    @Test func midpointReturnsHalf() {
        let start = Date()
        let end = start.addingTimeInterval(100)
        let mid = start.addingTimeInterval(50)
        let result = calculateBreakProgress(
            scheduledAt: start, nextBreak: end,
            isBreakActive: false, now: mid
        )
        #expect(result == 0.5)
    }

    @Test func elapsedExceedsTotalClampsToOne() {
        let start = Date()
        let end = start.addingTimeInterval(100)
        let past = start.addingTimeInterval(200)
        let result = calculateBreakProgress(
            scheduledAt: start, nextBreak: end,
            isBreakActive: false, now: past
        )
        #expect(result == 1.0)
    }

    @Test func beforeStartClampsToZero() {
        let start = Date()
        let end = start.addingTimeInterval(100)
        let before = start.addingTimeInterval(-50)
        let result = calculateBreakProgress(
            scheduledAt: start, nextBreak: end,
            isBreakActive: false, now: before
        )
        #expect(result == 0)
    }

    // MARK: - ProgressDisplayBranch

    @Test func belowThresholdIsEmpty() {
        #expect(ProgressDisplayBranch(progress: 0) == .empty)
        #expect(ProgressDisplayBranch(progress: 0.005) == .empty)
        #expect(ProgressDisplayBranch(progress: 0.004) == .empty)
    }

    @Test func aboveThresholdIsFull() {
        #expect(ProgressDisplayBranch(progress: 1.0) == .full)
        #expect(ProgressDisplayBranch(progress: 0.995) == .full)
        #expect(ProgressDisplayBranch(progress: 0.999) == .full)
    }

    @Test func betweenThresholdsIsPartial() {
        #expect(ProgressDisplayBranch(progress: 0.5) == .partial)
        #expect(ProgressDisplayBranch(progress: 0.006) == .partial)
        #expect(ProgressDisplayBranch(progress: 0.994) == .partial)
    }

    @Test func negativeProgressClampsToEmpty() {
        #expect(ProgressDisplayBranch(progress: -1.0) == .empty)
    }

    @Test func overOneClampsToFull() {
        #expect(ProgressDisplayBranch(progress: 2.0) == .full)
    }

    // MARK: - formatMenuBarTimer

    @Test func timerHiddenWhenBreakActive() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 30, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: true, isPaused: false, hasScheduledBreak: true
        ) == nil)
    }

    @Test func timerHiddenWhenPaused() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 30, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: true, hasScheduledBreak: true
        ) == nil)
    }

    @Test func timerHiddenWhenNoSchedule() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 30, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: false
        ) == nil)
    }

    @Test func fullTimerShowsMinutes() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 1920, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "32m")
    }

    @Test func fullTimerShowsSecondsUnder60() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 45, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "0:45")
    }

    @Test func countdownHiddenAboveThreshold() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 120, showFullTimer: false, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == nil)
    }

    @Test func countdownVisibleWithinThreshold() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 45, showFullTimer: false, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "0:45")
    }

    @Test func countdownThreeMinutesShowsMinutes() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 150, showFullTimer: false, countdownMinutes: 3,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "3m")
    }

    @Test func minuteRoundsUp() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 90, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "2m")
    }

    @Test func exactMinuteBoundary() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 60, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "1m")
    }

    @Test func fractionalSecondsAboveMinuteNotRoundedUp() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 60.01, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "1m")
    }

    @Test func zeroSecondsFormatsCorrectly() {
        #expect(formatMenuBarTimer(
            secondsRemaining: 0, showFullTimer: true, countdownMinutes: 1,
            isBreakActive: false, isPaused: false, hasScheduledBreak: true
        ) == "0:00")
    }
}

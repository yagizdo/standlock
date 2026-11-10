import Foundation
import Testing
@testable import StandLockCore

@Suite("BreakHistory Tests")
struct BreakHistoryTests {

    private func makeRecord(
        _ dateKey: String,
        completed: Int = 0,
        skipped: Int = 0,
        escaped: Int = 0,
        duration: TimeInterval = 0,
        active: Bool = true
    ) -> DailyBreakRecord {
        DailyBreakRecord(
            dateKey: dateKey,
            breaksCompleted: completed,
            breaksSkipped: skipped,
            breaksEscaped: escaped,
            totalBreakDuration: duration,
            hadActiveSchedule: active
        )
    }

    private func date(_ key: String) -> Date {
        DailyBreakRecord.date(from: key)!
    }

    // MARK: - Storage

    @Test func upsertCreatesNewRecord() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 3))
        #expect(history.record(for: "2026-06-01")?.breaksCompleted == 3)
    }

    @Test func upsertUpdatesExistingRecord() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 2))
        history.upsert(makeRecord("2026-06-01", completed: 5))
        #expect(history.record(for: "2026-06-01")?.breaksCompleted == 5)
        #expect(history.records.count == 1)
    }

    @Test func recordsInRangeFiltersCorrectly() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-05-28", completed: 1))
        history.upsert(makeRecord("2026-05-29", completed: 2))
        history.upsert(makeRecord("2026-05-30", completed: 3))
        history.upsert(makeRecord("2026-06-01", completed: 4))

        let filtered = history.records(in: "2026-05-29"..."2026-05-30")
        #expect(filtered.count == 2)
        #expect(filtered[0].dateKey == "2026-05-29")
        #expect(filtered[1].dateKey == "2026-05-30")
    }

    @Test func pruneRemovesOldRecords() {
        var history = BreakHistory()
        history.upsert(makeRecord("2025-01-01", completed: 1))
        history.upsert(makeRecord("2026-05-30", completed: 2))
        history.upsert(makeRecord("2026-06-01", completed: 3))

        history.pruneOlderThan("2026-05-01")
        #expect(history.records.count == 2)
        #expect(history.record(for: "2025-01-01") == nil)
    }

    @Test func jsonRoundTrip() throws {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 3, skipped: 1, duration: 300))

        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(BreakHistory.self, from: data)

        #expect(decoded.records.count == 1)
        #expect(decoded.bestStreak == 1)
        let record = decoded.record(for: "2026-06-01")!
        #expect(record.breaksCompleted == 3)
        #expect(record.breaksSkipped == 1)
        #expect(record.totalBreakDuration == 300)
    }

    // MARK: - Aggregation

    @Test func aggregateTodayReturnsOnlyTodayStats() {
        var history = BreakHistory()
        let todayKey = DailyBreakRecord.dateKey(from: Date())
        history.upsert(makeRecord(todayKey, completed: 4, skipped: 1))
        history.upsert(makeRecord("2020-01-01", completed: 10))

        let stats = history.aggregateStats(for: .today)
        #expect(stats.totalCompleted == 4)
        #expect(stats.totalSkipped == 1)
    }

    @Test func aggregateWeekCoversCalendarWeekFromMonday() {
        var history = BreakHistory()
        let ref = date("2026-06-04") // Thursday

        for key in ["2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04"] {
            history.upsert(makeRecord(key, completed: 2, duration: 600))
        }
        // Sunday closing the previous week. Within the trailing 7 days, outside this week.
        history.upsert(makeRecord("2026-05-31", completed: 100))

        let stats = history.aggregateStats(for: .week, referenceDate: ref)
        #expect(stats.totalCompleted == 8)
        #expect(stats.totalBreakTime == 2400)
        #expect(stats.activeDays == 4)
    }

    @Test func aggregateMonthCoversCalendarMonth() {
        var history = BreakHistory()
        let ref = date("2026-06-15")

        history.upsert(makeRecord("2026-06-01", completed: 3))
        history.upsert(makeRecord("2026-06-15", completed: 4))
        // Within the trailing 30 days, outside the calendar month.
        history.upsert(makeRecord("2026-05-31", completed: 100))

        let stats = history.aggregateStats(for: .month, referenceDate: ref)
        #expect(stats.totalCompleted == 7)
        #expect(stats.activeDays == 2)
    }

    @Test func aggregateWeekOnSundayStillStartsOnMonday() {
        var history = BreakHistory()
        let ref = date("2026-06-07") // Sunday

        history.upsert(makeRecord("2026-06-01", completed: 1)) // Monday, first day of the week
        history.upsert(makeRecord("2026-06-07", completed: 1))
        history.upsert(makeRecord("2026-05-31", completed: 100)) // previous Sunday

        let stats = history.aggregateStats(for: .week, referenceDate: ref)
        #expect(stats.totalCompleted == 2)
        #expect(stats.activeDays == 2)
    }

    @Test func aggregateYearSums365Days() {
        var history = BreakHistory()
        let ref = date("2026-06-01")
        let calendar = Calendar.current

        for offset in 0..<365 {
            let day = calendar.date(byAdding: .day, value: -offset, to: ref)!
            let key = DailyBreakRecord.dateKey(from: day)
            history.upsert(makeRecord(key, completed: 1))
        }

        let stats = history.aggregateStats(for: .year, referenceDate: ref)
        #expect(stats.totalCompleted == 365)
        #expect(stats.activeDays == 365)
    }

    /// The card's numbers use the same window as the cards above it; days without a session add nothing.
    @Test func aggregateSumsPomodoroTalliesForThePeriod() {
        var history = BreakHistory()
        let ref = date("2026-06-04") // Thursday
        var monday = makeRecord("2026-06-01", completed: 1)
        monday.pomodoroTallies = PomodoroTallies(focusSeconds: 3000, rounds: 2, sessionsAbandoned: 1)
        var thursday = makeRecord("2026-06-04", completed: 4, active: false)
        thursday.pomodoroTallies = PomodoroTallies(focusSeconds: 6000, rounds: 4, sessionsFinished: 1)
        var lastWeek = makeRecord("2026-05-31", completed: 1)
        lastWeek.pomodoroTallies = PomodoroTallies(focusSeconds: 1500, rounds: 1)
        history.upsert(monday)
        history.upsert(makeRecord("2026-06-02", completed: 3))
        history.upsert(thursday)
        history.upsert(lastWeek)

        #expect(history.aggregateStats(for: .week, referenceDate: ref).pomodoro
                == PomodoroTallies(focusSeconds: 9000, rounds: 6, sessionsFinished: 1, sessionsAbandoned: 1))
        #expect(history.aggregateStats(for: .today, referenceDate: date("2026-06-02")).pomodoro.isEmpty)
        #expect(AggregateStats.empty.pomodoro.isEmpty)
    }

    @Test func completionRateCalculation() {
        var history = BreakHistory()
        let ref = date("2026-06-01")
        history.upsert(makeRecord("2026-06-01", completed: 3, skipped: 1, escaped: 1))

        let stats = history.aggregateStats(for: .today, referenceDate: ref)
        #expect(stats.completionRate == 3.0 / 5.0)
    }

    @Test func completionRateZeroWhenNoBreaks() {
        let history = BreakHistory()
        let stats = history.aggregateStats(for: .today)
        #expect(stats.completionRate == 0)
    }

    // MARK: - Streak

    @Test func currentStreakCountsConsecutiveDays() {
        var history = BreakHistory()
        let ref = date("2026-06-03")
        history.upsert(makeRecord("2026-06-03", completed: 2))
        history.upsert(makeRecord("2026-06-02", completed: 1))
        history.upsert(makeRecord("2026-06-01", completed: 3))

        #expect(history.currentStreak(referenceDate: ref) == 3)
    }

    @Test func streakSkipsInactiveDays() {
        var history = BreakHistory()
        let ref = date("2026-06-03")
        history.upsert(makeRecord("2026-06-03", completed: 1))
        history.upsert(makeRecord("2026-06-02", completed: 0, active: false))
        history.upsert(makeRecord("2026-06-01", completed: 2))

        #expect(history.currentStreak(referenceDate: ref) == 2)
    }

    @Test func streakBreaksOnZeroCompletedActiveDay() {
        var history = BreakHistory()
        let ref = date("2026-06-03")
        history.upsert(makeRecord("2026-06-03", completed: 1))
        history.upsert(makeRecord("2026-06-02", completed: 0, active: true))
        history.upsert(makeRecord("2026-06-01", completed: 5))

        #expect(history.currentStreak(referenceDate: ref) == 1)
    }

    // 2026-06-01 is a Monday.
    private let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    @Test func streakSkipsUnrecordedDaysNoScheduleCovers() {
        var history = BreakHistory()
        history.scheduledWeekdays = weekdays
        history.upsert(makeRecord("2026-06-04", completed: 1))
        history.upsert(makeRecord("2026-06-05", completed: 1))
        // Saturday and Sunday have no record: the app was quit, or no break was due.
        history.upsert(makeRecord("2026-06-08", completed: 1))

        #expect(history.currentStreak(referenceDate: date("2026-06-08")) == 3)
        #expect(history.bestStreak == 3)
    }

    @Test func streakStillBreaksOnUnrecordedScheduledDay() {
        var history = BreakHistory()
        history.scheduledWeekdays = weekdays
        history.upsert(makeRecord("2026-06-04", completed: 1))
        history.upsert(makeRecord("2026-06-08", completed: 1))

        #expect(history.currentStreak(referenceDate: date("2026-06-08")) == 1)
    }

    @Test func streakWalkStopsAtOldestRecordWhenNoDayIsScheduled() {
        var history = BreakHistory()
        history.scheduledWeekdays = []
        #expect(history.currentStreak(referenceDate: date("2026-06-08")) == 0)

        history.upsert(makeRecord("2026-06-01", completed: 1))
        history.upsert(makeRecord("2026-06-08", completed: 1))
        #expect(history.currentStreak(referenceDate: date("2026-06-08")) == 2)
    }

    /// A day with no schedule enabled and a completed (Pomodoro) break extends the streak.
    @Test func pomodoroOnlyDayExtendsStreak() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 1))
        history.upsert(makeRecord("2026-06-02", completed: 2, active: false))
        history.upsert(makeRecord("2026-06-03", completed: 1))
        #expect(history.currentStreak(referenceDate: date("2026-06-03")) == 3)
        #expect(history.bestStreak == 3)
    }

    /// Without a completed break such a day is skipped, as before: trying Pomodoro on a day off
    /// never ends a streak.
    @Test func pomodoroOnlyDayWithoutCompletedBreakKeepsStreak() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 1))
        history.upsert(makeRecord("2026-06-02", skipped: 2, active: false))
        #expect(history.currentStreak(referenceDate: date("2026-06-02")) == 1)
    }

    /// A session stopped in focus 1 writes tallies and no break. That record reads as no record:
    /// today stays in progress, and a past scheduled weekday still ends the streak.
    @Test func talliesOnlyRecordReadsAsMissing() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 1))
        history.upsert(makeRecord("2026-06-02", completed: 1))
        var today = makeRecord("2026-06-03")
        today.pomodoroTallies = PomodoroTallies(sessionsAbandoned: 1)
        history.upsert(today)
        #expect(history.currentStreak(referenceDate: date("2026-06-03")) == 2)
        #expect(history.currentStreak(referenceDate: date("2026-06-04")) == 0)
    }

    @Test func bestStreakUpdatesOnUpsert() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 1))
        history.upsert(makeRecord("2026-06-02", completed: 1))
        history.upsert(makeRecord("2026-06-03", completed: 1))
        #expect(history.bestStreak == 3)

        history.upsert(makeRecord("2026-06-04", completed: 0))
        #expect(history.bestStreak == 3)
    }

    @Test func streakHandlesYearBoundary() {
        var history = BreakHistory()
        let ref = date("2026-01-02")
        history.upsert(makeRecord("2026-01-02", completed: 1))
        history.upsert(makeRecord("2026-01-01", completed: 1))
        history.upsert(makeRecord("2025-12-31", completed: 1))
        history.upsert(makeRecord("2025-12-30", completed: 1))

        #expect(history.currentStreak(referenceDate: ref) == 4)
    }

    // MARK: - DailyBreakRecord

    @Test func dateKeyRoundTrip() {
        let ref = date("2026-06-01")
        let key = DailyBreakRecord.dateKey(from: ref)
        #expect(key == "2026-06-01")
        let parsed = DailyBreakRecord.date(from: key)
        #expect(parsed != nil)
        #expect(DailyBreakRecord.dateKey(from: parsed!) == "2026-06-01")
    }

    @Test func recordIdentifiable() {
        let record = makeRecord("2026-06-01", completed: 3)
        #expect(record.id == "2026-06-01")
    }

    @Test func recordTotalBreaks() {
        let record = makeRecord("2026-06-01", completed: 3, skipped: 2, escaped: 1)
        #expect(record.totalBreaks == 6)
    }

    // MARK: - Pomodoro tallies

    /// `breakHistory` exactly as v0.12.0 writes it: one decode failure would empty the history
    /// and the next save would overwrite it.
    @Test func dailyRecordFromV0120DecodesWithNilPomodoro() throws {
        let json = #"""
        {"records":{"2026-06-01":{"dateKey":"2026-06-01","breaksCompleted":3,"breaksSkipped":1,\#
        "breaksEscaped":0,"totalBreakDuration":900,"hadActiveSchedule":true}},"bestStreak":4}
        """#
        let history = try JSONDecoder().decode(BreakHistory.self, from: Data(json.utf8))
        let record = try #require(history.record(for: "2026-06-01"))
        #expect(record.breaksCompleted == 3)
        #expect(record.totalBreakDuration == TimeInterval(900))
        #expect(record.pomodoroTallies == nil)
        #expect(history.bestStreak == 4)
    }

    @Test func statisticsFromV0120DecodesWithNilPomodoro() throws {
        let json = #"""
        {"date":800000000,"breaksCompleted":2,"breaksSkipped":1,"breaksEscaped":0,"breaksDeferred":1,\#
        "currentStreak":2,"weeklyEscapeCount":0,"weekStartDate":799900000}
        """#
        let stats = try JSONDecoder().decode(BreakStatistics.self, from: Data(json.utf8))
        #expect(stats.breaksCompleted == 2)
        #expect(stats.currentStreak == 2)
        #expect(stats.pomodoroTallies == nil)
    }

    @Test func pomodoroTalliesRoundTrip() throws {
        let tallies = PomodoroTallies(focusSeconds: 3000, rounds: 2, sessionsFinished: 1, sessionsAbandoned: 1)
        var record = makeRecord("2026-06-01", completed: 2)
        record.pomodoroTallies = tallies
        var stats = BreakStatistics()
        stats.pomodoroTallies = tallies

        let decodedRecord = try JSONDecoder().decode(DailyBreakRecord.self, from: JSONEncoder().encode(record))
        let decodedStats = try JSONDecoder().decode(BreakStatistics.self, from: JSONEncoder().encode(stats))
        #expect(decodedRecord.pomodoroTallies == tallies)
        #expect(decodedStats.pomodoroTallies == tallies)
    }

    // MARK: - Recording a day

    private func stats(completed: Int = 0, skipped: Int = 0, tallies: PomodoroTallies? = nil) -> BreakStatistics {
        var stats = BreakStatistics()
        stats.breaksCompleted = completed
        stats.breaksSkipped = skipped
        stats.pomodoroTallies = tallies
        return stats
    }

    @Test func recordDayCopiesCountersAndTallies() {
        var history = BreakHistory()
        let tallies = PomodoroTallies(focusSeconds: 1500, rounds: 1)
        let wrote = history.recordDay(stats(completed: 2, skipped: 1, tallies: tallies), on: "2026-06-01",
                                      hasActiveSchedule: true, averageBreakDuration: 300)
        #expect(wrote)
        let record = history.record(for: "2026-06-01")
        #expect(record?.breaksCompleted == 2)
        #expect(record?.breaksSkipped == 1)
        #expect(record?.totalBreakDuration == TimeInterval(600))
        #expect(record?.pomodoroTallies == tallies)
    }

    @Test func recordDaySkipsZeroedCounters() {
        var history = BreakHistory()
        let zeroed = history.recordDay(stats(), on: "2026-06-01", hasActiveSchedule: true, averageBreakDuration: 300)
        let emptyTallies = history.recordDay(stats(tallies: PomodoroTallies()), on: "2026-06-01",
                                             hasActiveSchedule: true, averageBreakDuration: 300)
        #expect(!zeroed)
        #expect(!emptyTallies)
        #expect(history.records.isEmpty)
    }

    /// A session stopped in focus 1 has no break but still reaches the day's record.
    @Test func recordDayAcceptsTalliesWithoutBreaks() {
        var history = BreakHistory()
        let tallies = PomodoroTallies(sessionsAbandoned: 1)
        let wrote = history.recordDay(stats(tallies: tallies), on: "2026-06-01",
                                      hasActiveSchedule: false, averageBreakDuration: 300)
        #expect(wrote)
        #expect(history.record(for: "2026-06-01")?.pomodoroTallies == tallies)
    }

    /// Schedule breaks in the morning, then a Pomodoro break with every schedule off: the day
    /// keeps its scheduled credit (the step 4 run saw the streak drop 19 to 18).
    @Test func recordDayKeepsEarlierScheduledFlag() {
        var history = BreakHistory()
        history.recordDay(stats(completed: 1), on: "2026-06-01", hasActiveSchedule: true, averageBreakDuration: 300)
        history.recordDay(stats(completed: 2), on: "2026-06-01", hasActiveSchedule: false, averageBreakDuration: 300)
        #expect(history.record(for: "2026-06-01")?.hadActiveSchedule == true)
    }

    /// Its focus phases were tallied live that day; only the abandon is new.
    @Test func staleSessionIsRecordedOnItsOwnDay() {
        var history = BreakHistory()
        history.upsert(DailyBreakRecord(dateKey: "2026-06-01", breaksCompleted: 1,
                                        pomodoroTallies: PomodoroTallies(focusSeconds: 1500, rounds: 1)))
        var session = PomodoroSession.start(at: date("2026-06-01").addingTimeInterval(9 * 3600), configuration: .standard)
        session = session.next(at: session.phaseEnd)!

        let recorded = history.recordingAbandoned(session)
        #expect(recorded.record(for: "2026-06-01")?.pomodoroTallies
                == PomodoroTallies(focusSeconds: 1500, rounds: 1, sessionsAbandoned: 1))
        #expect(recorded.record(for: "2026-06-01")?.breaksCompleted == 1)
        #expect(recorded.records.count == 1)

        let fresh = BreakHistory().recordingAbandoned(session)
        #expect(fresh.record(for: "2026-06-01")?.pomodoroTallies == PomodoroTallies(sessionsAbandoned: 1))
    }

    /// Review M1: a session quit in focus 1 on a scheduled weekday with no break, dropped at the
    /// next launch, must not turn that missed day into a skipped one.
    @Test func staleSessionDoesNotKeepStreakAcrossScheduledDay() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-07", completed: 1))
        let session = PomodoroSession.start(at: date("2026-06-08").addingTimeInterval(9 * 3600), configuration: .standard)
        let recorded = history.recordingAbandoned(session)
        #expect(recorded.currentStreak(referenceDate: date("2026-06-09")) == 0)
        #expect(history.currentStreak(referenceDate: date("2026-06-09")) == 0)
    }

    /// Review M2: after the day moves back onto a recorded day, a focus end or Stop (tallies, no
    /// break) must not blank that day's break counts.
    @Test func recordDayTalliesOnlyKeepsBreakCounts() {
        var history = BreakHistory()
        history.upsert(makeRecord("2026-06-01", completed: 6, skipped: 1, duration: 1800))
        let tallies = PomodoroTallies(focusSeconds: 1500, rounds: 1)
        history.recordDay(stats(tallies: tallies), on: "2026-06-01", hasActiveSchedule: true, averageBreakDuration: 300)
        let record = history.record(for: "2026-06-01")
        #expect(record?.breaksCompleted == 6)
        #expect(record?.breaksSkipped == 1)
        #expect(record?.totalBreakDuration == TimeInterval(1800))
        #expect(record?.pomodoroTallies == tallies)
    }

    @Test func rolloverClearsPomodoroTallies() {
        let today = date("2026-06-01")
        var stats = BreakStatistics(date: today)
        stats.pomodoroTallies = PomodoroTallies(focusSeconds: 1500, rounds: 1)
        let rolled = stats.resetDailyIfNeeded(currentDate: date("2026-06-02"))
        #expect(rolled)
        #expect(stats.pomodoroTallies == nil)
    }
}

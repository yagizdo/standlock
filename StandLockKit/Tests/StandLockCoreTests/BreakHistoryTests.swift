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

    @Test func aggregateWeekSumsLast7Days() {
        var history = BreakHistory()
        let ref = date("2026-06-01")
        let calendar = Calendar.current

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -offset, to: ref)!
            let key = DailyBreakRecord.dateKey(from: day)
            history.upsert(makeRecord(key, completed: 2, duration: 600))
        }
        let outside = calendar.date(byAdding: .day, value: -7, to: ref)!
        history.upsert(makeRecord(DailyBreakRecord.dateKey(from: outside), completed: 100))

        let stats = history.aggregateStats(for: .week, referenceDate: ref)
        #expect(stats.totalCompleted == 14)
        #expect(stats.totalBreakTime == 4200)
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
}

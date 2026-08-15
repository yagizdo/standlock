import Foundation

public enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    public var id: Self { self }
}

public struct AggregateStats: Equatable, Sendable {
    public let totalCompleted: Int
    public let totalSkipped: Int
    public let totalEscaped: Int
    public let completionRate: Double
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalBreakTime: TimeInterval
    public let activeDays: Int

    public static let empty = AggregateStats(
        totalCompleted: 0, totalSkipped: 0, totalEscaped: 0,
        completionRate: 0, currentStreak: 0, bestStreak: 0,
        totalBreakTime: 0, activeDays: 0
    )
}

public struct BreakHistory: Codable, Sendable {
    public var records: [String: DailyBreakRecord]
    public var bestStreak: Int
    public private(set) var revision: Int = 0

    private enum CodingKeys: String, CodingKey {
        case records, bestStreak
    }

    public init() {
        records = [:]
        bestStreak = 0
    }

    public func record(for dateKey: String) -> DailyBreakRecord? {
        records[dateKey]
    }

    public func records(in range: ClosedRange<String>) -> [DailyBreakRecord] {
        records.values
            .filter { range.contains($0.dateKey) }
            .sorted { $0.dateKey < $1.dateKey }
    }

    public mutating func upsert(_ record: DailyBreakRecord) {
        records[record.dateKey] = record
        let streak = currentStreak(referenceDate: DailyBreakRecord.date(from: record.dateKey) ?? Date())
        if streak > bestStreak {
            bestStreak = streak
        }
        revision += 1
    }

    /// Returns `true` when records were actually dropped, so the caller can skip a pointless save.
    @discardableResult
    public mutating func pruneOlderThan(_ dateKey: String) -> Bool {
        let before = records.count
        records = records.filter { $0.key >= dateKey }
        guard records.count != before else { return false }
        revision += 1
        return true
    }

    // MARK: - Streak

    public func currentStreak(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var dayOffset = 0

        while true {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else { break }
            let key = DailyBreakRecord.dateKey(from: day)

            if let record = records[key] {
                if !record.hadActiveSchedule {
                    dayOffset += 1
                    continue
                }
                if record.breaksCompleted >= 1 {
                    streak += 1
                    dayOffset += 1
                    continue
                }
                break
            } else {
                if dayOffset == 0 {
                    dayOffset += 1
                    continue
                }
                break
            }
        }
        return streak
    }

    // MARK: - Aggregation

    /// Start of the window a period covers. Week and month are calendar aligned so the totals
    /// match the Monday-Sunday and calendar-month grids the statistics panel draws; year stays
    /// a rolling window because the heatmap is one too.
    private func windowStart(for period: StatsPeriod, referenceDate: Date, calendar: Calendar) -> Date {
        switch period {
        case .today:
            return referenceDate
        case .week:
            let daysFromMonday = (calendar.component(.weekday, from: referenceDate) + 5) % 7
            return calendar.date(byAdding: .day, value: -daysFromMonday, to: referenceDate) ?? referenceDate
        case .month:
            let components = calendar.dateComponents([.year, .month], from: referenceDate)
            return calendar.date(from: components) ?? referenceDate
        case .year:
            return calendar.date(byAdding: .day, value: -364, to: referenceDate) ?? referenceDate
        }
    }

    public func aggregateStats(for period: StatsPeriod, referenceDate: Date = Date()) -> AggregateStats {
        let calendar = Calendar.current
        let startDate = windowStart(for: period, referenceDate: referenceDate, calendar: calendar)
        let startKey = DailyBreakRecord.dateKey(from: startDate)
        let endKey = DailyBreakRecord.dateKey(from: referenceDate)
        let filtered = records(in: startKey...endKey)

        var totalCompleted = 0
        var totalSkipped = 0
        var totalEscaped = 0
        var totalBreakTime: TimeInterval = 0
        var activeDays = 0

        for record in filtered {
            totalCompleted += record.breaksCompleted
            totalSkipped += record.breaksSkipped
            totalEscaped += record.breaksEscaped
            totalBreakTime += record.totalBreakDuration
            if record.totalBreaks > 0 { activeDays += 1 }
        }

        let total = totalCompleted + totalSkipped + totalEscaped
        let completionRate = total > 0 ? Double(totalCompleted) / Double(total) : 0

        let streak = currentStreak(referenceDate: referenceDate)

        return AggregateStats(
            totalCompleted: totalCompleted,
            totalSkipped: totalSkipped,
            totalEscaped: totalEscaped,
            completionRate: completionRate,
            currentStreak: streak,
            bestStreak: bestStreak,
            totalBreakTime: totalBreakTime,
            activeDays: activeDays
        )
    }
}

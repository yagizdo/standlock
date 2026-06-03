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
    }

    public mutating func pruneOlderThan(_ dateKey: String) {
        records = records.filter { $0.key >= dateKey }
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

    public func aggregateStats(for period: StatsPeriod, referenceDate: Date = Date()) -> AggregateStats {
        let calendar = Calendar.current
        let daysBack: Int
        switch period {
        case .today: daysBack = 0
        case .week: daysBack = 6
        case .month: daysBack = 29
        case .year: daysBack = 364
        }

        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: referenceDate)!
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

import SwiftUI
import StandLockCore

struct StatisticsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedPeriod: StatsPeriod = .month
    @State private var cachedHeatmap: HeatmapData?
    @State private var cachedStats: AggregateStats = .empty

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerRow
                metricsGrid
                Group {
                    switch selectedPeriod {
                    case .today:
                        EmptyView()
                    case .week:
                        WeekCardsView(history: coordinator.breakHistory,
                                      activeDays: cachedStats.activeDays)
                    case .month:
                        MonthCalendarView(history: coordinator.breakHistory,
                                          activeDays: cachedStats.activeDays)
                    case .year:
                        if let heatmap = cachedHeatmap {
                            YearHeatmapView(data: heatmap,
                                            activeDays: cachedStats.activeDays)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { rebuildCache() }
        .onChange(of: coordinator.breakHistory.records.count) { _ in rebuildCache() }
        .onChange(of: selectedPeriod) { _ in
            cachedStats = coordinator.breakHistory.aggregateStats(for: selectedPeriod)
        }
    }

    private func rebuildCache() {
        cachedHeatmap = HeatmapData(history: coordinator.breakHistory, referenceDate: Date())
        cachedStats = coordinator.breakHistory.aggregateStats(for: selectedPeriod)
    }

    private var headerRow: some View {
        HStack {
            Text("Break Statistics")
                .font(.headline)
            Spacer()
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatsPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    private var metricsGrid: some View {
        let s = cachedStats
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            StatCard(icon: "checkmark.circle", label: "Completed", value: "\(s.totalCompleted)", color: .green)
            StatCard(icon: "forward.end", label: "Skipped", value: "\(s.totalSkipped)", color: .orange)
            StatCard(icon: "chart.bar", label: "Completion", value: "\(Int(s.completionRate * 100))%", color: .blue)
            StatCard(icon: "flame", label: "Streak", value: "\(s.currentStreak)d", color: .red)
            StatCard(icon: "trophy", label: "Best Streak", value: "\(s.bestStreak)d", color: .purple)
            StatCard(icon: "clock", label: "Break Time", value: formattedTime(s.totalBreakTime), color: .cyan)
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Heatmap Color

private func heatmapColor(count: Int, maxCount: Int) -> Color {
    guard maxCount > 0, count > 0 else {
        return Color(.systemGray).opacity(0.15)
    }
    let ratio = Double(count) / Double(maxCount)
    switch ratio {
    case ..<0.25: return .green.opacity(0.3)
    case ..<0.50: return .green.opacity(0.5)
    case ..<0.75: return .green.opacity(0.7)
    default:      return .green.opacity(1.0)
    }
}

// MARK: - Year Heatmap View

private struct YearHeatmapView: View {
    let data: HeatmapData
    let activeDays: Int

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let labelWidth: CGFloat = 28

    private var gridWidth: CGFloat {
        CGFloat(data.weeks.count) * (cellSize + cellSpacing) - cellSpacing
    }

    private var gridHeight: CGFloat {
        7 * (cellSize + cellSpacing) - cellSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Break Activity").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(activeDays) days with breaks")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        monthLabelsRow
                        HStack(alignment: .top, spacing: 0) {
                            dayLabelsColumn
                            canvas
                            Color.clear.frame(width: 1, height: 1).id("heatmap-end")
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo("heatmap-end", anchor: .trailing)
                }
            }

            legendRow
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var canvas: some View {
        Canvas { context, _ in
            for col in 0..<data.weeks.count {
                for row in 0..<7 {
                    let x = CGFloat(col) * (cellSize + cellSpacing)
                    let y = CGFloat(row) * (cellSize + cellSpacing)
                    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                    let path = Path(roundedRect: rect, cornerRadius: 2)

                    if let day = data.weeks[col][row] {
                        let color = heatmapColor(count: day.breakCount, maxCount: data.maxCount)
                        context.fill(path, with: .color(color))
                    }
                }
            }
        }
        .frame(width: gridWidth, height: gridHeight)
    }

    private var monthLabelsRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth, height: 12)
            ForEach(0..<data.weeks.count, id: \.self) { col in
                if let label = data.monthLabels[col] {
                    Text(label)
                        .font(.caption2)
                        .fixedSize()
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize + cellSpacing, alignment: .leading)
                } else {
                    Color.clear.frame(width: cellSize + cellSpacing, height: 12)
                }
            }
        }
    }

    private var dayLabelsColumn: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { row in
                if row == 0 || row == 2 || row == 4 {
                    Text(["Mon", "", "Wed", "", "Fri", "", ""][row])
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                        .frame(width: labelWidth, height: cellSize, alignment: .trailing)
                } else {
                    Color.clear.frame(width: labelWidth, height: cellSize)
                }
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 3) {
            Spacer()
            Text("Less").font(.system(size: 10)).foregroundStyle(.secondary)
            ForEach([0.15, 0.3, 0.5, 0.7, 1.0], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(opacity == 0.15 ? Color(.systemGray).opacity(0.15) : .green.opacity(opacity))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Month Calendar View

private struct MonthCalendarView: View {
    let history: BreakHistory
    let activeDays: Int

    private static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: components)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday + 5) % 7
        let todayKey = DailyBreakRecord.dateKey(from: now)
        let maxCount = maxBreakCount(calendar: calendar, monthStart: monthStart, daysInMonth: daysInMonth)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(monthYearString(from: now)).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(activeDays) days with breaks")
                    .font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Self.dayNames, id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<offset, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
                    let key = DailyBreakRecord.dateKey(from: date)
                    let count = history.record(for: key)?.breaksCompleted ?? 0
                    let isToday = key == todayKey

                    VStack(spacing: 2) {
                        Text("\(day)").font(.caption)
                        if count > 0 {
                            Text("\(count)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(heatmapColor(count: count, maxCount: maxCount))
                    )
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func maxBreakCount(calendar: Calendar, monthStart: Date, daysInMonth: Int) -> Int {
        var result = 0
        for day in 0..<daysInMonth {
            let date = calendar.date(byAdding: .day, value: day, to: monthStart)!
            let count = history.record(for: DailyBreakRecord.dateKey(from: date))?.breaksCompleted ?? 0
            if count > result { result = count }
        }
        return result
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Week Calendar View

private struct WeekCardsView: View {
    let history: BreakHistory
    let activeDays: Int

    private static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (todayWeekday - 2 + 7) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday,
                                   to: calendar.startOfDay(for: now))!
        let todayKey = DailyBreakRecord.dateKey(from: now)

        let weekDates: [(day: Int, key: String, count: Int)] = (0..<7).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: monday)!
            let key = DailyBreakRecord.dateKey(from: date)
            let count = history.record(for: key)?.breaksCompleted ?? 0
            return (day: calendar.component(.day, from: date), key: key, count: count)
        }
        let maxCount = weekDates.map(\.count).max() ?? 0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This Week").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(activeDays) days with breaks")
                    .font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Self.dayNames, id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<7, id: \.self) { i in
                    let entry = weekDates[i]
                    let isToday = entry.key == todayKey

                    VStack(spacing: 2) {
                        Text("\(entry.day)").font(.caption)
                        if entry.count > 0 {
                            Text("\(entry.count)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(heatmapColor(count: entry.count, maxCount: maxCount))
                    )
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Heatmap Data

private struct HeatmapData {
    struct HeatmapDay {
        let dateKey: String
        let breakCount: Int
    }

    let weeks: [[HeatmapDay?]]
    let monthLabels: [Int: String]
    let activeDaysCount: Int
    let maxCount: Int

    init(history: BreakHistory, referenceDate: Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        var weeksArray: [[HeatmapDay?]] = Array(repeating: Array(repeating: nil, count: 7), count: 53)
        var labels: [Int: String] = [:]
        var activeCount = 0
        var maxBreaks = 0
        var lastMonth = -1
        var lastLabelCol = -10

        for dayOffset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -(364 - dayOffset), to: referenceDate) else { continue }
            let key = DailyBreakRecord.dateKey(from: day)
            let weekday = calendar.component(.weekday, from: day)
            let row = (weekday + 5) % 7
            let col = dayOffset / 7

            let breakCount = history.record(for: key)?.breaksCompleted ?? 0
            if breakCount > 0 { activeCount += 1 }
            if breakCount > maxBreaks { maxBreaks = breakCount }

            weeksArray[col][row] = HeatmapDay(dateKey: key, breakCount: breakCount)

            let month = calendar.component(.month, from: day)
            if month != lastMonth {
                lastMonth = month
                if col - lastLabelCol >= 3 {
                    labels[col] = calendar.shortMonthSymbols[month - 1]
                    lastLabelCol = col
                }
            }
        }

        weeks = weeksArray
        monthLabels = labels
        activeDaysCount = activeCount
        self.maxCount = maxBreaks
    }
}

import Foundation

public protocol SchedulingEngine: Sendable {
    func nextBreakTime(for schedule: Schedule, after date: Date) -> Date?
    func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval
    func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool
}

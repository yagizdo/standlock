import Foundation

/// Per-schedule counters that have to outlive a coordinator rebuild. Editing a schedule tears
/// the coordinator down and builds a new one, and every counter here lives on the instance: a
/// fresh one re-arms `dailyBreakCap` from zero, sends `intervalCycle` back to its first entry,
/// drops progressive enforcement to the base tier and forgets how far into the short-break run
/// the user was. Daily counters roll over separately from consecutive-dismissal streaks.
/// Codable state survives a quit; process-local timing is carried only across rebuilds.
public struct EnforcementState: Codable, Sendable {
    public var dailyBreakCounts: [UUID: Int]
    public var escalationTiers: [UUID: Int]
    public var cycleIndices: [UUID: Int]
    public var repetitionIndices: [UUID: Int]
    /// Slots the outgoing coordinator was counting down to, by schedule. The interval is
    /// measured from whenever the rebuilt coordinator starts, so without this any restart -- a
    /// schedule edit, a Strict permission reading that flaps -- pushes the break out by however
    /// far into the interval the user already was. Keyed by schedule because the slot decides
    /// which break fires, and because a disabled schedule's slot has to wait out the rebuilds
    /// that exclude it: switching a schedule off and on again must not buy a fresh interval.
    public var pendingBreakDates: [UUID: Date]
    /// The schedule whose break was postponed and is still owed. Carried across a rebuild so a
    /// schedule edit during the wait cannot drop the break, but left out of `CodingKeys`: a
    /// postponed break does not survive a quit.
    public var postponedScheduleID: UUID?
    public var consecutiveDismissalCounts: [UUID: Int]
    var runtime: CoordinatorRuntimeState?

    private enum CodingKeys: String, CodingKey {
        case dailyBreakCounts, escalationTiers, cycleIndices, repetitionIndices, pendingBreakDates, consecutiveDismissalCounts
    }

    public init(dailyBreakCounts: [UUID: Int] = [:], escalationTiers: [UUID: Int] = [:],
                cycleIndices: [UUID: Int] = [:], repetitionIndices: [UUID: Int] = [:],
                pendingBreakDates: [UUID: Date] = [:], postponedScheduleID: UUID? = nil,
                consecutiveDismissalCounts: [UUID: Int] = [:]) {
        self.dailyBreakCounts = dailyBreakCounts
        self.escalationTiers = escalationTiers
        self.cycleIndices = cycleIndices
        self.repetitionIndices = repetitionIndices
        self.pendingBreakDates = pendingBreakDates
        self.postponedScheduleID = postponedScheduleID
        self.consecutiveDismissalCounts = consecutiveDismissalCounts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyBreakCounts = try c.decodeIfPresent([UUID: Int].self, forKey: .dailyBreakCounts) ?? [:]
        escalationTiers = try c.decodeIfPresent([UUID: Int].self, forKey: .escalationTiers) ?? [:]
        cycleIndices = try c.decodeIfPresent([UUID: Int].self, forKey: .cycleIndices) ?? [:]
        repetitionIndices = try c.decodeIfPresent([UUID: Int].self, forKey: .repetitionIndices) ?? [:]
        pendingBreakDates = try c.decodeIfPresent([UUID: Date].self, forKey: .pendingBreakDates) ?? [:]
        consecutiveDismissalCounts = try c.decodeIfPresent([UUID: Int].self, forKey: .consecutiveDismissalCounts) ?? [:]
    }

    /// Lifetime streaks and observed in-process absences are independent of the calendar day.
    public mutating func resetDailyCounters() {
        dailyBreakCounts = [:]
        escalationTiers = [:]
        cycleIndices = [:]
        repetitionIndices = [:]
        pendingBreakDates = [:]
    }
}

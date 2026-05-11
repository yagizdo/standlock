import Foundation

public struct BreakEvent: Sendable, Identifiable {
    public let id: UUID
    public let scheduledAt: Date
    public let duration: TimeInterval
    public let level: DisciplineLevel
    public let scheduleId: UUID
    public var outcome: BreakOutcome

    public init(
        id: UUID = UUID(), scheduledAt: Date, duration: TimeInterval,
        level: DisciplineLevel, scheduleId: UUID,
        outcome: BreakOutcome = .pending
    ) {
        self.id = id; self.scheduledAt = scheduledAt; self.duration = duration
        self.level = level; self.scheduleId = scheduleId; self.outcome = outcome
    }
}

public enum BreakOutcome: Sendable {
    case pending
    case completed
    case skipped
    case escaped
    case deferred(reason: DeferralReason)
    case idleCounted
}

public enum DeferralReason: String, Sendable, Codable {
    case cameraActive
    case microphoneActive
    case calendarEvent
    case screenSharing
    case focusMode
}

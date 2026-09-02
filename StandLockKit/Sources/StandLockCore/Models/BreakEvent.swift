import Foundation

public struct BreakEvent: Sendable, Identifiable {
    public let id: UUID
    public let scheduledAt: Date
    public let duration: TimeInterval
    public let level: DisciplineLevel
    public let scheduleId: UUID

    public init(
        id: UUID = UUID(), scheduledAt: Date, duration: TimeInterval,
        level: DisciplineLevel, scheduleId: UUID
    ) {
        self.id = id; self.scheduledAt = scheduledAt; self.duration = duration
        self.level = level; self.scheduleId = scheduleId
    }
}

public enum DeferralReason: String, Sendable, Codable {
    case cameraActive
    case microphoneActive
    case calendarEvent
    case screenSharing

    public var displayName: String {
        switch self {
        case .cameraActive: "Camera in use"
        case .microphoneActive: "Microphone in use"
        case .calendarEvent: "Calendar event active"
        case .screenSharing: "Screen sharing active"
        }
    }
}

import Foundation
import StandLockCore

/// Process-local state carried across settings rebuilds, deliberately excluded from JSON.
struct CoordinatorRuntimeState: Sendable {
    var awayTracker: AwaySessionTracker
    var remainingWork: [UUID: TimeInterval]
    var awayOwnerID: UUID?
    var activeBreak: BreakEvent?
    var activeScheduleID: UUID?
    var activeDeadline: TimeInterval?
    var exercise: Exercise?
    var canPostpone: Bool
    var postponedBreak: BreakEvent?
    var pauseDeadline: Date?
    var deferredScheduleID: UUID?
}

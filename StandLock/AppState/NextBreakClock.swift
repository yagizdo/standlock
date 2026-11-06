import Combine
import Foundation
import StandLockCore

/// What the Settings footer watches instead of the coordinator, which publishes every second
/// before a break while this state only changes when a break moves, starts, waits or pauses.
@MainActor
final class NextBreakClock: ObservableObject {
    @Published private(set) var state: NextBreakState

    init(coordinator: AppCoordinator) {
        state = coordinator.nextBreakState
        coordinator.objectWillChange
            // It fires before the write, and one coordinator event writes several values: the
            // hop reads them all after the event.
            .receive(on: DispatchQueue.main)
            .map { coordinator.nextBreakState }
            .removeDuplicates()
            .assign(to: &$state)
    }
}

extension AppCoordinator {
    var nextBreakState: NextBreakState {
        NextBreakState(
            isBreakActive: isBreakActive,
            isPaused: isPaused,
            pausedUntil: pausedUntil,
            deferralReason: deferralReason,
            nextBreakTime: nextBreakTime,
            hasSchedules: !schedules.isEmpty
        )
    }
}

import SwiftUI
import StandLockCore

/// Starts a Pomodoro session, or stops it and skips its phase. One pill tall in both states,
/// so the panel keeps its height.
struct PomodoroRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 5) {
            if coordinator.pomodoroStatus == nil {
                Button {
                    coordinator.startPomodoro()
                } label: {
                    MenuBarPillLabel("Start Pomodoro", symbol: "timer")
                }
                .buttonStyle(MenuBarPillStyle())
            } else {
                Button {
                    coordinator.stopPomodoro()
                } label: {
                    MenuBarPillLabel("Stop", symbol: "stop.fill")
                }
                .buttonStyle(MenuBarPillStyle())

                Button {
                    coordinator.skipPomodoroPhase()
                } label: {
                    MenuBarPillLabel("Skip phase", symbol: "forward.frame")
                }
                .buttonStyle(MenuBarPillStyle())
            }
        }
        // Kit refuses all three while a break is on screen; the overlay's own exits apply there.
        .disabled(coordinator.isBreakActive)
    }
}

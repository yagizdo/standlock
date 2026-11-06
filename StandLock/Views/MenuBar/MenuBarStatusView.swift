import SwiftUI
import StandLockCore

/// The scene and the status row. One timeline drives the motion, the countdown and the change to
/// the last minute, because the coordinator only publishes every 10 s before that minute.
struct MenuBarStatusView: View {
    let state: NextBreakState
    let progress: Double
    let scene: MenuScene
    let schedule: Schedule?

    @EnvironmentObject private var checker: PermissionChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The first open creates this view. A timeline keeps ticking in a closed panel, so this stops
    /// it. Occlusion, not key: the panel stays up without key while the update window is open.
    @State private var isOpen = true

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion || scene == .off ? 1 : 1.0 / 12, paused: !isOpen)) { context in
            let look = MenuSceneLook(state: state, now: context.date)
            VStack(alignment: .leading, spacing: 10) {
                if scene != .off {
                    MenuSceneCard(scene: scene, look: look, progress: progress, date: context.date, isMoving: !reduceMotion)
                }
                statusRow(look: look, now: context.date)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { note in
            guard let window = note.object as? NSWindow, window.isMenuBarPanel else { return }
            isOpen = window.occlusionState.contains(.visible)
        }
    }

    private func statusRow(look: MenuSceneLook, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(look))
                        .font(.system(size: 16, weight: .semibold))
                    subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                trailing(now: now)
            }
            // The panel names the level with nothing else around it, so an unqualified "Strict"
            // is the one place the downgrade could pass for the real thing. Its own line, at full
            // width: beside the countdown it would wrap and change the panel's height. Hidden, not
            // removed, when Strict is active, so the panel is the same height either way.
            if schedule.map(checker.strictIsInactive) == true {
                strictWarning
            } else {
                strictWarning.hidden()
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var strictWarning: some View {
        Text("Strict inactive, running as Firm")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private func title(_ look: MenuSceneLook) -> LocalizedStringKey {
        switch look {
        case .working: "Working"
        case .breakSoon: "Break soon"
        case .timeToStand: "Time to stand"
        case .paused: "Paused"
        case .breakWaiting: "Break waiting"
        case .noSchedules: state == .noSchedules ? "No schedules configured" : "No active schedules"
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if case .deferred(let reason) = state {
            Text(LocalizedStringKey(reason.displayName))
        } else if let schedule {
            HStack(spacing: 4) {
                Text(schedule.name)
                    .lineLimit(1)
                Text(verbatim: "·")
                Text(LocalizedStringKey(schedule.disciplineLevel.displayName))
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private func trailing(now: Date) -> some View {
        switch state {
        case .countingDown(let nextBreak):
            trailingColumn(label: "Next break") {
                Text(formatCountdown(secondsRemaining: breakSecondsRemaining(until: nextBreak, now: now)))
            }
        case .paused(let until):
            trailingColumn(label: "Resumes") {
                Text(until, style: .time)
            }
        case .breakActive, .deferred, .noSchedules, .noActiveSchedules:
            // Holds the row's height with no width, so the panel does not jump between looks.
            trailingColumn(label: "Next break") {
                Text(verbatim: "0:00")
            }
            .frame(width: 0)
            .hidden()
        }
    }

    private func trailingColumn<Value: View>(label: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            value()
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

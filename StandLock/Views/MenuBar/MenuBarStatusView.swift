import SwiftUI
import StandLockCore

/// The scene and the status row. One clock drives the motion, the countdown and the change to
/// the last minute, because the coordinator only publishes every 10 s before that minute.
struct MenuBarStatusView: View {
    let state: NextBreakState
    let progress: Double
    let scene: MenuScene
    let schedule: Schedule?
    let pomodoro: PomodoroStatus?

    @EnvironmentObject private var checker: PermissionChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The first open creates this view. The clock would keep ticking in a closed panel, so this
    /// stops it. Occlusion, not key: the panel stays up without key while the update window is open.
    @State private var isOpen = true
    /// Started here rather than on appear, so the countdown runs from the first frame.
    @StateObject private var clock: PanelClock

    init(state: NextBreakState, progress: Double, scene: MenuScene, schedule: Schedule?, pomodoro: PomodoroStatus?) {
        self.state = state
        self.progress = progress
        self.scene = scene
        self.schedule = schedule
        self.pomodoro = pomodoro
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        _clock = StateObject(wrappedValue: PanelClock(every: Self.tickInterval(scene: scene, reduceMotion: reduceMotion, isOpen: true)))
    }

    /// Twelve frames a second for a moving scene, one for the countdown alone, none when closed.
    private static func tickInterval(scene: MenuScene, reduceMotion: Bool, isOpen: Bool) -> TimeInterval? {
        guard isOpen else { return nil }
        return reduceMotion || scene == .off ? 1 : 1.0 / 12
    }

    var body: some View {
        let look = MenuSceneLook(state: state, pomodoro: pomodoro, now: clock.now)
        VStack(alignment: .leading, spacing: 10) {
            if scene != .off {
                MenuSceneCard(scene: scene, look: look, progress: progress, date: clock.now, isMoving: !reduceMotion)
            }
            statusRow(look: look, now: clock.now)
        }
        .onChange(of: Self.tickInterval(scene: scene, reduceMotion: reduceMotion, isOpen: isOpen)) { interval in
            clock.run(every: interval)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { note in
            guard let window = note.object as? NSWindow, window.isMenuBarPanel else { return }
            isOpen = window.occlusionState.contains(.visible)
            // Here, not only in `onChange`: that never ran once the panel was hidden.
            clock.run(every: Self.tickInterval(scene: scene, reduceMotion: reduceMotion, isOpen: isOpen))
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
        if let pomodoro {
            switch pomodoro.phase {
            case .focus(let round): return "Focus \(round)/\(pomodoro.rounds)"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }
        return switch look {
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
        } else if let pomodoro {
            HStack(spacing: 4) {
                Text("Pomodoro")
                Text(verbatim: "·")
                if case .shortBreak = pomodoro.phase {
                    Text("next Focus \(pomodoro.round)/\(pomodoro.rounds)")
                } else {
                    Text(LocalizedStringKey(pomodoro.level.displayName))
                }
            }
            .lineLimit(1)
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
        // A break phase counts down only on screen: while it waits, its phase end is stale and
        // the state's date, if any, is a postponed break's return, which the state branch shows.
        if let pomodoro, !pomodoro.phase.isBreak || state == .breakActive {
            trailingColumn(label: pomodoro.phase.isBreak ? "Break left" : "Focus left") {
                Text(formatCountdown(secondsRemaining: breakSecondsRemaining(until: pomodoro.phaseEnd, now: now)))
            }
        } else {
            stateTrailing(now: now)
        }
    }

    @ViewBuilder
    private func stateTrailing(now: Date) -> some View {
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

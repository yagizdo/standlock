import SwiftUI
import StandLockCore

struct QuickActionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    private var activeSchedule: Schedule? {
        coordinator.schedules.first(where: \.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if coordinator.isPaused {
                Button {
                    coordinator.resumeSchedule()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text("Resume Schedule")
                        Spacer()
                    }
                }
                .buttonStyle(MenuBarRowStyle())
            } else {
                Button {
                    coordinator.skipNextBreak()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "forward.end")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text("Skip Next Break")
                        Spacer()
                    }
                }
                .buttonStyle(MenuBarRowStyle())
                .disabled(coordinator.schedules.isEmpty || coordinator.isBreakActive)

                Button {
                    showPauseMenu()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text("Pause Schedule")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(MenuBarRowStyle())
                .disabled(coordinator.schedules.isEmpty)
            }

            if let schedule = activeSchedule {
                scheduleInfo(schedule)
                    .padding(.top, 4)
            }
        }
    }

    private func scheduleInfo(_ schedule: Schedule) -> some View {
        HStack(spacing: 8) {
            Text(levelIcon(schedule.disciplineLevel))
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(schedule.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(schedule.disciplineLevel.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func showPauseMenu() {
        let handler = PauseMenuHandler(coordinator: coordinator)
        let menu = NSMenu()

        let item30 = NSMenuItem(title: "30 minutes", action: #selector(PauseMenuHandler.pause30), keyEquivalent: "")
        item30.target = handler
        menu.addItem(item30)

        let item60 = NSMenuItem(title: "1 hour", action: #selector(PauseMenuHandler.pause60), keyEquivalent: "")
        item60.target = handler
        menu.addItem(item60)

        let item120 = NSMenuItem(title: "2 hours", action: #selector(PauseMenuHandler.pause120), keyEquivalent: "")
        item120.target = handler
        menu.addItem(item120)

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func levelIcon(_ level: DisciplineLevel) -> String {
        switch level {
        case .gentle: "🟢"
        case .firm: "🟡"
        case .strict: "🔴"
        }
    }
}

@MainActor
private final class PauseMenuHandler: NSObject {
    let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    @objc func pause30() { coordinator.pauseSchedule(for: 30 * 60) }
    @objc func pause60() { coordinator.pauseSchedule(for: 60 * 60) }
    @objc func pause120() { coordinator.pauseSchedule(for: 2 * 60 * 60) }
}

import SwiftUI
import StandLockCore

struct QuickActionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.openWindow) private var openWindow
    @State private var isConfirmingQuit = false

    var body: some View {
        // Tight spacing leaves the two equal pills room for the longest title, Turkish "Duraklat".
        HStack(spacing: 5) {
            if coordinator.isPaused {
                Button {
                    coordinator.resumeSchedule()
                } label: {
                    MenuBarPillLabel("Resume", symbol: "play.fill")
                }
                .buttonStyle(MenuBarPillStyle())
            } else {
                Button {
                    coordinator.skipNextBreak()
                } label: {
                    MenuBarPillLabel("Skip", symbol: "forward.end")
                }
                .buttonStyle(MenuBarPillStyle())
                // Kit ignores both while a session runs: Stop ends it.
                .disabled(!coordinator.schedules.contains(where: \.isEnabled) || coordinator.isBreakActive || inSession)

                Button {
                    showPauseMenu()
                } label: {
                    MenuBarPillLabel("Pause", symbol: "pause.circle")
                }
                .buttonStyle(MenuBarPillStyle())
                .disabled(coordinator.schedules.isEmpty || inSession)
            }

            iconButton("About StandLock", symbol: "info.circle") {
                coordinator.settingsNavigation.open(.about, using: openWindow)
            }

            iconButton("Settings", symbol: "gearshape") {
                coordinator.settingsNavigation.open(.general, using: openWindow)
            }

            iconButton("Quit StandLock", symbol: "power") {
                isConfirmingQuit = true
            }
            .disabled(coordinator.isBreakActive)
            .popover(isPresented: $isConfirmingQuit, arrowEdge: .bottom) {
                // A popover is a new hosting root, so the language does not reach it otherwise.
                LocalizedRoot(store: languageStore) {
                    QuitConfirmationView(cancel: { isConfirmingQuit = false }, quit: { NSApp.terminate(nil) })
                }
            }
        }
    }

    private var inSession: Bool { coordinator.pomodoroStatus != nil }

    private func iconButton(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(MenuBarPillStyle())
        .frame(width: 28)
        .help(title)
        .accessibilityLabel(title)
    }

    private func showPauseMenu() {
        let handler = PauseMenuHandler(coordinator: coordinator)
        let menu = NSMenu()

        let item30 = NSMenuItem(title: languageStore.string("30 minutes"), action: #selector(PauseMenuHandler.pause30), keyEquivalent: "")
        item30.target = handler
        menu.addItem(item30)

        let item60 = NSMenuItem(title: languageStore.string("1 hour"), action: #selector(PauseMenuHandler.pause60), keyEquivalent: "")
        item60.target = handler
        menu.addItem(item60)

        let item120 = NSMenuItem(title: languageStore.string("2 hours"), action: #selector(PauseMenuHandler.pause120), keyEquivalent: "")
        item120.target = handler
        menu.addItem(item120)

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
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

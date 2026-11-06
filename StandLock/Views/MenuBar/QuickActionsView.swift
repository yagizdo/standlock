import SwiftUI
import StandLockCore

struct QuickActionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 6) {
            if coordinator.isPaused {
                Button {
                    coordinator.resumeSchedule()
                } label: {
                    pill("Resume", symbol: "play.fill")
                }
                .buttonStyle(MenuBarPillStyle())
            } else {
                Button {
                    coordinator.skipNextBreak()
                } label: {
                    pill("Skip", symbol: "forward.end")
                }
                .buttonStyle(MenuBarPillStyle())
                .disabled(coordinator.schedules.isEmpty || coordinator.isBreakActive)

                Button {
                    showPauseMenu()
                } label: {
                    pill("Pause", symbol: "pause.circle")
                }
                .buttonStyle(MenuBarPillStyle())
                .disabled(coordinator.schedules.isEmpty)
            }

            Button {
                showMoreMenu()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(MenuBarPillStyle())
            .frame(width: 34)
            .accessibilityLabel("Menu")
        }
    }

    private func pill(_ title: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
                .lineLimit(1)
        }
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

    private func showMoreMenu() {
        let handler = MoreMenuHandler(coordinator: coordinator, openWindow: openWindow)
        let menu = NSMenu()
        // An `NSMenu` item ignores SwiftUI's `.disabled`, and without this it would ignore
        // `isEnabled` too.
        menu.autoenablesItems = false

        let settings = NSMenuItem(title: languageStore.string("Settings..."), action: #selector(MoreMenuHandler.settings), keyEquivalent: ",")
        settings.target = handler
        menu.addItem(settings)

        let about = NSMenuItem(title: languageStore.string("About StandLock"), action: #selector(MoreMenuHandler.about), keyEquivalent: "")
        about.target = handler
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: languageStore.string("Quit StandLock"), action: #selector(MoreMenuHandler.quit), keyEquivalent: "")
        quit.target = handler
        quit.isEnabled = !coordinator.isBreakActive
        menu.addItem(quit)

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

@MainActor
private final class MoreMenuHandler: NSObject {
    let coordinator: AppCoordinator
    let openWindow: OpenWindowAction

    init(coordinator: AppCoordinator, openWindow: OpenWindowAction) {
        self.coordinator = coordinator
        self.openWindow = openWindow
    }

    @objc func settings() { coordinator.settingsNavigation.open(.general, using: openWindow) }
    @objc func about() { coordinator.settingsNavigation.open(.about, using: openWindow) }
    @objc func quit() { NSApp.terminate(nil) }
}

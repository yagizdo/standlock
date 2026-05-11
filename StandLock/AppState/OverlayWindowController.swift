import AppKit
import SwiftUI
import StandLockCore
import Locking

@MainActor
final class OverlayWindowController: LockPresenting, Observable {
    private var overlayWindows: [BreakOverlayWindow] = []
    private var eventTapController: EventTapController?
    private(set) var isShowing: Bool = false

    private var currentLevel: DisciplineLevel?
    private var currentDuration: TimeInterval = 0
    private var currentExercise: Exercise?
    private var currentPreferences: AppPreferences?

    var onSkip: (() -> Void)?
    var onComplete: (() -> Void)?
    var onEscape: (() -> Void)?

    nonisolated init() {}

    func showOverlay(
        level: DisciplineLevel, duration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences
    ) {
        dismissOverlay()

        currentLevel = level
        currentDuration = duration
        currentExercise = exercise
        currentPreferences = preferences

        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(screen: screen)
            let contentView = BreakContentView(
                level: level, totalDuration: duration,
                exercise: exercise, preferences: preferences,
                onSkip: { [weak self] in self?.handleSkip() },
                onComplete: { [weak self] in self?.handleComplete() }
            )
            window.setContent(contentView)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
        isShowing = true

        if level == .strict {
            startEventTap(preferences: preferences)
        }

        observeScreenChanges()
    }

    func dismissOverlay() {
        eventTapController?.stop()
        eventTapController = nil
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
        isShowing = false
    }

    private func startEventTap(preferences: AppPreferences) {
        eventTapController = EventTapController(
            escapeHoldDuration: preferences.strictEscapeHoldDuration,
            onEscapeTriggered: { [weak self] in
                Task { @MainActor in self?.handleEscape() }
            }
        )
        eventTapController?.startBlocking()
    }

    private func handleSkip() {
        dismissOverlay()
        onSkip?()
    }

    private func handleComplete() {
        dismissOverlay()
        onComplete?()
    }

    private func handleEscape() {
        dismissOverlay()
        onEscape?()
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    private func handleScreenChange() {
        guard isShowing,
              let level = currentLevel,
              let prefs = currentPreferences else { return }
        dismissOverlay()
        showOverlay(
            level: level, duration: currentDuration,
            exercise: currentExercise, preferences: prefs
        )
    }
}

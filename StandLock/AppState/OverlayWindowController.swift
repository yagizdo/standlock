import AppKit
import SwiftUI
import StandLockCore
import Locking

@MainActor
final class OverlayWindowController: LockPresenting, Observable {
    private var overlayWindows: [BreakOverlayWindow] = []
    private var eventTapController: EventTapController?
    private var screenObserver: NSObjectProtocol?
    private var deactivationObserver: NSObjectProtocol?
    private var focusTimer: Timer?
    private(set) var isShowing: Bool = false

    private var currentLevel: DisciplineLevel?
    private var currentDuration: TimeInterval = 0
    private var currentExercise: Exercise?
    private var currentPreferences: AppPreferences?
    private var currentStatistics: BreakStatistics?

    var onSkip: (() -> Void)?
    var onComplete: (() -> Void)?
    var onEscape: (() -> Void)?

    nonisolated init() {}

    func showOverlay(
        level: DisciplineLevel, duration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences,
        statistics: BreakStatistics
    ) {
        dismissOverlay()

        currentLevel = level
        currentDuration = duration
        currentExercise = exercise
        currentPreferences = preferences
        currentStatistics = statistics

        NSApp.setActivationPolicy(.regular)

        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(screen: screen)
            let contentView = BreakContentView(
                level: level, totalDuration: duration,
                exercise: exercise, preferences: preferences,
                statistics: statistics,
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

        forceFocus()

        if level == .firm || level == .strict {
            startFocusEnforcer()
        }

        observeScreenChanges()
    }

    func dismissOverlay() {
        guard isShowing else { return }

        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        if let observer = deactivationObserver {
            NotificationCenter.default.removeObserver(observer)
            deactivationObserver = nil
        }
        focusTimer?.invalidate()
        focusTimer = nil
        eventTapController?.stop()
        eventTapController = nil

        let windows = overlayWindows
        overlayWindows.removeAll()
        isShowing = false

        for window in windows {
            window.contentView = nil
            window.orderOut(nil)
        }

        NSApp.setActivationPolicy(.accessory)
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

    private func forceFocus() {
        NSApp.activate()
        overlayWindows.first?.orderFrontRegardless()
        overlayWindows.first?.makeKeyAndOrderFront(nil)
    }

    private func startFocusEnforcer() {
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self, self.isShowing else { return }
            self.forceFocus()
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    private func handleScreenChange() {
        guard isShowing,
              let level = currentLevel,
              let prefs = currentPreferences,
              let stats = currentStatistics else { return }
        dismissOverlay()
        showOverlay(
            level: level, duration: currentDuration,
            exercise: currentExercise, preferences: prefs,
            statistics: stats
        )
    }
}

import AppKit
import SwiftUI
import StandLockCore
import Locking

@MainActor
final class OverlayWindowController: LockPresenting {
    private var overlayWindows: [BreakOverlayWindow] = []
    private var eventTapController: EventTapController?
    private var screenObserver: NSObjectProtocol?
    private var focusTimer: Timer?
    private let mediaController = MediaController()
    private(set) var isShowing: Bool = false

    private var currentLevel: DisciplineLevel?
    private var currentDuration: TimeInterval = 0
    private var currentExercise: Exercise?
    private var currentPreferences: AppPreferences?
    private var currentStatistics: BreakStatistics?
    private var currentEscalationTier: Int = 0
    private var breakStartDate: Date?
    private var lastScreenChangeHandled: Date = .distantPast

    var onSkip: (() -> Void)?
    var onComplete: (() -> Void)?
    var onEscape: (() -> Void)?

    nonisolated init() {}

    func showOverlay(
        level: DisciplineLevel, duration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences,
        statistics: BreakStatistics, escalationTier: Int = 0
    ) {
        let isRecreation = isShowing
        dismissOverlay()
        if !isRecreation {
            breakStartDate = Date()
        }

        currentLevel = level
        currentDuration = duration
        currentExercise = exercise
        currentPreferences = preferences
        currentStatistics = statistics
        currentEscalationTier = escalationTier

        let palette = BreakPalette.for(level)
        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(screen: screen)
            window.backgroundColor = NSColor(palette.paper)
            let contentView = ManuscriptBreakView(
                level: level, totalDuration: duration,
                exercise: exercise, preferences: preferences,
                statistics: statistics, escalationTier: escalationTier,
                onSkip: { [weak self] in self?.handleSkip() },
                onEscape: { [weak self] in self?.handleEscape() },
                onComplete: { [weak self] in self?.handleComplete() }
            )
            window.setContent(contentView)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
        isShowing = true

        if level == .strict {
            startEventTap(preferences: preferences)
        }

        forceFocus()
        startFocusEnforcer()

        observeScreenChanges()

        if preferences.pauseMediaDuringBreak {
            mediaController.pause()
        }
    }

    func dismissOverlay() {
        guard isShowing else { return }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
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

        let hasOtherVisibleWindows = NSApp.windows.contains { window in
            window.isVisible && !(window is BreakOverlayWindow)
        }

        if !hasOtherVisibleWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func startEventTap(preferences: AppPreferences) {
        let level = currentLevel ?? .strict
        let policy = level.enforcementPolicy(preferences: preferences)
        let enforcementTier = policy.tier(at: currentEscalationTier)
        let effectiveHold: TimeInterval
        if case .keyCombo(let duration) = enforcementTier.dismissMechanism {
            effectiveHold = duration
        } else {
            effectiveHold = preferences.strictEscapeHoldDuration
        }
        eventTapController = EventTapController(
            escapeHoldDuration: effectiveHold,
            onEscapeTriggered: { [weak self] in
                Task { @MainActor in self?.handleEscape() }
            }
        )
        eventTapController?.startBlocking()
    }

    private func handleSkip() {
        breakStartDate = nil
        dismissOverlay()
        onSkip?()
    }

    private func handleComplete() {
        breakStartDate = nil
        dismissOverlay()
        onComplete?()
    }

    private func handleEscape() {
        breakStartDate = nil
        dismissOverlay()
        onEscape?()
    }

    private func forceFocus() {
        for window in overlayWindows {
            window.orderFrontRegardless()
        }
        overlayWindows.first?.makeKey()
    }

    private func startFocusEnforcer() {
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isShowing else { return }
                self.forceFocus()
            }
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleScreenChange()
            }
        }
    }

    private func handleScreenChange() {
        let now = Date()
        guard now.timeIntervalSince(lastScreenChangeHandled) > 2.0 else { return }
        lastScreenChangeHandled = now

        guard isShowing,
              let level = currentLevel,
              let prefs = currentPreferences,
              let stats = currentStatistics else { return }

        let elapsed = breakStartDate.map { now.timeIntervalSince($0) } ?? 0
        guard elapsed < currentDuration else {
            handleComplete()
            return
        }

        let remaining = currentDuration - elapsed
        let tier = currentEscalationTier
        let exercise = currentExercise
        dismissOverlay()
        showOverlay(
            level: level, duration: remaining,
            exercise: exercise, preferences: prefs,
            statistics: stats, escalationTier: tier
        )
    }
}

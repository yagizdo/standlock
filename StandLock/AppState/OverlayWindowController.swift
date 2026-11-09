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
    private let languageStore: LanguageStore
    private let themeStore: ThemeStore
    private(set) var isShowing: Bool = false

    private var currentLevel: DisciplineLevel?
    private var currentDuration: TimeInterval = 0
    private var currentExercise: Exercise?
    private var currentPreferences: AppPreferences?
    private var currentStatistics: BreakStatistics?
    private var currentEscalationTier: Int = 0
    private var currentNextIntervalLabel: String?
    private var currentCanPostpone = false
    private var breakStartDate: Date?
    private var lastScreenChangeHandled: Date = .distantPast
    private var policyBeforeOverlay: NSApplication.ActivationPolicy = .accessory

    private let dismissalState = BreakDismissalState()
    private var currentBreakID: UUID?
    var onSkip: ((UUID) -> Void)?
    var onEscape: ((UUID) -> Void)?
    var onPostpone: ((UUID) -> Void)?

    init(languageStore: LanguageStore, themeStore: ThemeStore) {
        self.languageStore = languageStore
        self.themeStore = themeStore
    }

    func showOverlay(
        level: DisciplineLevel, duration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences,
        statistics: BreakStatistics, escalationTier: Int = 0,
        nextIntervalLabel: String? = nil, canPostpone: Bool = false,
        breakID: UUID, dismissalAvailability: DismissalAvailability
    ) {
        let isRecreation = isShowing
        dismissOverlay()
        if !isRecreation {
            breakStartDate = Date()
        }

        currentBreakID = breakID
        dismissalState.availability = dismissalAvailability
        currentLevel = level
        currentDuration = duration
        currentExercise = exercise
        currentPreferences = preferences
        currentStatistics = statistics
        currentEscalationTier = escalationTier
        currentNextIntervalLabel = nextIntervalLabel
        currentCanPostpone = canPostpone

        // Read once per overlay. That is what makes each break pick up the current
        // appearance without this controller subscribing to the store.
        let look = BreakScreenLook.resolve(
            theme: themeStore.current, level: level, breakScreen: preferences.breakScreen
        )
        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(screen: screen, palette: look.palette, appearance: look.appearance)
            let contentView = ManuscriptBreakView(
                level: level, look: look, totalDuration: duration,
                exercise: exercise, preferences: preferences,
                statistics: statistics, escalationTier: escalationTier,
                nextIntervalLabel: nextIntervalLabel,
                canPostpone: canPostpone, dismissalState: dismissalState,
                onSkip: { [weak self] in self?.onSkip?(breakID) },
                onPostpone: { [weak self] in self?.onPostpone?(breakID) },
                onEscape: { [weak self] in self?.onEscape?(breakID) }
            )
            window.setContent(LocalizedRoot(store: languageStore) { contentView })
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
        isShowing = true

        // Activate the app, not just the window. A menu bar app stays .accessory and
        // inactive, and an inactive app gets no input method: the escape phrase field
        // then receives raw keystrokes, so Pinyin types `nihao` instead of 你好 and no
        // Chinese, Japanese or Korean phrase can ever be entered. `dismissOverlay`
        // restores the policy saved here; the `dismissOverlay` call above has already
        // put back any earlier one, so this is the policy from before the break.
        policyBeforeOverlay = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if level == .strict {
            startEventTap(preferences: preferences, breakID: breakID)
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

        // Put back what `showOverlay` saved instead of looking for other visible windows:
        // `NSApp.windows` always holds the menu bar item's visible NSStatusBarWindow, so
        // that check kept the app .regular, with a Dock icon and focus, after every break.
        NSApp.setActivationPolicy(policyBeforeOverlay)
    }

    func updateDismissalAvailability(_ availability: DismissalAvailability) {
        dismissalState.availability = availability
        eventTapController?.escapeEnabled = availability.emergencyEscapeAllowed
    }

    private func startEventTap(preferences: AppPreferences, breakID: UUID) {
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
                Task { @MainActor in self?.onEscape?(breakID) }
            }
        )
        eventTapController?.escapeEnabled = dismissalState.availability.emergencyEscapeAllowed
        eventTapController?.startBlocking()
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
              let breakID = currentBreakID,
              let prefs = currentPreferences,
              let stats = currentStatistics else { return }

        let elapsed = breakStartDate.map { now.timeIntervalSince($0) } ?? 0
        guard elapsed < currentDuration else {
            return
        }

        let remaining = currentDuration - elapsed
        let tier = currentEscalationTier
        let exercise = currentExercise
        let nextLabel = currentNextIntervalLabel
        let canPostpone = currentCanPostpone
        dismissOverlay()
        showOverlay(
            level: level, duration: remaining,
            exercise: exercise, preferences: prefs,
            statistics: stats, escalationTier: tier,
            nextIntervalLabel: nextLabel, canPostpone: canPostpone,
            breakID: breakID, dismissalAvailability: dismissalState.availability
        )
    }
}

import SwiftUI
import StandLockCore
import Locking

struct ActionArea: View {
    let tier: EnforcementTier
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let disciplineLevel: DisciplineLevel
    var escalationTier: Int = 0
    let onDismiss: () -> Void

    @State private var showAction = false
    @State private var countdown: Int = 0

    var body: some View {
        Group {
            if tier.skipDelay == 0 {
                mechanismView
            } else if showAction {
                mechanismView
            } else {
                countdownLabel
            }
        }
        .animation(.easeOut(duration: 0.3), value: showAction)
        .task {
            let delay = Int(tier.skipDelay)
            guard delay > 0 else {
                showAction = true
                return
            }
            countdown = delay
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown -= 1
            }
            showAction = true
        }
    }

    private var countdownLabel: some View {
        Text("Skip available in \(countdown)s")
            .font(BreakTypography.label(size: 12))
            .foregroundStyle(palette.inkFaint)
            .contentTransition(.numericText())
            .animation(.default, value: countdown)
    }

    @ViewBuilder
    private var mechanismView: some View {
        if let limit = disciplineLevel.dailySkipLimit(preferences: preferences), statistics.breaksSkipped >= limit {
            Text("Daily skip limit reached")
                .font(BreakTypography.label(size: 12, weight: .medium))
                .foregroundStyle(palette.inkFaint)
        } else {
            mechanismContent
        }
    }

    @ViewBuilder
    private var mechanismContent: some View {
        switch tier.dismissMechanism {
        case .button:
            DodgingWrapper(isActive: escalationTier >= 1) {
                ButtonDismissView(palette: palette, onDismiss: onDismiss)
            }
        case .typePhrase(let phrase, let requiresConfirmation):
            PhraseDismissView(
                palette: palette, phrase: phrase,
                requiresConfirmation: requiresConfirmation,
                escalationTier: escalationTier,
                onDismiss: onDismiss
            )
        case .findButton(let count, let attempts):
            FindButtonDismissView(
                palette: palette,
                buttonCount: count,
                maxAttempts: attempts,
                onDismiss: onDismiss
            )
        case .crateOpening(let slotCount, let maxAttempts):
            CrateOpeningDismissView(
                palette: palette,
                slotCount: slotCount,
                maxAttempts: maxAttempts,
                onDismiss: onDismiss
            )
        case .slotMachine(let reelCount, let maxAttempts):
            SlotMachineDismissView(
                palette: palette,
                reelCount: reelCount,
                maxAttempts: maxAttempts,
                onDismiss: onDismiss
            )
        case .keyCombo(let duration):
            KeyComboDismissView(
                palette: palette, holdDuration: duration,
                weeklyEscapeCount: statistics.weeklyEscapeCount
            )
        case .roastChallenge(let sentenceCount):
            RoastChallengeDismissView(
                palette: palette,
                sentenceCount: sentenceCount,
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Dodging

private struct DodgingWrapper<Content: View>: View {
    let isActive: Bool
    let content: Content

    @State private var center: CGPoint? = nil
    @State private var containerSize: CGSize = .zero
    @State private var dodgeCount = 0
    @State private var mouseInZone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isActive: Bool, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
    }

    var body: some View {
        if isActive && !reduceMotion {
            GeometryReader { geo in
                content
                    .fixedSize()
                    .position(center ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    .onAppear {
                        containerSize = geo.size
                        center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
            }
            .frame(height: 400)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard dodgeCount < 14, containerSize.width > 0 else { return }
                switch phase {
                case .active(let location):
                    let c = center ?? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                    let dist = hypot(location.x - c.x, location.y - c.y)
                    if dist < 180, !mouseInZone {
                        mouseInZone = true
                        performDodge(awayFrom: location)
                    } else if dist >= 180 {
                        mouseInZone = false
                    }
                case .ended:
                    mouseInZone = false
                }
            }
        } else {
            content
        }
    }

    private func performDodge(awayFrom mouse: CGPoint) {
        dodgeCount += 1
        let c = center ?? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let baseAngle = atan2(c.y - mouse.y, c.x - mouse.x)
        let angle = baseAngle + Double.random(in: -0.5...0.5)
        let r: CGFloat = 280
        var nx = c.x + cos(angle) * r
        var ny = c.y + sin(angle) * r
        nx = max(40, min(containerSize.width - 40, nx))
        ny = max(20, min(containerSize.height - 20, ny))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            center = CGPoint(x: nx, y: ny)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            mouseInZone = false
        }
    }
}

// MARK: - Shake

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = -5 * sin(shakes * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Find Button

private struct FindButtonDismissView: View {
    let palette: BreakPalette
    let buttonCount: Int
    let maxAttempts: Int
    let onDismiss: () -> Void

    @State private var buttonIDs: [UUID]
    @State private var correctIndex: Int
    @State private var remainingAttempts: Int
    @State private var shakeAmounts: [CGFloat]
    @State private var wrongIndex: Int? = nil
    @State private var correctFound = false
    @State private var isProcessing = false
    @State private var round = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(palette: BreakPalette, buttonCount: Int, maxAttempts: Int, onDismiss: @escaping () -> Void) {
        self.palette = palette
        self.buttonCount = buttonCount
        self.maxAttempts = maxAttempts
        self.onDismiss = onDismiss
        let ids = (0..<buttonCount).map { _ in UUID() }
        self._buttonIDs = State(initialValue: ids)
        self._correctIndex = State(initialValue: Int.random(in: 0..<buttonCount))
        self._remainingAttempts = State(initialValue: maxAttempts)
        self._shakeAmounts = State(initialValue: Array(repeating: 0, count: buttonCount))
    }

    private let columns = Array(repeating: GridItem(.fixed(120), spacing: 8), count: 4)

    private let headerMessages = [
        "Find the right button to skip",
        "Wrong again? Shocking.",
        "This is getting embarrassing",
        "Even a coin flip would work now",
    ]

    private let exhaustedMessages = [
        "Better luck next time!",
        "Wow. All three. Wasted.",
        "You're really committed to failing",
        "It's literally 50/50 now",
    ]

    private let subtitleMessages = [
        "One of these actually works...",
        "Fewer buttons, still lost?",
        "Maybe standing up is easier than this",
        "Two buttons. No excuses.",
    ]

    var body: some View {
        VStack(spacing: 12) {
            headerView
            attemptDots
            gridView
            Text(subtitleMessages[min(round, subtitleMessages.count - 1)])
                .font(BreakTypography.label(size: 11))
                .foregroundStyle(palette.inkFaint)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.2), value: round)
        }
        .transition(.opacity)
    }

    private var headerView: some View {
        let text = remainingAttempts == 0
            ? exhaustedMessages[min(round, exhaustedMessages.count - 1)]
            : headerMessages[min(round, headerMessages.count - 1)]
        return Text(text)
            .font(BreakTypography.label(size: 14, weight: .medium))
            .foregroundStyle(palette.ink)
            .contentTransition(.interpolate)
            .animation(.easeInOut(duration: 0.2), value: remainingAttempts)
            .animation(.easeInOut(duration: 0.2), value: round)
    }

    private var attemptDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<maxAttempts, id: \.self) { i in
                Circle()
                    .fill(i < remainingAttempts ? palette.accent : palette.paperEdge)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var gridView: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(buttonIDs.enumerated()), id: \.element) { index, _ in
                Button(action: { handleTap(at: index) }) {
                    Text("Skip this break \u{2192}")
                        .font(BreakTypography.label(size: 12, weight: .medium))
                        .foregroundStyle(wrongIndex == index ? Color.red : (correctFound && index == correctIndex ? Color.green : palette.ink))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(palette.paper.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    wrongIndex == index ? Color.red.opacity(0.5) :
                                    (correctFound && index == correctIndex ? Color.green.opacity(0.5) : palette.paperEdge),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .modifier(ShakeEffect(shakes: index < shakeAmounts.count ? shakeAmounts[index] : 0))
                .disabled(correctFound || isProcessing)
            }
        }
    }

    private func handleTap(at index: Int) {
        if index == correctIndex {
            withAnimation(.easeOut(duration: 0.15)) {
                correctFound = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                onDismiss()
            }
        } else {
            wrongIndex = index
            remainingAttempts -= 1
            isProcessing = true

            if !reduceMotion {
                withAnimation(.default) {
                    shakeAmounts[index] += 3
                }
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                wrongIndex = nil

                let shuffled = buttonIDs.shuffled()
                let newCorrectIndex = Int.random(in: 0..<shuffled.count)
                let animation: Animation? = reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)
                withAnimation(animation) {
                    buttonIDs = shuffled
                    correctIndex = newCorrectIndex
                }

                if remainingAttempts == 0 {
                    try? await Task.sleep(for: .milliseconds(600))
                    round += 1
                    let newCount = max(2, buttonIDs.count - 2)
                    if newCount < buttonIDs.count {
                        let trimmed = Array(buttonIDs.shuffled().prefix(newCount))
                        let trimCorrectIndex = Int.random(in: 0..<newCount)
                        let trimAnimation: Animation? = reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)
                        withAnimation(trimAnimation) {
                            buttonIDs = trimmed
                            correctIndex = trimCorrectIndex
                        }
                        shakeAmounts = Array(repeating: 0, count: newCount)
                    }
                    remainingAttempts = maxAttempts
                }
                isProcessing = false
            }
        }
    }
}

// MARK: - Crate Opening

private struct CrateOpeningDismissView: View {
    let palette: BreakPalette
    let slotCount: Int
    let maxAttempts: Int
    let onDismiss: () -> Void

    private let slotWidth: CGFloat = 52
    private let slotSpacing: CGFloat = 4
    private let viewportWidth: CGFloat = 420
    private let spinDuration: TimeInterval = 7.0
    private let greenSlotOffset = 4
    private let repetitions = 8

    @State private var stripOffset: CGFloat = 0
    @State private var currentAttempt = 0
    @State private var isSpinning = false
    @State private var landed: Bool? = nil
    @State private var usedAttempts: [Bool]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(palette: BreakPalette, slotCount: Int, maxAttempts: Int, onDismiss: @escaping () -> Void) {
        self.palette = palette
        self.slotCount = slotCount
        self.maxAttempts = maxAttempts
        self.onDismiss = onDismiss
        let stride: CGFloat = 56
        self._stripOffset = State(initialValue: 420 / 2 - CGFloat(slotCount - 1) * stride - 52 / 2)
        self._usedAttempts = State(initialValue: Array(repeating: false, count: maxAttempts))
    }

    private var totalSlots: Int { slotCount * repetitions }
    private var slotStride: CGFloat { slotWidth + slotSpacing }

    private var greenIndices: Set<Int> {
        Set((0..<repetitions).map { $0 * slotCount + greenSlotOffset })
    }

    private var initialOffset: CGFloat {
        viewportWidth / 2 - CGFloat(slotCount - 1) * slotStride - slotWidth / 2
    }

    private let headerMessages = [
        "So you'd rather gamble than stand up",
        "Bold of you to try again",
        "Fine. Last spin.",
    ]

    private let loseMessages = [
        "Saw that coming",
        "Genuinely impressive",
    ]

    private let subtitleMessages = [
        "Most of these are red. Just saying.",
        "Still feeling lucky?",
        "Last chance. No pressure.",
    ]

    private var headerText: String {
        switch landed {
        case nil:
            return headerMessages[min(currentAttempt, headerMessages.count - 1)]
        case false:
            return loseMessages[min(currentAttempt, loseMessages.count - 1)]
        case true:
            return "Ugh. Fine, go."
        }
    }

    private var subtitleText: String {
        subtitleMessages[min(currentAttempt, subtitleMessages.count - 1)]
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(headerText)
                .font(BreakTypography.label(size: 14, weight: .medium))
                .foregroundStyle(palette.ink)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.2), value: landed)
                .animation(.easeInOut(duration: 0.2), value: currentAttempt)

            HStack(spacing: 6) {
                ForEach(0..<maxAttempts, id: \.self) { i in
                    Circle()
                        .fill(usedAttempts[i] ? palette.paperEdge : palette.accent)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(spacing: 0) {
                IndicatorTriangle()
                    .fill(palette.accent)
                    .frame(width: 10, height: 6)

                ZStack {
                    HStack(spacing: slotSpacing) {
                        ForEach(0..<totalSlots, id: \.self) { i in
                            let isGreen = greenIndices.contains(i)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isGreen ? palette.accent : Color.red.opacity(0.55))
                                .frame(width: slotWidth, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isGreen ? palette.accent.opacity(0.3) : Color.red.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                                .overlay(
                                    Text(isGreen ? "Skip" : "\u{2715}")
                                        .font(BreakTypography.label(size: isGreen ? 13 : 16, weight: .medium))
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                    .offset(x: stripOffset)
                    .frame(width: viewportWidth, height: 64, alignment: .leading)

                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [palette.paper, palette.paper.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 36)
                        Spacer()
                        LinearGradient(
                            colors: [palette.paper.opacity(0), palette.paper],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 36)
                    }

                    Rectangle()
                        .fill(palette.accent)
                        .frame(width: 2, height: 64)
                }
                .frame(width: viewportWidth, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.paper.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(palette.paperEdge, lineWidth: 1)
                )

                IndicatorTriangle()
                    .fill(palette.accent)
                    .frame(width: 10, height: 6)
                    .rotationEffect(.degrees(180))
            }

            Text(subtitleText)
                .font(BreakTypography.label(size: 11))
                .foregroundStyle(palette.inkFaint)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.2), value: currentAttempt)

            Button(action: spin) {
                VStack(spacing: 4) {
                    Text(currentAttempt == 0 ? "Spin \u{2192}" : "Try again \u{2192}")
                        .font(BreakTypography.label(size: 14, weight: .medium))
                        .foregroundStyle(palette.ink)
                    Rectangle()
                        .fill(palette.ink)
                        .frame(height: 1)
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
            .disabled(isSpinning)
            .opacity(isSpinning ? 0.4 : 1)
        }
        .transition(.opacity)
    }

    private func spin() {
        guard !isSpinning else { return }
        isSpinning = true
        landed = nil

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stripOffset = initialOffset
        }

        let targetStart = slotCount * 4
        let targetEnd = slotCount * (repetitions - 1)
        let greens = Array(greenIndices).filter { $0 >= targetStart && $0 < targetEnd }
        let nonGreens = (targetStart..<targetEnd).filter { !greenIndices.contains($0) }

        let targetIndex: Int
        switch currentAttempt {
        case 0:
            targetIndex = Int.random(in: targetStart..<targetEnd)
        case 1:
            targetIndex = Double.random(in: 0..<1) < 0.35
                ? greens.randomElement()!
                : nonGreens.randomElement()!
        default:
            targetIndex = greens.randomElement()!
        }

        let jitter = CGFloat.random(in: -10...10)
        let finalOffset = viewportWidth / 2 - CGFloat(targetIndex) * slotStride - slotWidth / 2 + jitter
        let hitGreen = greenIndices.contains(targetIndex)

        Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) {
                    stripOffset = finalOffset
                }
                try? await Task.sleep(for: .milliseconds(400))
            } else {
                withAnimation(.timingCurve(0.1, 0.8, 0.2, 1.0, duration: spinDuration)) {
                    stripOffset = finalOffset
                }
                try? await Task.sleep(for: .seconds(spinDuration + 0.3))
            }

            guard !Task.isCancelled else { return }

            if hitGreen {
                landed = true
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                onDismiss()
            } else {
                landed = false
                usedAttempts[currentAttempt] = true
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                currentAttempt += 1
                isSpinning = false
            }
        }
    }
}

// MARK: - Slot Machine

private struct SlotMachineDismissView: View {
    let palette: BreakPalette
    let reelCount: Int
    let maxAttempts: Int
    let onDismiss: () -> Void

    private let symbolHeight: CGFloat = 48
    private let symbolSpacing: CGFloat = 4
    private let reelWidth: CGFloat = 100
    private let reelSpacing: CGFloat = 12
    private let visibleRows = 3
    private let stopDuration: CGFloat = 0.8

    @State private var reels: [ReelState]
    @State private var symbols: [[SlotSymbol]]
    @State private var gamePhase: GamePhase = .idle
    @State private var currentAttempt = 0
    @State private var usedAttempts: [Bool]
    @State private var nearMiss = false
    @State private var winGlow = false
    @State private var loseFlash: Set<Int> = []
    @State private var autoStopTasks: [Task<Void, Never>] = []
    @State private var fallbackInput = ""
    private let fallbackPhrase = "I prefer sitting anyway"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var symbolStride: CGFloat { symbolHeight + symbolSpacing }
    private var symbolCount: Int { SlotSymbol.allCases.count }
    private var activeReelCount: Int { currentAttempt >= maxAttempts - 1 ? 1 : reelCount }
    private var viewportHeight: CGFloat { CGFloat(visibleRows) * symbolStride - symbolSpacing }
    private var centerAlignOffset: CGFloat { viewportHeight / 2 - symbolHeight / 2 }

    private struct ReelState {
        var phase: ReelPhase = .idle
        var baseOffset: CGFloat
        var speed: CGFloat
        var spinStart: Date = .distantPast
        var stopStart: Date = .distantPast
        var stopFromOffset: CGFloat = 0
        var targetOffset: CGFloat = 0
        var resultIndex: Int = 0
    }

    private enum ReelPhase: Equatable {
        case idle, spinning, stopping, stopped
    }

    private enum GamePhase: Equatable {
        case idle, spinning, evaluating, result, fallback
    }

    private enum SlotSymbol: CaseIterable, Equatable {
        case skip, cross, skull, runner, bone, chair

        var label: String {
            switch self {
            case .skip: "Skip"
            case .cross: "\u{2715}"
            case .skull: "\u{1F480}"
            case .runner: "\u{1F3C3}"
            case .bone: "\u{1F9B4}"
            case .chair: "\u{1FA91}"
            }
        }

        var isWin: Bool { self == .skip }
    }

    init(palette: BreakPalette, reelCount: Int, maxAttempts: Int, onDismiss: @escaping () -> Void) {
        self.palette = palette
        self.reelCount = reelCount
        self.maxAttempts = maxAttempts
        self.onDismiss = onDismiss

        let initial: CGFloat = (CGFloat(3) * 52 - 4) / 2 - 24

        self._reels = State(initialValue: (0..<reelCount).map { i in
            ReelState(baseOffset: initial, speed: 220)
        })
        self._symbols = State(initialValue: (0..<reelCount).map { _ in SlotSymbol.allCases.shuffled() })
        self._usedAttempts = State(initialValue: Array(repeating: false, count: maxAttempts))
    }

    // MARK: Messages

    private let headers = ["Feeling lucky?", "Double or nothing... well, nothing or nothing", "Last chance. No pressure."]
    private let subtitles = ["Stop each reel on Skip to win", "Reels are a bit slower now. You're welcome.", "One reel. One button. No excuses."]
    private let lossMessages = ["The house always wins", "Two out of three ain\u{2019}t... well, it IS bad here.", "Impressive. Not a single one."]
    private let nearMissMessage = "Soooo close. The universe has a cruel sense of humor."
    private let winMessages = ["Genuinely impressive. Fine, go.", "Took you two tries but okay.", "Jackpot. Ugh."]
    private var headerText: String {
        switch gamePhase {
        case .idle, .spinning:
            return headers[min(currentAttempt, headers.count - 1)]
        case .evaluating:
            return headers[min(currentAttempt, headers.count - 1)]
        case .result:
            let count = activeReelCount
            let allSkip = (0..<count).allSatisfy { symbols[$0][reels[$0].resultIndex].isWin }
            if allSkip {
                return winMessages[min(currentAttempt, winMessages.count - 1)]
            }
            if nearMiss {
                return nearMissMessage
            }
            let skipCount = (0..<count).filter { symbols[$0][reels[$0].resultIndex].isWin }.count
            return lossMessages[min(skipCount, lossMessages.count - 1)]
        case .fallback:
            return "Fine. Just type this:"
        }
    }

    private var subtitleText: String {
        subtitles[min(currentAttempt, subtitles.count - 1)]
    }

    // MARK: Computed

    private var anyAnimating: Bool {
        reels.contains { $0.phase == .spinning || $0.phase == .stopping }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 12) {
            Text(headerText)
                .font(BreakTypography.label(size: 14, weight: .medium))
                .foregroundStyle(palette.ink)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.2), value: gamePhase)
                .animation(.easeInOut(duration: 0.2), value: currentAttempt)

            if gamePhase == .fallback {
                fallbackContent
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<maxAttempts, id: \.self) { i in
                        Circle()
                            .fill(usedAttempts[i] ? palette.paperEdge : palette.accent)
                            .frame(width: 8, height: 8)
                    }
                }

                TimelineView(.animation(paused: !anyAnimating)) { timeline in
                    HStack(spacing: reelSpacing) {
                        ForEach(0..<activeReelCount, id: \.self) { i in
                            reelColumn(index: i, date: timeline.date)
                        }
                    }
                }

                Text(subtitleText)
                    .font(BreakTypography.label(size: 11))
                    .foregroundStyle(palette.inkFaint)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: currentAttempt)

                if gamePhase == .idle {
                    Button(action: startSpin) {
                        VStack(spacing: 4) {
                            Text(currentAttempt == 0 ? "Spin \u{2192}" : "Try again \u{2192}")
                                .font(BreakTypography.label(size: 14, weight: .medium))
                                .foregroundStyle(palette.ink)
                            Rectangle()
                                .fill(palette.ink)
                                .frame(height: 1)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: Reel Column

    private func reelColumn(index: Int, date: Date) -> some View {
        VStack(spacing: 8) {
            reelViewport(index: index, date: date)
            reelStopButton(index: index)
        }
    }

    private func reelViewport(index: Int, date: Date) -> some View {
        let offset = reelOffset(for: index, at: date)

        let rawFirst = (-offset - symbolHeight) / symbolStride
        let rawLast = (viewportHeight - offset) / symbolStride
        let first = max(0, Int(floor(rawFirst)) - 2)
        let last = max(first, Int(ceil(rawLast)) + 2)

        return ZStack {
            ForEach(first...last, id: \.self) { i in
                symbolCell(symbols[index][i % symbolCount])
                    .offset(y: offset - centerAlignOffset + CGFloat(i) * symbolStride)
            }

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.accent, lineWidth: 2.5)
                .frame(width: reelWidth + 8, height: symbolHeight + 6)
        }
        .frame(width: reelWidth, height: viewportHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .fill(winGlow ? palette.accent.opacity(0.3) :
                      loseFlash.contains(index) ? Color.red.opacity(0.3) : .clear)
        )
        .animation(.easeInOut(duration: 0.3), value: winGlow)
        .animation(.easeInOut(duration: 0.3), value: loseFlash)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.paperEdge, lineWidth: 1)
        )
    }

    private func reelOffset(for index: Int, at date: Date) -> CGFloat {
        let reel = reels[index]
        switch reel.phase {
        case .idle, .stopped:
            return reel.baseOffset
        case .spinning:
            let elapsed = CGFloat(date.timeIntervalSince(reel.spinStart))
            return reel.baseOffset - elapsed * reel.speed
        case .stopping:
            let elapsed = CGFloat(date.timeIntervalSince(reel.stopStart))
            let t = min(elapsed / stopDuration, 1.0)
            let eased = 1 - pow(1 - t, 3)
            return reel.stopFromOffset + (reel.targetOffset - reel.stopFromOffset) * eased
        }
    }

    private func reelStopButton(index: Int) -> some View {
        let active = reels[index].phase == .spinning

        return Button {
            stopReel(index)
        } label: {
            VStack(spacing: 2) {
                Text("Stop")
                    .font(BreakTypography.label(size: 13, weight: .medium))
                    .foregroundStyle(palette.ink)
                Rectangle()
                    .fill(palette.ink)
                    .frame(height: 1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(!active)
        .opacity(gamePhase == .spinning ? (active ? 1 : 0.3) : 0)
        .animation(.easeInOut(duration: 0.2), value: active)
        .animation(.easeInOut(duration: 0.2), value: gamePhase)
    }

    private func symbolCell(_ symbol: SlotSymbol) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(symbol.isWin ? palette.accent : Color.red.opacity(0.55))
            .frame(width: reelWidth - 8, height: symbolHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        symbol.isWin ? palette.accent.opacity(0.3) : Color.red.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .overlay(
                Text(symbol.label)
                    .font(BreakTypography.label(size: symbol.isWin ? 13 : 18, weight: .medium))
                    .foregroundStyle(.white)
            )
    }

    @ViewBuilder
    private var fallbackContent: some View {
        Text(fallbackPhrase)
            .font(BreakTypography.label(size: 16, weight: .bold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.accent.opacity(0.1))
            )

        TextField("", text: $fallbackInput)
            .textFieldStyle(.plain)
            .font(BreakTypography.label(size: 14))
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.paperEdge, lineWidth: 1)
            )
            .frame(width: 250)

        if fallbackInput.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(fallbackPhrase) == .orderedSame {
            Button(action: onDismiss) {
                VStack(spacing: 4) {
                    Text("Fine, go \u{2192}")
                        .font(BreakTypography.label(size: 14, weight: .medium))
                        .foregroundStyle(palette.ink)
                    Rectangle()
                        .fill(palette.ink)
                        .frame(height: 1)
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }

        Text("We both know standing would\u{2019}ve been easier.")
            .font(BreakTypography.label(size: 11))
            .foregroundStyle(palette.inkFaint)
    }

    // MARK: Actions

    private func speedFactor(for attempt: Int) -> CGFloat {
        switch attempt {
        case 0: return 1.2
        case 1: return 0.9
        default: return 0.70
        }
    }

    private func startSpin() {
        let count = activeReelCount
        for i in 0..<count {
            symbols[i] = SlotSymbol.allCases.shuffled()
        }

        nearMiss = false
        winGlow = false
        loseFlash = []

        if reduceMotion {
            gamePhase = .evaluating
            for i in 0..<count {
                let idx = Int.random(in: 0..<symbolCount)
                reels[i].resultIndex = idx
                reels[i].baseOffset = centerAlignOffset - CGFloat(idx) * symbolStride
                reels[i].phase = .stopped
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                evaluateResult()
            }
            return
        }

        autoStopTasks.forEach { $0.cancel() }
        autoStopTasks = []

        let now = Date()
        let factor = speedFactor(for: currentAttempt)

        for i in 0..<count {
            reels[i] = ReelState(
                phase: .spinning,
                baseOffset: centerAlignOffset,
                speed: 220 * factor,
                spinStart: now
            )
            let reelIndex = i
            let task = Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                if reels[reelIndex].phase == .spinning {
                    stopReel(reelIndex)
                }
            }
            autoStopTasks.append(task)
        }

        gamePhase = .spinning
    }

    private func stopReel(_ index: Int) {
        guard reels[index].phase == .spinning else { return }

        let now = Date()
        let elapsed = CGFloat(now.timeIntervalSince(reels[index].spinStart))
        let currentOffset = reels[index].baseOffset - elapsed * reels[index].speed

        let overshoot = symbolStride * 0.5
        let futureOffset = currentOffset - overshoot
        let rawIndex = (centerAlignOffset - futureOffset) / symbolStride
        let snapped = max(0, Int(rawIndex.rounded()))
        let target = centerAlignOffset - CGFloat(snapped) * symbolStride

        reels[index].phase = .stopping
        reels[index].stopStart = now
        reels[index].stopFromOffset = currentOffset
        reels[index].targetOffset = target
        reels[index].resultIndex = snapped % symbolCount

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(stopDuration * 1000) + 100))
            guard !Task.isCancelled else { return }

            reels[index].phase = .stopped
            reels[index].baseOffset = target

            if reels.prefix(activeReelCount).allSatisfy({ $0.phase == .stopped }) {
                evaluateResult()
            }
        }
    }

    private func evaluateResult() {
        gamePhase = .evaluating

        let count = activeReelCount
        let allSkip = (0..<count).allSatisfy { symbols[$0][reels[$0].resultIndex].isWin }

        Task { @MainActor in
            if allSkip {
                gamePhase = .result
                withAnimation(.easeInOut(duration: 0.3)) { winGlow = true }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                onDismiss()
            } else {
                let skipCount = (0..<count).filter { symbols[$0][reels[$0].resultIndex].isWin }.count
                nearMiss = count > 1 && skipCount == count - 1

                gamePhase = .result
                let losing = (0..<count).filter { !symbols[$0][reels[$0].resultIndex].isWin }
                withAnimation(.easeInOut(duration: 0.3)) { loseFlash = Set(losing) }

                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled else { return }

                usedAttempts[currentAttempt] = true
                withAnimation(.easeInOut(duration: 0.2)) { loseFlash = [] }
                try? await Task.sleep(for: .milliseconds(400))

                currentAttempt += 1
                if currentAttempt >= maxAttempts {
                    gamePhase = .fallback
                    return
                }
                gamePhase = .idle
            }
        }
    }
}

private struct IndicatorTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Roast Challenge

private struct RoastChallengeDismissView: View {
    let palette: BreakPalette
    let sentenceCount: Int
    let onDismiss: () -> Void

    @State private var currentIndex = 0
    @State private var typedText = ""
    @State private var previousText = ""
    @State private var phase: Phase = .typing
    @State private var selectedSentences: [String]
    @State private var currentResponse = ""
    @FocusState private var isFieldFocused: Bool

    private enum Phase {
        case typing
        case responding
    }

    init(palette: BreakPalette, sentenceCount: Int, onDismiss: @escaping () -> Void) {
        self.palette = palette
        self.sentenceCount = sentenceCount
        self.onDismiss = onDismiss
        self._selectedSentences = State(initialValue: Array(Self.sentencePool.shuffled().prefix(sentenceCount)))
    }

    private static let sentencePool = [
        "I'm too lazy to stand for thirty seconds",
        "My spine filed a complaint but I ignored it",
        "I treat my legs like decorative furniture",
        "Standing is my greatest fear",
        "I'd rather humiliate myself than take a break",
        "My chair and I are in a committed relationship",
        "I choose early back pain over a short walk",
        "Exercise? I thought you said extra fries",
        "I skipped leg day and every other day too",
        "My doctor would be so disappointed right now",
        "I'm allergic to standing up",
        "My posture is a cry for help",
        "I consider sitting a competitive sport",
        "My legs forgot their purpose",
        "I treat health advice as gentle suggestions",
    ]

    private static let responsesAfterFirst = [
        "I already knew that. Next.",
        "Tell me something I don't know.",
        "Boring. Type another one.",
    ]

    private static let responsesAfterSecond = [
        "Still going? Wow.",
        "You actually typed that? Impressive dedication to laziness.",
        "Two down and zero shame. One more.",
    ]

    private static let responsesFinal = [
        "Fine. You're even more hopeless than I thought. Take your skip.",
        "Okay okay, you win. Or lose. Depends on perspective.",
        "I'm out of insults. Skip granted, you absolute legend.",
    ]

    private static let headerMessages = [
        "You want to skip? Earn it.",
        "Not done yet.",
        "Last one. Make it count.",
    ]

    private var phraseMatches: Bool {
        typedText.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(selectedSentences[currentIndex]) == .orderedSame
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(Self.headerMessages[min(currentIndex, Self.headerMessages.count - 1)])
                .font(BreakTypography.label(size: 14, weight: .medium))
                .foregroundStyle(palette.ink)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.2), value: currentIndex)

            HStack(spacing: 6) {
                ForEach(0..<sentenceCount, id: \.self) { i in
                    Circle()
                        .fill(i < currentIndex ? palette.accent : (i == currentIndex ? palette.accent.opacity(0.5) : palette.paperEdge))
                        .frame(width: 8, height: 8)
                }
            }

            switch phase {
            case .typing:
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Text("Write ")
                            .font(BreakTypography.label(size: 12))
                            .tracking(0.15)
                            .foregroundStyle(palette.inkFaint)
                        Text("\"\(selectedSentences[currentIndex])\"")
                            .font(BreakTypography.exerciseName(size: 12).italic())
                            .foregroundStyle(palette.ink)
                            .contentTransition(.interpolate)
                        Text(" to continue")
                            .font(BreakTypography.label(size: 12))
                            .tracking(0.15)
                            .foregroundStyle(palette.inkFaint)
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)

                    TextField("", text: $typedText)
                        .font(BreakTypography.exerciseName(size: 16))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .focused($isFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 400, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(palette.paperEdge, lineWidth: 1)
                        )
                        .onAppear { isFieldFocused = true }
                        .onChange(of: typedText) { newValue in
                            if newValue.count - previousText.count > 1 {
                                typedText = previousText
                                return
                            }
                            previousText = newValue
                        }
                }
                .transition(.opacity)

            case .responding:
                Text(currentResponse)
                    .font(BreakTypography.label(size: 13, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: phase == .responding)
        .onChange(of: phraseMatches) { matches in
            guard matches else { return }
            let responsePool: [String]
            switch currentIndex {
            case 0: responsePool = Self.responsesAfterFirst
            case 1: responsePool = Self.responsesAfterSecond
            default: responsePool = Self.responsesFinal
            }
            currentResponse = responsePool.randomElement()!
            withAnimation(.easeInOut(duration: 0.2)) { phase = .responding }

            Task { @MainActor in
                let delay: Duration = currentIndex < sentenceCount - 1 ? .milliseconds(1500) : .milliseconds(2000)
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }

                if currentIndex < sentenceCount - 1 {
                    currentIndex += 1
                    typedText = ""
                    previousText = ""
                    withAnimation(.easeInOut(duration: 0.2)) { phase = .typing }
                    isFieldFocused = true
                } else {
                    onDismiss()
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Button

private struct ButtonDismissView: View {
    let palette: BreakPalette
    let onDismiss: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onDismiss) {
            VStack(spacing: 4) {
                Text("Skip this break \u{2192}")
                    .font(BreakTypography.label(size: 14, weight: .medium))
                    .foregroundStyle(palette.ink.opacity(isPressed ? 0.7 : 1))
                Rectangle()
                    .fill(palette.ink.opacity(isPressed ? 0.7 : 1))
                    .frame(height: 1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .transition(.opacity)
    }
}

// MARK: - Type Phrase

private struct PhraseDismissView: View {
    let palette: BreakPalette
    let phrase: String
    let requiresConfirmation: Bool
    let escalationTier: Int
    let onDismiss: () -> Void

    @State private var typedPhrase = ""
    @State private var previousPhrase = ""
    @State private var showSkipConfirmation = false
    @State private var displayPhrase: String
    @State private var switchCount = 0
    @State private var canSwitch = true
    @FocusState private var isFieldFocused: Bool

    init(palette: BreakPalette, phrase: String, requiresConfirmation: Bool,
         escalationTier: Int, onDismiss: @escaping () -> Void) {
        self.palette = palette
        self.phrase = phrase
        self.requiresConfirmation = requiresConfirmation
        self.escalationTier = escalationTier
        self.onDismiss = onDismiss
        self._displayPhrase = State(initialValue: phrase)
    }

    private var phraseMatches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(displayPhrase) == .orderedSame
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("Write ")
                    .font(BreakTypography.label(size: 12))
                    .tracking(0.15)
                    .foregroundStyle(palette.inkFaint)
                Text("\"\(displayPhrase)\"")
                    .font(BreakTypography.exerciseName(size: 12).italic())
                    .foregroundStyle(palette.ink)
                    .contentTransition(.interpolate)
                Text(" to dismiss")
                    .font(BreakTypography.label(size: 12))
                    .tracking(0.15)
                    .foregroundStyle(palette.inkFaint)
            }
            .animation(.easeInOut(duration: 0.2), value: displayPhrase)

            TextField("", text: $typedPhrase)
                .font(BreakTypography.exerciseName(size: 16))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 400, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.paperEdge, lineWidth: 1)
                )
                .onAppear { isFieldFocused = true }
                .onChange(of: typedPhrase) { newValue in
                    if newValue.count - previousPhrase.count > 1 {
                        typedPhrase = previousPhrase
                        return
                    }
                    previousPhrase = newValue

                    if newValue.count <= 2 {
                        canSwitch = true
                    }

                    guard escalationTier >= 2, switchCount < 2, canSwitch,
                          displayPhrase.count > 6 else { return }
                    let threshold = max(3, Int(Double(displayPhrase.count) * 0.6))
                    guard newValue.count >= threshold else { return }

                    switchCount += 1
                    canSwitch = false
                    typedPhrase = ""
                    previousPhrase = ""
                    let nextPhrase: String
                    if switchCount == 1 {
                        nextPhrase = "Are you sure about that?"
                    } else {
                        nextPhrase = "I solemnly swear to take every single break from now until the end of time itself"
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayPhrase = nextPhrase
                    }
                }
        }
        .onChange(of: phraseMatches) { matches in
            if matches {
                if requiresConfirmation {
                    showSkipConfirmation = true
                } else {
                    onDismiss()
                }
            }
        }
        .alert("Skip this break?", isPresented: $showSkipConfirmation) {
            Button("Skip", role: .destructive) { onDismiss() }
            Button("Cancel", role: .cancel) { typedPhrase = "" }
        }
        .onChange(of: showSkipConfirmation) { showing in
            if !showing { isFieldFocused = true }
        }
        .task(id: switchCount) {
            guard switchCount == 2 else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, switchCount == 2 else { return }
            switchCount = 3
            typedPhrase = ""
            previousPhrase = ""
            withAnimation(.easeInOut(duration: 0.2)) {
                displayPhrase = phrase
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Key Combo

private struct KeyComboDismissView: View {
    let palette: BreakPalette
    let holdDuration: TimeInterval
    let weeklyEscapeCount: Int

    @State private var holdingKeys = false
    @State private var progress: CGFloat = 0
    @State private var remaining: Int

    init(palette: BreakPalette, holdDuration: TimeInterval, weeklyEscapeCount: Int) {
        self.palette = palette
        self.holdDuration = holdDuration
        self.weeklyEscapeCount = weeklyEscapeCount
        self._remaining = State(initialValue: Int(holdDuration))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
                keycap("⌃", active: holdingKeys)
                keycap("⌥", active: holdingKeys)
                keycap("⌘", active: holdingKeys)
                Text("for \(Int(holdDuration)) seconds to exit.")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
            }

            if holdingKeys {
                VStack(spacing: 6) {
                    Capsule()
                        .fill(palette.accent.opacity(0.15))
                        .frame(width: 200, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(palette.accent)
                                .frame(width: 200 * progress, height: 4)
                        }
                        .clipShape(Capsule())
                    Text("\(remaining)s")
                        .font(BreakTypography.label(size: 11, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .contentTransition(.numericText())
                        .animation(.default, value: remaining)
                }
                .transition(.opacity)
            }

            HStack(spacing: 0) {
                Text("Emergency exits this week")
                    .font(BreakTypography.label(size: 11))
                    .foregroundStyle(palette.inkFaint)
                Text(" \u{00B7} ")
                    .foregroundStyle(palette.inkFaint)
                Text("\(weeklyEscapeCount)")
                    .font(BreakTypography.label(size: 11))
                    .foregroundStyle(palette.inkFaint)
            }
        }
        .animation(.easeOut(duration: 0.2), value: holdingKeys)
        .onReceive(NotificationCenter.default.publisher(for: .escapeHoldStarted)) { _ in
            holdingKeys = true
            remaining = Int(holdDuration)
            progress = 0
            withAnimation(.linear(duration: holdDuration)) {
                progress = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .escapeHoldEnded)) { _ in
            withAnimation(.easeOut(duration: 0.15)) {
                holdingKeys = false
            }
            progress = 0
            remaining = Int(holdDuration)
        }
        .task(id: holdingKeys) {
            guard holdingKeys else { return }
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
            }
        }
    }

    private func keycap(_ glyph: String, active: Bool = false) -> some View {
        Text(glyph)
            .font(BreakTypography.keycap())
            .foregroundStyle(active ? .white : palette.ink)
            .frame(minWidth: 26, minHeight: 24)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(active ? palette.accent : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(active ? palette.accent.opacity(0.3) : palette.paperEdge, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: active)
    }
}

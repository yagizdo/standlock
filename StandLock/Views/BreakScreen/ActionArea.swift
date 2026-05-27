import SwiftUI
import StandLockCore

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
        case .keyCombo(let duration):
            KeyComboDismissView(
                palette: palette, holdDuration: duration,
                weeklyEscapeCount: statistics.weeklyEscapeCount
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

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
                keycap("⌃")
                keycap("⌥")
                keycap("⌘")
                Text("for \(Int(holdDuration)) seconds to exit.")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
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
    }

    private func keycap(_ glyph: String) -> some View {
        Text(glyph)
            .font(BreakTypography.keycap())
            .foregroundStyle(palette.ink)
            .frame(minWidth: 26, minHeight: 24)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(palette.paperEdge, lineWidth: 1)
            )
    }
}

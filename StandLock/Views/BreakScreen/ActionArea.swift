import SwiftUI
import StandLockCore

struct ActionArea: View {
    let tier: EnforcementTier
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
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
        switch tier.dismissMechanism {
        case .button:
            DodgingWrapper(isActive: escalationTier >= 2) {
                ButtonDismissView(palette: palette, onDismiss: onDismiss)
            }
        case .holdButton(let duration):
            DodgingWrapper(isActive: escalationTier >= 2) {
                HoldDismissView(palette: palette, holdDuration: duration, onDismiss: onDismiss)
            }
        case .typePhrase(let phrase, let requiresConfirmation):
            if statistics.breaksSkipped >= preferences.firmDailySkipLimit {
                Text("Daily skip limit reached")
                    .font(BreakTypography.label(size: 12, weight: .medium))
                    .foregroundStyle(palette.inkFaint)
            } else {
                PhraseDismissView(
                    palette: palette, phrase: phrase,
                    requiresConfirmation: requiresConfirmation,
                    escalationTier: escalationTier,
                    onDismiss: onDismiss
                )
            }
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
            .frame(height: 250)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard dodgeCount < 8, containerSize.width > 0 else { return }
                switch phase {
                case .active(let location):
                    let c = center ?? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                    let dist = hypot(location.x - c.x, location.y - c.y)
                    if dist < 100, !mouseInZone {
                        mouseInZone = true
                        performDodge()
                    } else if dist >= 100 {
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

    private func performDodge() {
        dodgeCount += 1
        let c = center ?? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let angle = Double.random(in: 0 ..< 2 * .pi)
        let r: CGFloat = 150
        var nx = c.x + cos(angle) * r
        var ny = c.y + sin(angle) * r
        nx = max(60, min(containerSize.width - 60, nx))
        ny = max(30, min(containerSize.height - 30, ny))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            center = CGPoint(x: nx, y: ny)
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

// MARK: - Hold

private struct HoldDismissView: View {
    let palette: BreakPalette
    let holdDuration: TimeInterval
    let onDismiss: () -> Void

    @State private var holdProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            Text("Hold to skip")
                .font(BreakTypography.label(size: 12))
                .foregroundStyle(palette.inkFaint)

            ZStack {
                Circle()
                    .stroke(palette.paperEdge, lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(palette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.ink)
            }
            .onLongPressGesture(minimumDuration: holdDuration) {
                onDismiss()
            } onPressingChanged: { pressing in
                if pressing {
                    withAnimation(.linear(duration: holdDuration)) {
                        holdProgress = 1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        holdProgress = 0
                    }
                }
            }
        }
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
    @State private var showSkipConfirmation = false
    @State private var displayPhrase: String
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
            .caseInsensitiveCompare(phrase) == .orderedSame
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
                .frame(width: 320, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.paperEdge, lineWidth: 1)
                )
                .onAppear { isFieldFocused = true }
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
        .task {
            guard escalationTier >= 2 else { return }
            let alternatives = [
                "I love standing up",
                "Taking breaks is great actually",
            ]
            for (i, alt) in alternatives.enumerated() {
                try? await Task.sleep(for: .seconds(4 + i * 10))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayPhrase = alt
                }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayPhrase = phrase
                }
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

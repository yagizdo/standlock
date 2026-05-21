import SwiftUI
import StandLockCore

struct ActionArea: View {
    let level: DisciplineLevel
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let escalationTier: Int
    let onDismiss: () -> Void

    var body: some View {
        switch level {
        case .gentle:
            GentleActionView(palette: palette, escalationTier: escalationTier, onDismiss: onDismiss)
        case .firm:
            FirmActionView(palette: palette, preferences: preferences,
                          statistics: statistics, escalationTier: escalationTier,
                          onDismiss: onDismiss)
        case .strict:
            StrictActionView(palette: palette, preferences: preferences,
                            statistics: statistics, escalationTier: escalationTier)
        }
    }
}

// MARK: - Gentle

private struct GentleActionView: View {
    let palette: BreakPalette
    let escalationTier: Int
    let onDismiss: () -> Void

    @State private var isPressed = false
    @State private var showSkipAction = false
    @State private var holdProgress: CGFloat = 0
    @State private var typedPhrase = ""
    @State private var countdown: Int = 0
    @FocusState private var isFieldFocused: Bool

    private var skipDelay: Int {
        switch escalationTier {
        case 1: 5
        case 2: 10
        default: 15
        }
    }

    var body: some View {
        Group {
            if escalationTier == 0 {
                skipButton(animated: false)
            } else if showSkipAction {
                switch escalationTier {
                case 1: skipButton(animated: true)
                case 2: holdToSkipButton
                default: typeToSkipField
                }
            } else {
                countdownLabel
            }
        }
        .animation(.easeOut(duration: 0.3), value: showSkipAction)
        .task {
            guard escalationTier >= 1 else {
                showSkipAction = true
                return
            }
            countdown = skipDelay
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown -= 1
            }
            showSkipAction = true
        }
    }

    private var countdownLabel: some View {
        Text("Skip available in \(countdown)s")
            .font(BreakTypography.label(size: 12))
            .foregroundStyle(palette.inkFaint)
            .contentTransition(.numericText())
            .animation(.default, value: countdown)
    }

    private func skipButton(animated: Bool) -> some View {
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
        .transition(animated ? .opacity : .identity)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var holdToSkipButton: some View {
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
            .onLongPressGesture(minimumDuration: 2) {
                onDismiss()
            } onPressingChanged: { pressing in
                if pressing {
                    withAnimation(.linear(duration: 2)) {
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

    private var typeToSkipField: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("Write ")
                    .font(BreakTypography.label(size: 12))
                    .tracking(0.15)
                    .foregroundStyle(palette.inkFaint)
                Text("\"skip\"")
                    .font(BreakTypography.exerciseName(size: 12).italic())
                    .foregroundStyle(palette.ink)
                Text(" to dismiss")
                    .font(BreakTypography.label(size: 12))
                    .tracking(0.15)
                    .foregroundStyle(palette.inkFaint)
            }

            TextField("", text: $typedPhrase)
                .font(BreakTypography.exerciseName(size: 16))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 200, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.paperEdge, lineWidth: 1)
                )
                .onAppear { isFieldFocused = true }
                .onChange(of: typedPhrase) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespaces)
                        .caseInsensitiveCompare("skip") == .orderedSame {
                        onDismiss()
                    }
                }
        }
        .transition(.opacity)
    }
}

// MARK: - Firm

private struct FirmActionView: View {
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let escalationTier: Int
    let onDismiss: () -> Void

    @State private var typedPhrase = ""
    @State private var showSkipConfirmation = false
    @State private var showPhraseField = false
    @State private var countdown: Int = 0
    @FocusState private var isFieldFocused: Bool

    private var limitReached: Bool {
        guard !preferences.firmEscalationEnabled else { return false }
        return statistics.breaksSkipped >= preferences.firmDailySkipLimit
    }

    private var effectivePhrase: String {
        escalationTier >= 3
            ? preferences.firmEscapePhrase + " I really mean it"
            : preferences.firmEscapePhrase
    }

    private var phraseMatches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(effectivePhrase) == .orderedSame
    }

    private var tierMultiplier: Double {
        AppPreferences.tierMultiplier(for: escalationTier)
    }

    private var effectiveDelay: Int {
        Int(preferences.firmSkipDelay * tierMultiplier)
    }

    var body: some View {
        if !limitReached && preferences.firmEscapePhrase
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            GentleActionView(palette: palette, escalationTier: 0, onDismiss: onDismiss)
        } else {
            VStack(spacing: 16) {
                if limitReached {
                    Text("Daily skip limit reached")
                        .font(BreakTypography.label(size: 12, weight: .medium))
                        .foregroundStyle(palette.inkFaint)
                } else if showPhraseField {
                    promptLine
                    phraseField
                } else if countdown > 0 {
                    Text("Skip available in \(countdown)s")
                        .font(BreakTypography.label(size: 12))
                        .foregroundStyle(palette.inkFaint)
                        .contentTransition(.numericText())
                        .animation(.default, value: countdown)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showPhraseField)
            .task {
                let total = effectiveDelay
                if total > 0 {
                    countdown = total
                    while countdown > 0 {
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled else { return }
                        countdown -= 1
                    }
                }
                showPhraseField = true
            }
            .onChange(of: phraseMatches) { _, matches in
                if matches {
                    if escalationTier >= 2 {
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
            .onChange(of: showSkipConfirmation) { _, showing in
                if !showing { isFieldFocused = true }
            }
            .onChange(of: showPhraseField) { _, showing in
                if showing { isFieldFocused = true }
            }
        }
    }

    private var promptLine: some View {
        HStack(spacing: 0) {
            Text("Write ")
                .font(BreakTypography.label(size: 12))
                .tracking(0.15)
                .foregroundStyle(palette.inkFaint)
            Text("\"\(effectivePhrase)\"")
                .font(BreakTypography.exerciseName(size: 12).italic())
                .foregroundStyle(palette.ink)
            Text(" to dismiss")
                .font(BreakTypography.label(size: 12))
                .tracking(0.15)
                .foregroundStyle(palette.inkFaint)
        }
    }

    private var phraseField: some View {
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
    }
}

// MARK: - Strict

private struct StrictActionView: View {
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let escalationTier: Int

    private var effectiveHoldDuration: TimeInterval {
        preferences.strictEscapeHoldDuration * AppPreferences.tierMultiplier(for: escalationTier)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
                keycap("⌃")
                keycap("⌥")
                keycap("⌘")
                Text("for \(Int(effectiveHoldDuration)) seconds to exit.")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
            }

            HStack(spacing: 0) {
                Text("Emergency exits this week")
                    .font(BreakTypography.label(size: 11))
                    .foregroundStyle(palette.inkFaint)
                Text(" \u{00B7} ")
                    .foregroundStyle(palette.inkFaint)
                Text("\(statistics.weeklyEscapeCount)")
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

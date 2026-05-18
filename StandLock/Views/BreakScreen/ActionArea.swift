import SwiftUI
import StandLockCore

struct ActionArea: View {
    let level: DisciplineLevel
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let onDismiss: () -> Void

    var body: some View {
        switch level {
        case .gentle:
            GentleActionView(palette: palette, onDismiss: onDismiss)
        case .firm:
            FirmActionView(palette: palette, preferences: preferences,
                          statistics: statistics, onDismiss: onDismiss)
        case .strict:
            StrictActionView(palette: palette, statistics: statistics)
        }
    }
}

// MARK: - Gentle

private struct GentleActionView: View {
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
    }
}

// MARK: - Firm

private struct FirmActionView: View {
    let palette: BreakPalette
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let onDismiss: () -> Void

    @State private var typedPhrase = ""
    @FocusState private var isFieldFocused: Bool

    private var limitReached: Bool {
        statistics.breaksSkipped >= preferences.firmDailySkipLimit
    }

    private var phraseMatches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(preferences.firmEscapePhrase) == .orderedSame
    }

    var body: some View {
        VStack(spacing: 16) {
            if limitReached {
                Text("Daily skip limit reached")
                    .font(BreakTypography.label(size: 12, weight: .medium))
                    .foregroundStyle(palette.inkFaint)
            } else {
                promptLine
                phraseField
            }
        }
        .onChange(of: phraseMatches) { _, matches in
            if matches { onDismiss() }
        }
        .onAppear { isFieldFocused = true }
    }

    private var promptLine: some View {
        HStack(spacing: 0) {
            Text("Write ")
                .font(BreakTypography.label(size: 12))
                .tracking(0.15)
                .foregroundStyle(palette.inkFaint)
            Text("\"\(preferences.firmEscapePhrase)\"")
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
    let statistics: BreakStatistics

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(BreakTypography.label(size: 13))
                    .foregroundStyle(palette.inkSoft)
                keycap("⌃")
                keycap("⌥")
                keycap("⌘")
                Text("for ten seconds to exit.")
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

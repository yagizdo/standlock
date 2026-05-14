import SwiftUI
import StandLockCore

struct BreakContentView: View {
    let level: DisciplineLevel
    let totalDuration: TimeInterval
    let exercise: Exercise?
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let onSkip: () -> Void
    let onComplete: () -> Void

    @State private var remainingSeconds: TimeInterval
    @State private var skipDelayRemaining: TimeInterval
    @State private var typedPhrase: String = ""

    init(
        level: DisciplineLevel, totalDuration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences,
        statistics: BreakStatistics,
        onSkip: @escaping () -> Void, onComplete: @escaping () -> Void
    ) {
        self.level = level
        self.totalDuration = totalDuration
        self.exercise = exercise
        self.preferences = preferences
        self.statistics = statistics
        self.onSkip = onSkip
        self.onComplete = onComplete
        self._remainingSeconds = State(initialValue: totalDuration)
        self._skipDelayRemaining = State(initialValue: preferences.firmSkipDelay)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                levelIndicator

                CountdownView(
                    remainingSeconds: remainingSeconds,
                    totalDuration: totalDuration
                )

                if let exercise {
                    ExerciseSuggestionView(exercise: exercise)
                }

                skipControls

                Spacer()

                statsBar
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
        .task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                remainingSeconds -= 1
                if level == .firm && skipDelayRemaining > 0 {
                    skipDelayRemaining -= 1
                }
                if remainingSeconds <= 0 {
                    onComplete()
                }
            }
        }
    }

    // MARK: - Level Indicator

    private var levelIndicator: some View {
        Text(level.displayName.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .tracking(4)
            .foregroundStyle(levelColor.opacity(0.8))
    }

    // MARK: - Per-Level Skip Controls

    @ViewBuilder
    private var skipControls: some View {
        switch level {
        case .gentle:
            gentleControls
        case .firm:
            firmControls
        case .strict:
            strictControls
        }
    }

    private var gentleControls: some View {
        Button(action: onSkip) {
            Text("Skip Break")
                .font(.body)
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            Capsule().fill(.white.opacity(0.15))
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var firmControls: some View {
        VStack(spacing: 12) {
            if skipDelayRemaining > 0 {
                Text("Skip available in \(Int(skipDelayRemaining))s")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
            } else if statistics.breaksSkipped < preferences.firmDailySkipLimit {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("", text: $typedPhrase, prompt: Text(preferences.firmEscapePhrase).foregroundStyle(.white.opacity(0.3)))
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.08))
                            )
                            .frame(maxWidth: 360)

                        if typedPhrase.lowercased() == preferences.firmEscapePhrase.lowercased() {
                            Button(action: onSkip) {
                                Text("Skip")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(Capsule().fill(.white.opacity(0.15)))
                            .foregroundStyle(.white)
                        }
                    }

                    Text("Type the phrase above to skip")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                Text("Daily skip limit reached")
                    .font(.callout)
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Text("You've skipped \(statistics.breaksSkipped) of \(preferences.firmDailySkipLimit) allowed skips today")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var strictControls: some View {
        VStack(spacing: 8) {
            Text("Hold Ctrl+Option+Cmd for \(Int(preferences.strictEscapeHoldDuration))s for emergency exit")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.5))

            Text("Emergency escapes this week: \(statistics.weeklyEscapeCount)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 32) {
            statItem(icon: "checkmark.circle", label: "Completed", value: "\(statistics.breaksCompleted)")
            statItem(icon: "flame", label: "Streak", value: "\(statistics.currentStreak)")
            statItem(icon: "forward", label: "Skipped", value: "\(statistics.breaksSkipped)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private var levelColor: Color {
        switch level {
        case .gentle: .green
        case .firm: .orange
        case .strict: .red
        }
    }
}

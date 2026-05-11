import SwiftUI
import StandLockCore

struct BreakContentView: View {
    let level: DisciplineLevel
    let totalDuration: TimeInterval
    let exercise: Exercise?
    let preferences: AppPreferences
    let onSkip: () -> Void
    let onComplete: () -> Void

    @State private var remainingSeconds: TimeInterval
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        level: DisciplineLevel, totalDuration: TimeInterval,
        exercise: Exercise?, preferences: AppPreferences,
        onSkip: @escaping () -> Void, onComplete: @escaping () -> Void
    ) {
        self.level = level
        self.totalDuration = totalDuration
        self.exercise = exercise
        self.preferences = preferences
        self.onSkip = onSkip
        self.onComplete = onComplete
        self._remainingSeconds = State(initialValue: totalDuration)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(level.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))

                Text(timeString)
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)

                if let exercise {
                    Text(exercise.title)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer().frame(height: 20)

                skipControls
            }
        }
        .onReceive(timer) { _ in
            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                onComplete()
            }
        }
    }

    @ViewBuilder
    private var skipControls: some View {
        switch level {
        case .gentle:
            Button("Skip Break") { onSkip() }
                .buttonStyle(.bordered)
                .tint(.white)

        case .firm:
            Text("Skip available after delay")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

        case .strict:
            Text("Hold Ctrl+Option+Cmd for \(Int(preferences.strictEscapeHoldDuration))s to exit")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var timeString: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

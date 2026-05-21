import SwiftUI
import StandLockCore

struct ManuscriptBreakView: View {
    let level: DisciplineLevel
    let totalDuration: TimeInterval
    let exercise: Exercise?
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let escalationTier: Int
    let onSkip: () -> Void
    let onComplete: () -> Void

    @State private var remainingSeconds: TimeInterval
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(level: DisciplineLevel, totalDuration: TimeInterval, exercise: Exercise?,
         preferences: AppPreferences, statistics: BreakStatistics,
         escalationTier: Int = 0,
         onSkip: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.level = level
        self.totalDuration = totalDuration
        self.exercise = exercise
        self.preferences = preferences
        self.statistics = statistics
        self.escalationTier = escalationTier
        self.onSkip = onSkip
        self.onComplete = onComplete
        self._remainingSeconds = State(initialValue: totalDuration)
    }

    private var palette: BreakPalette { .for(level) }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 720
            ZStack {
                backgroundGradient(size: geometry.size)
                vignetteOverlays(size: geometry.size)

                VStack(spacing: 0) {
                    WordmarkView(palette: palette)
                        .padding(.top, 40)

                    Spacer()

                    VStack(spacing: compact ? 16 : 24) {
                        LevelPill(level: level, palette: palette)
                        TimerNumerals(
                            remainingSeconds: remainingSeconds,
                            totalDuration: totalDuration,
                            palette: palette,
                            viewportHeight: geometry.size.height,
                            reduceMotion: reduceMotion
                        )
                        if let exercise {
                            ExerciseBlock(exercise: exercise, palette: palette)
                        }
                        ActionArea(
                            level: level, palette: palette,
                            preferences: preferences, statistics: statistics,
                            escalationTier: escalationTier,
                            onDismiss: onSkip
                        )
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    StatsFooter(statistics: statistics, palette: palette)
                        .padding(.bottom, 44)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isVisible ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = true
                }
            }
        }
        .task { await startCountdown() }
    }

    @ViewBuilder
    private func backgroundGradient(size: CGSize) -> some View {
        RadialGradient(
            colors: [palette.paper, palette.paperEdge],
            center: .center,
            startRadius: 0,
            endRadius: max(size.width, size.height)
        )
    }

    @ViewBuilder
    private func vignetteOverlays(size: CGSize) -> some View {
        RadialGradient(
            colors: [Color.black.opacity(0.05), Color.clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: size.width * 0.7
        )
        .allowsHitTesting(false)

        RadialGradient(
            colors: [Color.black.opacity(0.05), Color.clear],
            center: .bottomTrailing,
            startRadius: 0,
            endRadius: size.width * 0.7
        )
        .allowsHitTesting(false)
    }

    private func startCountdown() async {
        while remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            remainingSeconds -= 1
        }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            try? await Task.sleep(for: .milliseconds(300))
        } else {
            isVisible = false
        }
        onComplete()
    }
}

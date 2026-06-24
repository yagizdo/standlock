import SwiftUI
import StandLockCore

struct ManuscriptBreakView: View {
    let level: DisciplineLevel
    let totalDuration: TimeInterval
    let exercise: Exercise?
    let preferences: AppPreferences
    let statistics: BreakStatistics
    let enforcementTier: EnforcementTier
    let escalationTierIndex: Int
    let onSkip: () -> Void
    let onEscape: () -> Void
    let onComplete: () -> Void

    @State private var remainingSeconds: TimeInterval
    @State private var isVisible = false
    @State private var splashTexts: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(level: DisciplineLevel, totalDuration: TimeInterval, exercise: Exercise?,
         preferences: AppPreferences, statistics: BreakStatistics,
         escalationTier: Int = 0,
         onSkip: @escaping () -> Void,
         onEscape: @escaping () -> Void,
         onComplete: @escaping () -> Void) {
        self.level = level
        self.totalDuration = totalDuration
        self.exercise = exercise
        self.preferences = preferences
        self.statistics = statistics
        let policy = level.enforcementPolicy(preferences: preferences)
        self.enforcementTier = policy.tier(at: escalationTier)
        self.escalationTierIndex = escalationTier
        self.onSkip = onSkip
        self.onEscape = onEscape
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
                            tier: enforcementTier, palette: palette,
                            preferences: preferences, statistics: statistics,
                            disciplineLevel: level,
                            escalationTier: escalationTierIndex,
                            onDismiss: onSkip,
                            onEscape: onEscape
                        )
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    StatsFooter(statistics: statistics, palette: palette)
                        .padding(.bottom, 44)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isVisible ? 1 : 0)

                if escalationTierIndex >= 2, !splashTexts.isEmpty {
                    Group {
                        SplashLabel(text: splashTexts[0], palette: palette, rotation: -15)
                            .position(x: geometry.size.width * 0.15, y: geometry.size.height * 0.25)
                        if splashTexts.count > 1 {
                            SplashLabel(text: splashTexts[1], palette: palette, rotation: 12)
                                .position(x: geometry.size.width * 0.83, y: geometry.size.height * 0.35)
                        }
                        if splashTexts.count > 2 {
                            SplashLabel(text: splashTexts[2], palette: palette, rotation: -8)
                                .position(x: geometry.size.width * 0.20, y: geometry.size.height * 0.72)
                        }
                    }
                    .allowsHitTesting(false)
                    .opacity(isVisible ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            if escalationTierIndex >= 2 {
                splashTexts = Array([
                    "Ctrl+Z won't fix your posture",
                    "Two minutes. You'll survive.",
                    "Even CPUs need cooling breaks",
                    "Stretch now, debug later",
                    "Consecutive skip detected",
                    "Screen time: hours. Break time: refused.",
                    "Standing: surprisingly not fatal",
                    "Brief pause. Big difference.",
                    "The chair isn't going anywhere",
                    "You're still here?",
                    "Never gonna give you up",
                    "This is fine.",
                    "One does not simply skip breaks",
                    "I'm in this picture and I don't like it",
                    "Go touch some grass",
                    "git commit -m \"touched grass\"",
                    "sudo stand up",
                    "Have you tried turning yourself off and on?",
                    "It works on my spine",
                    "LGTM. Now stand up.",
                ].shuffled().prefix(3))
            }
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

// MARK: - Splash Label

private struct SplashLabel: View {
    let text: String
    let palette: BreakPalette
    var rotation: Double = -12

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(BreakTypography.label(size: 16, weight: .bold))
            .foregroundStyle(palette.accent)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isPulsing ? 1.06 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

import SwiftUI

struct TimerNumerals: View {
    let remainingSeconds: TimeInterval
    let totalDuration: TimeInterval
    let palette: BreakPalette
    let viewportHeight: CGFloat
    let reduceMotion: Bool

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingSeconds / totalDuration)
    }

    private var timeString: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var fontSize: CGFloat {
        min(220, viewportHeight * 0.22)
    }

    private var progressWidth: CGFloat {
        fontSize * 2.5
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(timeString)
                .font(BreakTypography.timerNumerals(size: fontSize))
                .monospacedDigit()
                .tracking(fontSize * -0.04)
                .foregroundStyle(palette.ink)
                .contentTransition(.identity)
                .transaction { $0.animation = nil }

            progressBar
                .frame(width: progressWidth)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.paperEdge)
                    .frame(height: 1)
                Rectangle()
                    .fill(palette.ink)
                    .frame(width: geo.size.width * progress, height: 3)
                    .offset(y: -1)
            }
        }
        .frame(height: 3)
        .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
    }
}

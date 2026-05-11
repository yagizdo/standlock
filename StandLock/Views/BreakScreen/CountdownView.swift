import SwiftUI

struct CountdownView: View {
    let remainingSeconds: TimeInterval
    let totalDuration: TimeInterval

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1 - remainingSeconds / totalDuration))
    }

    private var timeString: String {
        let mins = Int(max(0, remainingSeconds)) / 60
        let secs = Int(max(0, remainingSeconds)) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 6)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentGradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Text(timeString)
                .font(.system(size: 56, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var accentGradient: AngularGradient {
        AngularGradient(
            colors: [.cyan.opacity(0.8), .blue.opacity(0.6), .cyan.opacity(0.8)],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
}

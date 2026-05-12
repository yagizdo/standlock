import SwiftUI

struct QuickSetupStepView: View {
    var onCreateDefault: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)

            Text("Quick Setup")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start with a recommended schedule, or configure your own later.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Label("Monday – Friday", systemImage: "calendar")
                Label("09:00 – 17:00", systemImage: "clock")
                Label("Break every 45 minutes", systemImage: "timer")
                Label("5 minute breaks", systemImage: "figure.stand")
                Label("Gentle mode", systemImage: "leaf")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            Spacer()

            VStack(spacing: 10) {
                Button("Use Default Schedule") {
                    onCreateDefault()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("I'll configure later") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()
                .frame(height: 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

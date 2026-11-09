import SwiftUI
import Scheduling
import StandLockCore

/// A local wall-time dial: 00:00 is at the top, 12:00 at the bottom, in either app appearance.
struct DayPreviewClock: View {
    let clock: DayClock
    let windows: [TimeWindow]
    let hasLongBreaks: Bool
    @Binding var selection: DayClock.Segment?

    @State private var hovered: DayClock.Segment?
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.locale) private var locale

    private var active: DayClock.Segment? { hovered ?? selection }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SettingsTokens.sectionSpacing) {
                face
                legend
            }
            VStack(alignment: .leading, spacing: SettingsTokens.cardSpacing) {
                face.frame(maxWidth: .infinity)
                legend
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("24-hour work and break schedule")
        .accessibilityValue(accessibilityValue)
        .onChange(of: clock) { _ in hovered = nil }
    }

    private var face: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                VStack(spacing: SettingsTokens.rowTextSpacing) {
                    if let active {
                        Text(title(active.kind))
                            .fontWeight(.medium)
                        Text("\(time(active.start))–\(time(active.end))")
                            .monospacedDigit()
                        Text(duration(active.duration))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("24-hour day")
                            .fontWeight(.medium)
                        if let window = windows.first, windows.count == 1 {
                            Text("\(String(format: "%02d:%02d", window.startHour, window.startMinute))–\(String(format: "%02d:%02d", window.endHour, window.endMinute))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(windows.count) time windows")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(SettingsTokens.descriptionFont)
                .allowsHitTesting(false)

                Image(systemName: "moon")
                    .foregroundStyle(.secondary)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.25)
                Image(systemName: "sun.max")
                    .foregroundStyle(.orange)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.75)
            }
            .contentShape(Circle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): hovered = segment(at: location, size: geometry.size)
                case .ended: hovered = nil
                }
            }
            .gesture(SpatialTapGesture().onEnded { event in
                let tapped = segment(at: event.location, size: geometry.size)
                selection = selection == tapped ? nil : tapped
            })
        }
        .frame(width: 232, height: 232)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.blockSpacing) {
            legendRow(.work)
            legendRow(.shortBreak)
            if hasLongBreaks { legendRow(.longBreak) }
        }
        .font(SettingsTokens.descriptionFont)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func legendRow(_ kind: DayClock.Kind) -> some View {
        HStack(spacing: SettingsTokens.listItemSpacing) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(kind))
                .frame(width: 9, height: 9)
            Text(title(kind, total: true))
            Text(duration(clock.duration(for: kind)))
                .monospacedDigit()
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = size.width * 0.34
        let width = size.width * 0.08
        let track = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(track, with: .color(.secondary.opacity(0.12)), lineWidth: width)

        for tick in 0..<48 {
            let fraction = Double(tick) / 48
            var path = Path()
            path.move(to: point(fraction, radius: radius + width / 2 + 3, center: center))
            path.addLine(to: point(fraction, radius: radius + width / 2 + (tick.isMultiple(of: 6) ? 9 : 5), center: center))
            context.stroke(path, with: .color(.secondary.opacity(0.3)), lineWidth: 1)
        }
        for segment in clock.segments {
            var path = Path()
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(segment.startFraction * 360 - 90),
                        endAngle: .degrees(segment.endFraction * 360 - 90), clockwise: false)
            let opacity = active == nil || active == segment ? 1.0 : 0.45
            context.stroke(path, with: .color(color(segment.kind).opacity(opacity)),
                           style: StrokeStyle(lineWidth: width, lineCap: .butt))
        }
        for hour in stride(from: 0, to: 24, by: 3) {
            let label = Text(String(format: "%02d", hour))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            context.draw(label, at: point(Double(hour) / 24, radius: radius + width / 2 + 21, center: center))
        }
    }

    private func point(_ fraction: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = fraction * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    private func segment(at location: CGPoint, size: CGSize) -> DayClock.Segment? {
        let x = location.x - size.width / 2
        let y = location.y - size.height / 2
        guard abs(hypot(x, y) - size.width * 0.34) <= size.width * 0.04 + 4 else { return nil }
        let angle = (atan2(y, x) + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let seconds = angle / (2 * .pi) * 86400
        return clock.segments.first { $0.start <= seconds && seconds < $0.end }
    }

    private func color(_ kind: DayClock.Kind) -> Color {
        switch kind {
        case .work: .blue
        case .shortBreak: .orange
        case .longBreak: .purple
        }
    }

    private func title(_ kind: DayClock.Kind, total: Bool = false) -> LocalizedStringKey {
        switch kind {
        case .work: "Work"
        case .shortBreak: total ? "Short break time" : "Short break"
        case .longBreak: total ? "Long break time" : "Long break"
        }
    }

    private func time(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        if value.isMultiple(of: 60) {
            return String(format: "%02d:%02d", value / 3600, value % 3600 / 60)
        }
        return String(format: "%02d:%02d:%02d", value / 3600, value % 3600 / 60, value % 60)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        if seconds > 0, seconds < 60 { return languageStore.string("\(Int(seconds.rounded())) sec") }
        if seconds >= 3600 {
            let minutes = Int(seconds / 60)
            if minutes.isMultiple(of: 60) { return languageStore.string("\(minutes / 60) h") }
            return languageStore.string("\(minutes / 60) h \(minutes % 60) min")
        }
        let minutes = (seconds / 60).formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        return languageStore.string("\(minutes) min")
    }

    private var accessibilityValue: String {
        if let active {
            return languageStore.string("\(time(active.start)) to \(time(active.end)), \(duration(active.duration))")
        }
        let work = duration(clock.workDuration), pauses = duration(clock.breakDuration)
        return languageStore.string("Work: \(work). Breaks: \(pauses).")
    }
}

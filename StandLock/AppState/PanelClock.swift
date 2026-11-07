import Combine
import Foundation

/// The menu bar panel's clock: the scene's motion and the countdown both read `now`.
///
/// A `TimelineView` asked for anything faster than once a second follows the display's refresh,
/// and cost the open panel about 7% CPU whether it asked for 4 frames a second or 12. A plain
/// timer wakes only for the ticks it needs: the same scenes ran at 2 to 5%.
@MainActor
final class PanelClock: ObservableObject {
    @Published private(set) var now = Date()

    private var interval: TimeInterval?
    private var ticks: AnyCancellable?

    init(every interval: TimeInterval?) {
        run(every: interval)
    }

    /// Ticks every `interval` seconds from now; nil stops it, for a closed panel.
    func run(every interval: TimeInterval?) {
        guard interval != self.interval else { return }
        self.interval = interval
        ticks = nil
        guard let interval else { return }
        now = Date()
        ticks = Timer.publish(every: interval, tolerance: interval / 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }
}

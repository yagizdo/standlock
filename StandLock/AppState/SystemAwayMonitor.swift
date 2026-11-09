import AppKit
import Coordination
import Detection

/// App-lifetime observation, independent of schedule/coordinator rebuilds.
@MainActor
final class SystemAwayMonitor {
    /// NotificationCenter supports removal from any thread, including object teardown.
    private struct Observation: @unchecked Sendable {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }
    private let reader = ScreenLockStateReader()
    private var observers: [Observation] = []
    private var probe: Task<Void, Never>?
    private var locked: Bool?
    private var sleeping = false
    private var onChange: ((AwaySessionTracker.Reason, Bool) -> Void)?

    func start(onChange: @escaping (AwaySessionTracker.Reason, Bool) -> Void) {
        self.onChange = onChange
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.setSleeping(true) }
        observe(workspace, NSWorkspace.didWakeNotification) {
            $0.reconcileLockState()
            $0.setSleeping(false)
        }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.reconcileLockState() }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.reconcileLockState() }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, .init("com.apple.screenIsLocked")) { $0.setLocked(true) }
        observe(distributed, .init("com.apple.screenIsUnlocked")) { $0.setLocked(false) }
        reconcileLockState()
        probe = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                self?.reconcileLockState()
            }
        }
    }

    func synchronize(_ coordinator: BreakCoordinator) {
        if let locked {
            locked ? coordinator.handleScreenLock() : coordinator.handleScreenUnlock()
        }
        sleeping ? coordinator.handleSystemSleep() : coordinator.handleSystemWake()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping @MainActor (SystemAwayMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        observers.append(Observation(center: center, token: token))
    }

    private func reconcileLockState() {
        if let value = reader.isLocked() { setLocked(value) }
    }

    private func setLocked(_ value: Bool) {
        guard locked != value else { return }
        locked = value
        onChange?(.locked, value)
    }

    private func setSleeping(_ value: Bool) {
        guard sleeping != value else { return }
        sleeping = value
        onChange?(.sleeping, value)
    }

    deinit {
        probe?.cancel()
        for observation in observers { observation.center.removeObserver(observation.token) }
    }
}

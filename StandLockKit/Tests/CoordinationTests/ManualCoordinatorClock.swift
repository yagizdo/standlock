import Foundation
import Coordination

final class ManualCoordinatorClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    private var seconds: TimeInterval = 0
    private var waiters: [UUID: (TimeInterval, CheckedContinuation<Void, Error>)] = [:]
    private var cancelled: Set<UUID> = []

    init() {
        date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
    }

    var clock: CoordinatorClock {
        CoordinatorClock(now: { self.lock.withLock { self.date } },
                         elapsed: { self.lock.withLock { self.seconds } },
                         sleep: { try await self.sleep($0) })
    }

    func advance(_ duration: TimeInterval) {
        let ready: [CheckedContinuation<Void, Error>] = lock.withLock {
            seconds += duration
            date.addTimeInterval(duration)
            let ready = waiters.filter { $0.value.0 <= seconds }
            for id in ready.keys { waiters.removeValue(forKey: id) }
            return ready.values.map(\.1)
        }
        for continuation in ready { continuation.resume() }
    }

    private func sleep(_ duration: TimeInterval) async throws {
        let id = UUID()
        let deadline = lock.withLock { seconds + max(0, duration) }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let result = lock.withLock { () -> Int in
                    if cancelled.remove(id) != nil || Task.isCancelled { return -1 }
                    if deadline <= seconds { return 1 }
                    waiters[id] = (deadline, continuation)
                    return 0
                }
                if result == -1 { continuation.resume(throwing: CancellationError()) }
                if result == 1 { continuation.resume() }
            }
        } onCancel: {
            let continuation = self.lock.withLock {
                self.cancelled.insert(id)
                return self.waiters.removeValue(forKey: id)?.1
            }
            continuation?.resume(throwing: CancellationError())
        }
    }
}

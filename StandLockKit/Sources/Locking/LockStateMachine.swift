import Foundation
import StandLockCore

public enum LockState: Sendable, Equatable {
    case idle
    case active(level: DisciplineLevel, remainingSeconds: TimeInterval)
    case skipAvailable
    case dismissed(outcome: LockOutcome)
}

public enum LockOutcome: Sendable, Equatable {
    case completed
    case skipped
    case escaped
}

public enum LockEvent: Sendable {
    case activate(level: DisciplineLevel, duration: TimeInterval)
    case tick(elapsed: TimeInterval)
    case skipRequested
    case phraseTyped(correct: Bool)
    case escapeTriggered
    case timerExpired
}

public struct LockStateMachine: Sendable {
    public private(set) var state: LockState = .idle
    public private(set) var currentLevel: DisciplineLevel?
    public private(set) var totalDuration: TimeInterval = 0
    public private(set) var elapsedTime: TimeInterval = 0
    public let skipDelay: TimeInterval
    public let escapePhrase: String
    public let dailySkipLimit: Int
    public private(set) var dailySkipCount: Int = 0

    public init(
        skipDelay: TimeInterval = 10,
        escapePhrase: String = "I choose to skip this break",
        dailySkipLimit: Int = 5
    ) {
        self.skipDelay = skipDelay
        self.escapePhrase = escapePhrase
        self.dailySkipLimit = dailySkipLimit
    }

    public mutating func handle(_ event: LockEvent) {
        switch (state, event) {
        case (_, .activate(let level, let duration)):
            currentLevel = level
            totalDuration = duration
            elapsedTime = 0
            state = .active(level: level, remainingSeconds: duration)

        case (.active(let level, _), .tick(let elapsed)):
            elapsedTime += elapsed
            let remaining = max(0, totalDuration - elapsedTime)
            if remaining <= 0 {
                state = .dismissed(outcome: .completed)
                return
            }
            if level == .firm && elapsedTime >= skipDelay && dailySkipCount < dailySkipLimit {
                state = .skipAvailable
            } else {
                state = .active(level: level, remainingSeconds: remaining)
            }

        case (.active(.gentle, _), .skipRequested):
            dailySkipCount += 1
            state = .dismissed(outcome: .skipped)

        case (.active(.firm, _), .phraseTyped(let correct)):
            if correct && dailySkipCount < dailySkipLimit {
                dailySkipCount += 1
                state = .dismissed(outcome: .skipped)
            }

        case (.skipAvailable, .skipRequested):
            dailySkipCount += 1
            state = .dismissed(outcome: .skipped)

        case (.skipAvailable, .tick(let elapsed)):
            elapsedTime += elapsed
            let remaining = max(0, totalDuration - elapsedTime)
            if remaining <= 0 {
                state = .dismissed(outcome: .completed)
                return
            }
            if dailySkipCount >= dailySkipLimit {
                state = .active(level: .firm, remainingSeconds: remaining)
            }

        case (_, .escapeTriggered) where currentLevel == .strict:
            state = .dismissed(outcome: .escaped)

        case (_, .timerExpired):
            state = .dismissed(outcome: .completed)

        default:
            break
        }
    }

    public mutating func resetDailySkipCount() {
        dailySkipCount = 0
    }
}

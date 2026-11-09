import Foundation
import Testing
@testable import StandLockCore

@Suite("Pomodoro Session")
struct PomodoroSessionTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let config = PomodoroConfiguration.standard

    static func session(_ phase: PomodoroPhase, endingAt end: Date = start) -> PomodoroSession {
        var session = PomodoroSession.start(at: start, configuration: config)
        session.phase = phase
        session.phaseEnd = end
        return session
    }

    // MARK: - Configuration

    @Test func standardIsTwentyFiveFiveFifteenFour() {
        #expect(Self.config.focus == TimeInterval(1500))
        #expect(Self.config.shortBreak == TimeInterval(300))
        #expect(Self.config.longBreak == TimeInterval(900))
        #expect(Self.config.rounds == 4)
    }

    @Test func decodesEmptyObjectToStandard() throws {
        let decoded = try JSONDecoder().decode(PomodoroConfiguration.self, from: Data("{}".utf8))
        #expect(decoded == .standard)
    }

    @Test func standardIsWithinBounds() {
        #expect(Self.config.isWithinBounds)
    }

    @Test(arguments: [
        PomodoroConfiguration(focus: 0, shortBreak: 300, longBreak: 900, rounds: 4),
        PomodoroConfiguration(focus: 181 * 60, shortBreak: 300, longBreak: 900, rounds: 4),
        PomodoroConfiguration(focus: 1500, shortBreak: 61 * 60, longBreak: 900, rounds: 4),
        PomodoroConfiguration(focus: 1500, shortBreak: 300, longBreak: .nan, rounds: 4),
        PomodoroConfiguration(focus: 1500, shortBreak: 300, longBreak: 900, rounds: 0),
        PomodoroConfiguration(focus: 1500, shortBreak: 300, longBreak: 900, rounds: 13),
    ])
    func outOfRangeValuesAreOutOfBounds(config: PomodoroConfiguration) {
        #expect(!config.isWithinBounds)
    }

    // MARK: - Phases

    @Test func startBeginsFocusOneEndingAfterFocusLength() {
        let session = PomodoroSession.start(at: Self.start, configuration: Self.config)
        #expect(session.phase == .focus(round: 1))
        #expect(session.phaseEnd == Self.start.addingTimeInterval(1500))
        #expect(session.startedAt == Self.start)
        #expect(session.focusSecondsDone == TimeInterval(0))
    }

    @Test func focusNGoesToShortBreak() throws {
        let now = Self.start.addingTimeInterval(1500)
        let next = try #require(Self.session(.focus(round: 2)).next(at: now))
        #expect(next.phase == .shortBreak(afterRound: 2))
        #expect(next.phaseEnd == now.addingTimeInterval(300))
    }

    @Test func focusFourGoesToLongBreak() throws {
        let next = try #require(Self.session(.focus(round: 4)).next(at: Self.start))
        #expect(next.phase == .longBreak)
        #expect(next.phaseEnd == Self.start.addingTimeInterval(900))
    }

    @Test func shortBreakGoesToNextFocus() throws {
        let next = try #require(Self.session(.shortBreak(afterRound: 2)).next(at: Self.start))
        #expect(next.phase == .focus(round: 3))
        #expect(next.phaseEnd == Self.start.addingTimeInterval(1500))
    }

    @Test func longBreakEndsSession() {
        #expect(Self.session(.longBreak).next(at: Self.start) == nil)
    }

    @Test func oneRoundGoesStraightToLongBreak() throws {
        var session = PomodoroSession.start(at: Self.start, configuration: Self.config)
        session.configuration.rounds = 1
        #expect(try #require(session.next(at: Self.start)).phase == .longBreak)
    }

    @Test func focusSecondsDoneAddsOnlyCompletedFocus() throws {
        let afterFocus = try #require(Self.session(.focus(round: 1)).next(at: Self.start))
        #expect(afterFocus.focusSecondsDone == TimeInterval(1500))
        let afterBreak = try #require(afterFocus.next(at: Self.start))
        #expect(afterBreak.focusSecondsDone == TimeInterval(1500))
    }

    // MARK: - Catch up

    @Test func catchUpStillInFocusChangesNothing() {
        let session = Self.session(.focus(round: 1), endingAt: Self.start.addingTimeInterval(600))
        let result = session.catchUp(awayFrom: Self.start, to: Self.start.addingTimeInterval(300))
        #expect(result == .unchanged)
    }

    @Test func catchUpAwayCoveringWholeBreakCreditsIt() {
        // Focus ends 10 min into a 20 min absence: the 5 min break is covered.
        let session = Self.session(.focus(round: 1), endingAt: Self.start.addingTimeInterval(600))
        let back = Self.start.addingTimeInterval(1200)
        guard case .creditedBreaks(let count, let next?) = session.catchUp(awayFrom: Self.start, to: back) else {
            Issue.record("expected a credited break with a session")
            return
        }
        #expect(count == 1)
        #expect(next.phase == .focus(round: 2))
        #expect(next.phaseEnd == back.addingTimeInterval(1500))
        #expect(next.focusSecondsDone == TimeInterval(1500))
    }

    @Test func catchUpBreakPartlyCoveredOpensWithRemaining() {
        // Two minutes away, focus ended during them: three minutes of the break are left.
        let session = Self.session(.focus(round: 1), endingAt: Self.start.addingTimeInterval(60))
        let back = Self.start.addingTimeInterval(120)
        guard case .openBreak(let remaining, let next) = session.catchUp(awayFrom: Self.start, to: back) else {
            Issue.record("expected an open break")
            return
        }
        #expect(remaining == TimeInterval(180))
        #expect(next.phase == .shortBreak(afterRound: 1))
        #expect(next.phaseEnd == back.addingTimeInterval(180))
    }

    @Test func catchUpBreakEndedWhileAwayCreditsIt() {
        let session = Self.session(.shortBreak(afterRound: 1), endingAt: Self.start.addingTimeInterval(60))
        let back = Self.start.addingTimeInterval(120)
        guard case .creditedBreaks(1, let next?) = session.catchUp(awayFrom: Self.start, to: back) else {
            Issue.record("expected a credited break with a session")
            return
        }
        #expect(next.phase == .focus(round: 2))
        #expect(next.phaseEnd == back.addingTimeInterval(1500))
    }

    @Test func catchUpPastLongBreakFinishesSession() {
        let lastFocus = Self.session(.focus(round: 4), endingAt: Self.start.addingTimeInterval(60))
        #expect(lastFocus.catchUp(awayFrom: Self.start, to: Self.start.addingTimeInterval(3600)) == .creditedBreaks(count: 1, session: nil))
        let longBreak = Self.session(.longBreak, endingAt: Self.start.addingTimeInterval(60))
        #expect(longBreak.catchUp(awayFrom: Self.start, to: Self.start.addingTimeInterval(120)) == .creditedBreaks(count: 1, session: nil))
    }

    @Test func decodesSessionSavedWithoutFocusSeconds() throws {
        let saved = PomodoroSession.start(at: Self.start, configuration: Self.config)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        object["focusSecondsDone"] = nil
        let decoded = try JSONDecoder().decode(PomodoroSession.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded == saved)
    }

    // MARK: - Status

    @Test func statusRoundOfShortBreakIsNextFocus() {
        let status = PomodoroStatus(session: Self.session(.shortBreak(afterRound: 2)), level: .firm)
        #expect(status.round == 3)
        #expect(status.rounds == 4)
        #expect(status.level == .firm)
        #expect(status.phaseEnd == Self.start)
    }

    @Test func chipForShortBreakShowsFinishedRound() {
        let status = PomodoroStatus(session: Self.session(.shortBreak(afterRound: 2)), level: .gentle)
        #expect(status.chip == PomodoroChip(round: 2, rounds: 4, isLong: false))
    }

    @Test func chipForLongBreakIsLong() {
        let status = PomodoroStatus(session: Self.session(.longBreak), level: .gentle)
        #expect(status.chip?.isLong == true)
    }

    @Test func focusHasNoChip() {
        #expect(PomodoroStatus(session: Self.session(.focus(round: 1)), level: .gentle).chip == nil)
    }
}

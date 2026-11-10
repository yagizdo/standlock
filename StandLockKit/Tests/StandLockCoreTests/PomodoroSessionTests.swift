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

    @Test func focusElapsedIsTheTimeTheFocusRan() {
        let focus = Self.session(.focus(round: 1), endingAt: Self.start.addingTimeInterval(1500))
        #expect(focus.focusElapsed(at: Self.start) == TimeInterval(0))
        #expect(focus.focusElapsed(at: Self.start.addingTimeInterval(600)) == TimeInterval(600))
        #expect(focus.focusElapsed(at: Self.start.addingTimeInterval(9000)) == TimeInterval(1500))
        // A clock set back before the start counts nothing, never a negative.
        #expect(focus.focusElapsed(at: Self.start.addingTimeInterval(-3600)) == TimeInterval(0))
        #expect(Self.session(.shortBreak(afterRound: 1)).focusElapsed(at: Self.start) == TimeInterval(0))
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

    @Test func configurationWithoutCoverDecodesToBreaks() throws {
        let json = #"{"focus":1500,"shortBreak":300,"longBreak":900,"rounds":4}"#
        let decoded = try JSONDecoder().decode(PomodoroConfiguration.self, from: Data(json.utf8))
        #expect(decoded.cover == .breaks)
        #expect(decoded == .standard)
    }

    @Test func unknownCoverDecodesToBreaks() throws {
        let json = #"{"focus":1500,"shortBreak":300,"longBreak":900,"rounds":4,"cover":"sideways"}"#
        let decoded = try JSONDecoder().decode(PomodoroConfiguration.self, from: Data(json.utf8))
        #expect(decoded.cover == .breaks)
    }

    @Test func focusCoverRefusesFocusOverAnHour() {
        #expect(!PomodoroConfiguration(focus: 61 * 60, shortBreak: 300, longBreak: 900, rounds: 4, cover: .focus).isWithinBounds)
        #expect(PomodoroConfiguration(focus: 60 * 60, shortBreak: 300, longBreak: 900, rounds: 4, cover: .focus).isWithinBounds)
    }

    @Test func breaksCoverKeepsThreeHourFocus() {
        #expect(PomodoroConfiguration(focus: 180 * 60, shortBreak: 300, longBreak: 900, rounds: 4, cover: .breaks).isWithinBounds)
    }

    @Test func settingFocusCoverPullsFocusIntoRange() {
        var config = PomodoroConfiguration(focus: 180 * 60, shortBreak: 300, longBreak: 900, rounds: 4)
        config.setCover(.focus)
        #expect(config.cover == .focus)
        #expect(config.focus == TimeInterval(60 * 60))
        config.setCover(.breaks)
        #expect(config.cover == .breaks)
        #expect(config.focus == TimeInterval(60 * 60))
    }

    // MARK: - Phases

    @Test func startBeginsFocusOneEndingAfterFocusLength() {
        let session = PomodoroSession.start(at: Self.start, configuration: Self.config)
        #expect(session.phase == .focus(round: 1))
        #expect(session.phaseEnd == Self.start.addingTimeInterval(1500))
        #expect(session.startedAt == Self.start)
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

    /// Earlier builds of this branch saved a running focus total; the key is ignored now.
    @Test func decodesSessionSavedWithFocusSeconds() throws {
        let saved = PomodoroSession.start(at: Self.start, configuration: Self.config)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        object["focusSecondsDone"] = 1500
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

@Suite("Pomodoro restore bounds")
struct PomodoroRestoreBoundsTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func sessionInsideBoundsIsKept() {
        let session = PomodoroSessionTests.session(.focus(round: 2), endingAt: Self.now.addingTimeInterval(600))
        #expect(session.bounded(now: Self.now) == session)
    }

    @Test func zeroLengthFocusIsDropped() {
        var session = PomodoroSessionTests.session(.focus(round: 1))
        session.configuration.focus = 0
        #expect(session.bounded(now: Self.now) == nil)
    }

    @Test(arguments: [
        PomodoroPhase.focus(round: 0), .focus(round: 5), .shortBreak(afterRound: 0), .shortBreak(afterRound: 4),
    ])
    func roundOutsideTheSessionIsDropped(phase: PomodoroPhase) {
        #expect(PomodoroSessionTests.session(phase).bounded(now: Self.now) == nil)
    }

    @Test func clockSetBackCannotStretchAPhase() {
        let session = PomodoroSessionTests.session(.shortBreak(afterRound: 1), endingAt: Self.now.addingTimeInterval(86_400))
        #expect(session.bounded(now: Self.now)?.phaseEnd == Self.now.addingTimeInterval(5 * 60))
    }
}

@Suite("Pomodoro level")
struct PomodoroLevelTests {
    @Test func strictestEnabledLevelWins() {
        #expect(DisciplineLevel.strictest(of: [.gentle, .strict, .firm]) == .strict)
        #expect(DisciplineLevel.strictest(of: [.gentle, .firm]) == .firm)
    }

    @Test func noScheduleMeansGentle() {
        #expect(DisciplineLevel.strictest(of: []) == .gentle)
    }
}

@Suite("Pomodoro relaunch")
struct PomodoroRelaunchTests {
    @Test func sessionFromTodayIsRestorable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let session = PomodoroSessionTests.session(.focus(round: 1))
        #expect(session.isRestorable(now: PomodoroSessionTests.start.addingTimeInterval(3600), calendar: calendar))
        #expect(!session.isRestorable(now: PomodoroSessionTests.start.addingTimeInterval(86_400), calendar: calendar))
    }
}

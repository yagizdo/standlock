import Foundation
import Testing
@testable import StandLockCore

@Suite("Menu Scene Tests")
struct MenuSceneTests {

    private let now = Date(timeIntervalSince1970: 10_000)

    private func look(_ state: NextBreakState) -> MenuSceneLook {
        MenuSceneLook(state: state, now: now)
    }

    private func look(secondsLeft: TimeInterval) -> MenuSceneLook {
        look(.countingDown(to: now.addingTimeInterval(secondsLeft)))
    }

    @Test func aCountdownOverAMinuteIsWorking() {
        #expect(look(secondsLeft: 25 * 60) == .working)
        #expect(look(secondsLeft: 61) == .working)
    }

    @Test func theLastMinuteIsBreakSoon() {
        #expect(look(secondsLeft: 60) == .breakSoon)
        #expect(look(secondsLeft: 1) == .breakSoon)
        #expect(look(secondsLeft: 0) == .breakSoon)
    }

    @Test func aBreakPastItsTimeIsStillBreakSoon() {
        #expect(look(secondsLeft: -5) == .breakSoon)
    }

    @Test func theLookTurnsWithTheDigitsOnScreen() {
        // 60.4 s shows as 1:00, so it has to read as the last minute.
        #expect(look(secondsLeft: 60.4) == .breakSoon)
        #expect(look(secondsLeft: 60.6) == .working)
    }

    @Test func everyOtherStateHasItsOwnLook() {
        #expect(look(.breakActive) == .timeToStand)
        #expect(look(.paused(until: now)) == .paused)
        #expect(look(.deferred(.cameraActive)) == .breakWaiting)
        #expect(look(.noSchedules) == .noSchedules)
        #expect(look(.noActiveSchedules) == .noSchedules)
    }

    @Test func savedPreferencesFromAnOlderVersionGetTheHourglass() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(decoded.menuScene == .hourglass)
    }

    @Test func aSceneThisBuildDoesNotKnowKeepsTheOtherPreferences() throws {
        let json = #"{"menuScene":"lighthouse","menuBarCountdownMinutes":3}"#
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))
        #expect(decoded.menuScene == .hourglass)
        #expect(decoded.menuBarCountdownMinutes == 3)
    }

    @Test func aChosenSceneSurvivesARoundTrip() throws {
        let data = try JSONEncoder().encode(AppPreferences(menuScene: .desk))
        #expect(try JSONDecoder().decode(AppPreferences.self, from: data).menuScene == .desk)
    }
}

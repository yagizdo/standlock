import Foundation
import Testing
@testable import StandLockCore

@Suite("Update Status Tests")
struct UpdateStatusTests {

    private let date = Date(timeIntervalSince1970: 1_000)

    @Test func aFoundUpdateNamesItsVersion() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date
        )
        #expect(status == .available(version: "1.2"))
    }

    @Test func aFoundUpdateWinsOverAnEarlierUpToDateResult() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: true, lastCheckDate: date
        )
        #expect(status == .available(version: "1.2"))
    }

    @Test func aFinishedCheckThatFoundNothingIsUpToDate() {
        let status = UpdateStatus(
            availableVersion: nil, onLatestVersion: true, lastCheckDate: date
        )
        #expect(status == .upToDate)
    }

    @Test func theResultDoesNotDependOnTheDate() {
        let status = UpdateStatus(
            availableVersion: nil, onLatestVersion: true, lastCheckDate: nil
        )
        #expect(status == .upToDate)
    }

    @Test func aDateAloneClaimsNothingAboutTheVersion() {
        let status = UpdateStatus(
            availableVersion: nil, onLatestVersion: false, lastCheckDate: date
        )
        #expect(status == .checked)
    }

    @Test func noFactsMeansNeverChecked() {
        let status = UpdateStatus(
            availableVersion: nil, onLatestVersion: false, lastCheckDate: nil
        )
        #expect(status == .neverChecked)
    }

    @Test func aRunningUpgradeBeatsAnAvailableVersion() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date,
            homebrewUpgrade: .running
        )
        #expect(status == .upgrading)
    }

    @Test func aFinishedUpgradeWaitingToRestartBeatsAnAvailableVersion() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date,
            homebrewUpgrade: .waitingToRestart
        )
        #expect(status == .upgradeWaiting)
    }

    @Test func aBlockedUpgradeBeatsAnAvailableVersion() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date,
            homebrewUpgrade: .blocked
        )
        #expect(status == .upgradeBlocked)
    }

    @Test func aFailedUpgradeBeatsAnAvailableVersion() {
        let status = UpdateStatus(
            availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date,
            homebrewUpgrade: .failed
        )
        #expect(status == .upgradeFailed)
    }

    @Test func anIdleUpgradeLeavesTheCheckResultAlone() {
        let status = UpdateStatus(
            availableVersion: nil, onLatestVersion: true, lastCheckDate: date,
            homebrewUpgrade: .idle
        )
        #expect(status == .upToDate)
    }

    @Test func onlyARunningOrWaitingUpgradeIsBusy() {
        #expect(HomebrewUpgradeState.running.isBusy)
        #expect(HomebrewUpgradeState.waitingToRestart.isBusy)
        #expect(!HomebrewUpgradeState.idle.isBusy)
        #expect(!HomebrewUpgradeState.blocked.isBusy)
        #expect(!HomebrewUpgradeState.failed.isBusy)
    }
}

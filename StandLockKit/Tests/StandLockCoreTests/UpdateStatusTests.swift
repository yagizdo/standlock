import Foundation
import Testing
@testable import StandLockCore

@Suite("Update Status Tests")
struct UpdateStatusTests {

    private let date = Date(timeIntervalSince1970: 1_000)

    @Test func aFoundUpdateNamesItsVersion() {
        let status = UpdateStatus(
            updateAvailable: true, availableVersion: "1.2", onLatestVersion: false, lastCheckDate: date
        )
        #expect(status == .available(version: "1.2"))
    }

    @Test func aFoundUpdateWithNoVersionStillShows() {
        let status = UpdateStatus(
            updateAvailable: true, availableVersion: nil, onLatestVersion: false, lastCheckDate: date
        )
        #expect(status == .available(version: nil))
    }

    @Test func aFoundUpdateWinsOverAnEarlierUpToDateResult() {
        let status = UpdateStatus(
            updateAvailable: true, availableVersion: "1.2", onLatestVersion: true, lastCheckDate: date
        )
        #expect(status == .available(version: "1.2"))
    }

    @Test func aFinishedCheckThatFoundNothingIsUpToDate() {
        let status = UpdateStatus(
            updateAvailable: false, availableVersion: nil, onLatestVersion: true, lastCheckDate: date
        )
        #expect(status == .upToDate)
    }

    @Test func theResultDoesNotDependOnTheDate() {
        let status = UpdateStatus(
            updateAvailable: false, availableVersion: nil, onLatestVersion: true, lastCheckDate: nil
        )
        #expect(status == .upToDate)
    }

    @Test func aDateAloneClaimsNothingAboutTheVersion() {
        let status = UpdateStatus(
            updateAvailable: false, availableVersion: nil, onLatestVersion: false, lastCheckDate: date
        )
        #expect(status == .checked)
    }

    @Test func noFactsMeansNeverChecked() {
        let status = UpdateStatus(
            updateAvailable: false, availableVersion: nil, onLatestVersion: false, lastCheckDate: nil
        )
        #expect(status == .neverChecked)
    }
}

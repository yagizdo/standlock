import Foundation
import Testing
@testable import StandLockCore

@Suite("SettingsPage Tests")
struct SettingsPageTests {

    @Test func casesAreDistinct() {
        let id = UUID()
        let pages: Set<SettingsPage> = [.general, .menuBar, .breakScreen, .discipline, .schedule(id), .schedule(UUID()), .newSchedule, .detection, .permissions, .statistics, .about]
        #expect(pages.count == 11)
        #expect(SettingsPage.schedule(id) == .schedule(id))
    }

    @Test func aLiveScheduleStaysSelected() {
        let live = UUID()
        #expect(SettingsPage.schedule(live).resolved(scheduleIDs: [UUID(), live]) == .schedule(live))
    }

    @Test func aDeletedScheduleMovesToTheFirstOneLeft() {
        let first = UUID()
        #expect(SettingsPage.schedule(UUID()).resolved(scheduleIDs: [first, UUID()]) == .schedule(first))
    }

    @Test func aDeletedLastScheduleMovesToNewSchedule() {
        #expect(SettingsPage.schedule(UUID()).resolved(scheduleIDs: []) == .newSchedule)
    }

    @Test func otherPagesAreLeftAlone() {
        #expect(SettingsPage.detection.resolved(scheduleIDs: []) == .detection)
        #expect(SettingsPage.newSchedule.resolved(scheduleIDs: [UUID()]) == .newSchedule)
    }

    @Test func firstScheduleFallsBackToNewSchedule() {
        let first = UUID()
        #expect(SettingsPage.firstSchedule(in: [first, UUID()]) == .schedule(first))
        #expect(SettingsPage.firstSchedule(in: []) == .newSchedule)
    }

    @Test func leavingAsksOnlyWithUnsavedEdits() {
        let page = SettingsPage.schedule(UUID())
        #expect(page.leaving(to: .general, hasUnsavedEdits: true) == .ask)
        #expect(page.leaving(to: .general, hasUnsavedEdits: false) == .go)
    }

    @Test func leavingForTheSamePageDoesNothing() {
        let page = SettingsPage.schedule(UUID())
        #expect(page.leaving(to: page, hasUnsavedEdits: true) == .stay)
        #expect(page.leaving(to: page, hasUnsavedEdits: false) == .stay)
    }
}

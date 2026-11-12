import Testing
@testable import StandLockCore

@Suite("Permission Attention Tests")
struct PermissionAttentionTests {

    private func schedule(enabled: Bool = true, level: DisciplineLevel) -> Schedule {
        Schedule(
            name: "Work", isEnabled: enabled, days: .everyDay, windows: [],
            breakInterval: 3600, breakDuration: 300, disciplineLevel: level
        )
    }

    @Test func enabledStrictWithThePermissionMissingNeedsIt() {
        #expect(scheduleNeedsStrictPermission(schedule(level: .strict), strictAvailable: false))
    }

    @Test func enabledStrictWithThePermissionAvailableDoesNot() {
        #expect(!scheduleNeedsStrictPermission(schedule(level: .strict), strictAvailable: true))
    }

    @Test func disabledStrictDoesNot() {
        #expect(!scheduleNeedsStrictPermission(schedule(enabled: false, level: .strict), strictAvailable: false))
    }

    @Test(arguments: [DisciplineLevel.gentle, .firm])
    func otherLevelsDoNot(level: DisciplineLevel) {
        #expect(!scheduleNeedsStrictPermission(schedule(level: level), strictAvailable: false))
    }

    @Test func usesStrictNeedsAnEnabledStrictSchedule() {
        #expect(!scheduleUsesStrict(schedule(enabled: false, level: .strict)))
        #expect(!scheduleUsesStrict(schedule(level: .firm)))
    }
}

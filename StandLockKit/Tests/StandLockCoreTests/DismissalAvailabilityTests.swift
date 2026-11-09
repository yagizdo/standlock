import Testing
@testable import StandLockCore

@Suite("Dismissal availability")
struct DismissalAvailabilityTests {
    @Test func capBlocksEveryDismissalAtBoundary() {
        let result = DismissalAvailability(progressiveEnforcement: true, consecutiveSkipLimit: 2,
            consecutiveDismissals: 2, dailySkipLimit: 5, dailySkips: 0)
        #expect(!result.normalSkipAllowed)
        #expect(!result.emergencyEscapeAllowed)
        #expect(result.remainingConsecutiveSkips == 0)
    }

    @Test func dailyQuotaStillAllowsEmergencyExit() {
        let result = DismissalAvailability(progressiveEnforcement: true, consecutiveSkipLimit: 2,
            consecutiveDismissals: 1, dailySkipLimit: 1, dailySkips: 1)
        #expect(!result.normalSkipAllowed)
        #expect(result.emergencyEscapeAllowed)
        #expect(result.remainingConsecutiveSkips == 1)
    }

    @Test func disabledProgressiveEnforcementIgnoresCap() {
        let result = DismissalAvailability(progressiveEnforcement: false, consecutiveSkipLimit: 2,
            consecutiveDismissals: 20, dailySkipLimit: nil, dailySkips: 0)
        #expect(result.normalSkipAllowed && result.emergencyEscapeAllowed)
        #expect(result.remainingConsecutiveSkips == nil)
    }
}

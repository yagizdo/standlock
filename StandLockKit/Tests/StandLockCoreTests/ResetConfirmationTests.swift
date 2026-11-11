import Testing
@testable import StandLockCore

@Suite("Reset Confirmation")
struct ResetConfirmationTests {

    @Test func acceptsThePhraseInAnyCaseWithSurroundingSpace() {
        #expect(ResetConfirmation.matches("StandLock"))
        #expect(ResetConfirmation.matches("standlock"))
        #expect(ResetConfirmation.matches("  STANDLOCK\n"))
    }

    @Test func refusesEmptyAndNearMisses() {
        #expect(!ResetConfirmation.matches(""))
        #expect(!ResetConfirmation.matches("   "))
        #expect(!ResetConfirmation.matches("StandLoc"))
        #expect(!ResetConfirmation.matches("Stand Lock"))
    }
}

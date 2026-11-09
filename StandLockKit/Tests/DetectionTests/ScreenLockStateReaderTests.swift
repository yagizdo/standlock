import Testing
@testable import Detection

@Suite("Screen lock snapshots")
struct ScreenLockStateReaderTests {
    @Test func missingSnapshotDoesNotInventAState() {
        #expect(ScreenLockStateReader.isLocked(in: nil) == nil)
        #expect(ScreenLockStateReader.isLocked(in: [:]) == nil)
    }

    @Test func validSessionsDistinguishLockedUnlockedAndUnknown() {
        #expect(ScreenLockStateReader.isLocked(in: ["CGSSessionScreenIsLocked": true]) == true)
        #expect(ScreenLockStateReader.isLocked(in: ["CGSSessionScreenIsLocked": false]) == false)
        #expect(ScreenLockStateReader.isLocked(in: ["kCGSSessionUserIDKey": 501]) == false)
        #expect(ScreenLockStateReader.isLocked(in: ["CGSSessionScreenIsLocked": "unknown"]) == nil)
    }
}

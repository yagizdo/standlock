import Testing
@testable import Detection

@Suite("ScreenSharingDetector Tests")
struct ScreenSharingDetectorTests {
    @Test func returnsFalseWhenNoSharingProcesses() async {
        let detector = ScreenSharingDetector()
        let result = await detector.isScreenBeingShared()
        #expect(!result)
    }
}

import Testing
@testable import Detection

@Suite("ScreenSharingDetector Tests")
struct ScreenSharingDetectorTests {
    @Test func returnsFalseWhenNoSharingProcesses() async {
        let detector = ScreenSharingDetector(processNames: { ["Finder", "Safari", "Xcode"] })
        let result = await detector.isScreenBeingShared()
        #expect(!result)
    }

    @Test func returnsTrueWhenScreensharingAgentRunning() async {
        let detector = ScreenSharingDetector(processNames: { ["Finder", "ScreensharingAgent", "Xcode"] })
        let result = await detector.isScreenBeingShared()
        #expect(result)
    }

    @Test func returnsTrueWhenScreencaptureuiRunning() async {
        let detector = ScreenSharingDetector(processNames: { ["Finder", "screencaptureui"] })
        let result = await detector.isScreenBeingShared()
        #expect(result)
    }

    @Test func returnsFalseWhenProcessListEmpty() async {
        let detector = ScreenSharingDetector(processNames: { [] })
        let result = await detector.isScreenBeingShared()
        #expect(!result)
    }
}

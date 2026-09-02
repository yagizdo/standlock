import Testing
@testable import Detection
import StandLockCore

@Suite("CompositeDetector Tests")
struct CompositeDetectorTests {

    @Test func allClear() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(!context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.calendarEventActive)
        #expect(!context.screenSharingActive)
        #expect(context.idleDuration == 0)
    }

    @Test func cameraActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { true },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.calendarEventActive)
        #expect(!context.screenSharingActive)
    }

    @Test func microphoneActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { true },
            calendarCheck: { false },
            privacyIndicatorCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.microphoneActive)
        #expect(!context.cameraActive)
        #expect(!context.calendarEventActive)
        #expect(!context.screenSharingActive)
    }

    @Test func calendarActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { true },
            privacyIndicatorCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.calendarEventActive)
        #expect(!context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.screenSharingActive)
    }

    @Test func screenSharingDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { true },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.screenSharingActive)
        #expect(!context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.calendarEventActive)
    }

    @Test func idleDurationPassesThrough() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { false },
            idleCheck: { 120.5 }
        )
        let context = await detector.currentContext()
        #expect(context.idleDuration == 120.5)
    }

    @Test func multipleDetectionsActive() async {
        let detector = CompositeDetector(
            cameraCheck: { true },
            microphoneCheck: { true },
            calendarCheck: { true },
            privacyIndicatorCheck: { false },
            idleCheck: { 30 }
        )
        let context = await detector.currentContext()
        #expect(context.cameraActive)
        #expect(context.microphoneActive)
        #expect(context.calendarEventActive)
        #expect(!context.screenSharingActive)
        #expect(context.idleDuration == 30)
    }

    @Test func privacyIndicatorWithMicrophoneIsNotScreenSharing() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { true },
            calendarCheck: { false },
            privacyIndicatorCheck: { true },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(!context.screenSharingActive)
        #expect(context.microphoneActive)
    }

    @Test func privacyIndicatorWithCameraIsNotScreenSharing() async {
        let detector = CompositeDetector(
            cameraCheck: { true },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { true },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(!context.screenSharingActive)
        #expect(context.cameraActive)
    }

    @Test func hiddenPrivacyIndicatorIsNotScreenSharing() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            privacyIndicatorCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(!context.screenSharingActive)
        #expect(!context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.calendarEventActive)
    }
}

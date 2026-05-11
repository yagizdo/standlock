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
            screenSharingCheck: { false },
            focusModeCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(!context.cameraActive)
        #expect(!context.microphoneActive)
        #expect(!context.calendarEventActive)
        #expect(!context.screenSharingActive)
        #expect(!context.focusModeActive)
        #expect(context.idleDuration == 0)
        #expect(!context.shouldDefer)
        #expect(context.deferralReason == nil)
    }

    @Test func cameraActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { true },
            microphoneCheck: { false },
            calendarCheck: { false },
            screenSharingCheck: { false },
            focusModeCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.cameraActive)
        #expect(context.shouldDefer)
        #expect(context.deferralReason == .cameraActive)
    }

    @Test func microphoneActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { true },
            calendarCheck: { false },
            screenSharingCheck: { false },
            focusModeCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.microphoneActive)
        #expect(context.shouldDefer)
        #expect(context.deferralReason == .microphoneActive)
    }

    @Test func calendarActiveDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { true },
            screenSharingCheck: { false },
            focusModeCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.calendarEventActive)
        #expect(context.shouldDefer)
        #expect(context.deferralReason == .calendarEvent)
    }

    @Test func screenSharingDefers() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            screenSharingCheck: { true },
            focusModeCheck: { false },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.screenSharingActive)
        #expect(context.shouldDefer)
        #expect(context.deferralReason == .screenSharing)
    }

    @Test func focusModeAloneDoesNotDefer() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            screenSharingCheck: { false },
            focusModeCheck: { true },
            idleCheck: { 0 }
        )
        let context = await detector.currentContext()
        #expect(context.focusModeActive)
        #expect(!context.shouldDefer)
        #expect(context.deferralReason == .focusMode)
    }

    @Test func idleDurationPassesThrough() async {
        let detector = CompositeDetector(
            cameraCheck: { false },
            microphoneCheck: { false },
            calendarCheck: { false },
            screenSharingCheck: { false },
            focusModeCheck: { false },
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
            screenSharingCheck: { false },
            focusModeCheck: { true },
            idleCheck: { 30 }
        )
        let context = await detector.currentContext()
        #expect(context.cameraActive)
        #expect(context.microphoneActive)
        #expect(context.calendarEventActive)
        #expect(!context.screenSharingActive)
        #expect(context.focusModeActive)
        #expect(context.idleDuration == 30)
        #expect(context.shouldDefer)
        #expect(context.deferralReason == .cameraActive)
    }
}

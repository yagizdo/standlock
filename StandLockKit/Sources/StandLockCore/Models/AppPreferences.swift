import Foundation

public struct AppPreferences: Codable, Sendable, Equatable {
    public var firmSkipDelay: TimeInterval
    public var firmEscapePhrase: String
    public var firmDailySkipLimit: Int

    public var strictEscapeHoldDuration: TimeInterval

    public var cameraDetection: DetectionBehavior
    public var microphoneDetection: DetectionBehavior
    public var calendarDetectionEnabled: Bool
    public var calendarLookAheadMinutes: Int
    public var screenSharingDetectionEnabled: Bool
    public var screenSharingPostDeferral: PostDeferralBehavior
    public var focusModeDetection: DetectionBehavior
    public var idleDetectionEnabled: Bool

    public var pauseMediaDuringBreak: Bool
    public var resumeMediaAfterBreak: Bool

    public var resetIntervalOnSkip: Bool

    public init(
        firmSkipDelay: TimeInterval = 10,
        firmEscapePhrase: String = "I choose to skip this break",
        firmDailySkipLimit: Int = 5,
        strictEscapeHoldDuration: TimeInterval = 10,
        cameraDetection: DetectionBehavior = .deferBreak,
        microphoneDetection: DetectionBehavior = .deferBreak,
        calendarDetectionEnabled: Bool = true,
        calendarLookAheadMinutes: Int = 5,
        screenSharingDetectionEnabled: Bool = true,
        screenSharingPostDeferral: PostDeferralBehavior = .triggerBreak,
        focusModeDetection: DetectionBehavior = .deferBreak,
        idleDetectionEnabled: Bool = true,
        pauseMediaDuringBreak: Bool = true,
        resumeMediaAfterBreak: Bool = false,
        resetIntervalOnSkip: Bool = true
    ) {
        self.firmSkipDelay = firmSkipDelay
        self.firmEscapePhrase = firmEscapePhrase
        self.firmDailySkipLimit = firmDailySkipLimit
        self.strictEscapeHoldDuration = strictEscapeHoldDuration
        self.cameraDetection = cameraDetection
        self.microphoneDetection = microphoneDetection
        self.calendarDetectionEnabled = calendarDetectionEnabled
        self.calendarLookAheadMinutes = calendarLookAheadMinutes
        self.screenSharingDetectionEnabled = screenSharingDetectionEnabled
        self.screenSharingPostDeferral = screenSharingPostDeferral
        self.focusModeDetection = focusModeDetection
        self.idleDetectionEnabled = idleDetectionEnabled
        self.pauseMediaDuringBreak = pauseMediaDuringBreak
        self.resumeMediaAfterBreak = resumeMediaAfterBreak
        self.resetIntervalOnSkip = resetIntervalOnSkip
    }

    private enum CodingKeys: String, CodingKey {
        case firmSkipDelay, firmEscapePhrase, firmDailySkipLimit
        case strictEscapeHoldDuration
        case cameraDetection, microphoneDetection
        case calendarDetectionEnabled, calendarLookAheadMinutes
        case screenSharingDetectionEnabled, screenSharingPostDeferral
        case focusModeDetection, idleDetectionEnabled
        case pauseMediaDuringBreak, resumeMediaAfterBreak
        case resetIntervalOnSkip
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firmSkipDelay = try c.decodeIfPresent(TimeInterval.self, forKey: .firmSkipDelay) ?? 10
        firmEscapePhrase = try c.decodeIfPresent(String.self, forKey: .firmEscapePhrase) ?? "I choose to skip this break"
        firmDailySkipLimit = try c.decodeIfPresent(Int.self, forKey: .firmDailySkipLimit) ?? 5
        strictEscapeHoldDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .strictEscapeHoldDuration) ?? 10
        cameraDetection = try c.decodeIfPresent(DetectionBehavior.self, forKey: .cameraDetection) ?? .deferBreak
        microphoneDetection = try c.decodeIfPresent(DetectionBehavior.self, forKey: .microphoneDetection) ?? .deferBreak
        calendarDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .calendarDetectionEnabled) ?? true
        calendarLookAheadMinutes = try c.decodeIfPresent(Int.self, forKey: .calendarLookAheadMinutes) ?? 5
        screenSharingDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .screenSharingDetectionEnabled) ?? true
        screenSharingPostDeferral = try c.decodeIfPresent(PostDeferralBehavior.self, forKey: .screenSharingPostDeferral) ?? .triggerBreak
        focusModeDetection = try c.decodeIfPresent(DetectionBehavior.self, forKey: .focusModeDetection) ?? .deferBreak
        idleDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .idleDetectionEnabled) ?? true
        pauseMediaDuringBreak = try c.decodeIfPresent(Bool.self, forKey: .pauseMediaDuringBreak) ?? true
        resumeMediaAfterBreak = try c.decodeIfPresent(Bool.self, forKey: .resumeMediaAfterBreak) ?? false
        resetIntervalOnSkip = try c.decodeIfPresent(Bool.self, forKey: .resetIntervalOnSkip) ?? true
    }
}

public enum DetectionBehavior: String, Codable, Sendable, CaseIterable {
    case deferBreak
    case reduceToGentle
    case ignore
}

public enum PostDeferralBehavior: String, Codable, Sendable {
    case triggerBreak
    case skipBreak
}

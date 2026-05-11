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
    public var focusModeDetection: DetectionBehavior
    public var idleDetectionEnabled: Bool

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
        focusModeDetection: DetectionBehavior = .deferBreak,
        idleDetectionEnabled: Bool = true,
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
        self.focusModeDetection = focusModeDetection
        self.idleDetectionEnabled = idleDetectionEnabled
        self.resetIntervalOnSkip = resetIntervalOnSkip
    }
}

public enum DetectionBehavior: String, Codable, Sendable, CaseIterable {
    case deferBreak
    case reduceToGentle
    case ignore
}

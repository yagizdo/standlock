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

    public var pauseMediaDuringBreak: Bool
    public var resumeMediaAfterBreak: Bool

    public var resetIntervalOnSkip: Bool

    public var gentleEscalationEnabled: Bool
    public var firmEscalationEnabled: Bool
    public var strictEscalationEnabled: Bool

    public func escalationEnabled(for level: DisciplineLevel) -> Bool {
        switch level {
        case .gentle: gentleEscalationEnabled
        case .firm: firmEscalationEnabled
        case .strict: strictEscalationEnabled
        }
    }

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
        pauseMediaDuringBreak: Bool = true,
        resumeMediaAfterBreak: Bool = false,
        resetIntervalOnSkip: Bool = true,
        gentleEscalationEnabled: Bool = false,
        firmEscalationEnabled: Bool = false,
        strictEscalationEnabled: Bool = false
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
        self.pauseMediaDuringBreak = pauseMediaDuringBreak
        self.resumeMediaAfterBreak = resumeMediaAfterBreak
        self.resetIntervalOnSkip = resetIntervalOnSkip
        self.gentleEscalationEnabled = gentleEscalationEnabled
        self.firmEscalationEnabled = firmEscalationEnabled
        self.strictEscalationEnabled = strictEscalationEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case firmSkipDelay, firmEscapePhrase, firmDailySkipLimit
        case strictEscapeHoldDuration
        case cameraDetection, microphoneDetection
        case calendarDetectionEnabled, calendarLookAheadMinutes
        case screenSharingDetectionEnabled
        case focusModeDetection, idleDetectionEnabled
        case pauseMediaDuringBreak, resumeMediaAfterBreak
        case resetIntervalOnSkip
        case gentleEscalationEnabled, firmEscalationEnabled, strictEscalationEnabled
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
        focusModeDetection = try c.decodeIfPresent(DetectionBehavior.self, forKey: .focusModeDetection) ?? .deferBreak
        idleDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .idleDetectionEnabled) ?? true
        pauseMediaDuringBreak = try c.decodeIfPresent(Bool.self, forKey: .pauseMediaDuringBreak) ?? true
        resumeMediaAfterBreak = try c.decodeIfPresent(Bool.self, forKey: .resumeMediaAfterBreak) ?? false
        resetIntervalOnSkip = try c.decodeIfPresent(Bool.self, forKey: .resetIntervalOnSkip) ?? true
        gentleEscalationEnabled = try c.decodeIfPresent(Bool.self, forKey: .gentleEscalationEnabled) ?? false
        firmEscalationEnabled = try c.decodeIfPresent(Bool.self, forKey: .firmEscalationEnabled) ?? false
        strictEscalationEnabled = try c.decodeIfPresent(Bool.self, forKey: .strictEscalationEnabled) ?? false
    }
}

public enum DetectionBehavior: String, Codable, Sendable, CaseIterable {
    case deferBreak
    case reduceToGentle
    case ignore
}

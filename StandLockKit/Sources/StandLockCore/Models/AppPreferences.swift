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

    public var escalationLevel: EscalationLevel

    public static func tierMultiplier(for tier: Int) -> Double {
        switch tier {
        case 0: 1.0
        case 1: 1.5
        case 2: 2.0
        default: 2.5
        }
    }

    public func escalationEnabled(for level: DisciplineLevel) -> Bool {
        switch level {
        case .gentle: escalationLevel >= .gentle
        case .firm: escalationLevel >= .firm
        case .strict: escalationLevel >= .strict
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
        escalationLevel: EscalationLevel = .off
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
        self.escalationLevel = escalationLevel
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
        case escalationLevel
    }

    private enum LegacyKeys: String, CodingKey {
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
        if let level = try c.decodeIfPresent(EscalationLevel.self, forKey: .escalationLevel) {
            escalationLevel = level
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let gentle = try legacy.decodeIfPresent(Bool.self, forKey: .gentleEscalationEnabled) ?? false
            let firm = try legacy.decodeIfPresent(Bool.self, forKey: .firmEscalationEnabled) ?? false
            let strict = try legacy.decodeIfPresent(Bool.self, forKey: .strictEscalationEnabled) ?? false
            if strict { escalationLevel = .strict }
            else if firm { escalationLevel = .firm }
            else if gentle { escalationLevel = .gentle }
            else { escalationLevel = .off }
        }
    }
}

public enum DetectionBehavior: String, Codable, Sendable, CaseIterable {
    case deferBreak
    case reduceToGentle
    case ignore
}

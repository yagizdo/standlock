import Foundation

public struct AppPreferences: Codable, Sendable, Equatable {
    /// The escape phrase a user gets until they set their own. The app treats a
    /// stored phrase equal to this one as translatable; anything else is shown verbatim.
    public static let defaultFirmEscapePhrase = "I choose to skip this break"

    public var gentleDailySkipLimit: Int
    public var firmSkipDelay: TimeInterval
    public var firmEscapePhrase: String
    public var firmDailySkipLimit: Int

    public var strictEscapeHoldDuration: TimeInterval

    public var cameraDetection: DetectionBehavior
    public var microphoneDetection: DetectionBehavior
    public var calendarDetectionEnabled: Bool
    public var calendarLookAheadMinutes: Int
    /// Whether every calendar defers breaks or only the ones picked in Settings. The default
    /// keeps today's behaviour, so nothing changes for anyone who never opens the list.
    public var calendarSelectionMode: CalendarSelectionMode
    public var selectedCalendarIdentifiers: [String]
    public var screenSharingDetectionEnabled: Bool
    public var screenSharingPostDeferral: PostDeferralBehavior
    /// Seconds the microphone and camera must both stay free before a postponed break returns.
    public var postponeReturnDelay: TimeInterval
    public var idleDetectionEnabled: Bool

    public var pauseMediaDuringBreak: Bool
    public var soundBeforeBreak: Bool
    public var soundAfterBreak: Bool
    public var lockScreenAfterUnattendedBreak: Bool

    public var resetIntervalOnSkip: Bool

    public var showFullWorkTimer: Bool
    public var menuBarCountdownMinutes: Int
    public var menuScene: MenuScene

    public var breakScreen: BreakScreenPreferences

    public var pomodoro: PomodoroConfiguration

    public init(
        gentleDailySkipLimit: Int = 5,
        firmSkipDelay: TimeInterval = 10,
        firmEscapePhrase: String = AppPreferences.defaultFirmEscapePhrase,
        firmDailySkipLimit: Int = 5,
        strictEscapeHoldDuration: TimeInterval = 10,
        cameraDetection: DetectionBehavior = .deferBreak,
        microphoneDetection: DetectionBehavior = .deferBreak,
        calendarDetectionEnabled: Bool = true,
        calendarLookAheadMinutes: Int = 5,
        calendarSelectionMode: CalendarSelectionMode = .all,
        selectedCalendarIdentifiers: [String] = [],
        screenSharingDetectionEnabled: Bool = true,
        screenSharingPostDeferral: PostDeferralBehavior = .triggerBreak,
        postponeReturnDelay: TimeInterval = 120,
        idleDetectionEnabled: Bool = true,
        pauseMediaDuringBreak: Bool = true,
        soundBeforeBreak: Bool = false,
        soundAfterBreak: Bool = false,
        lockScreenAfterUnattendedBreak: Bool = false,
        resetIntervalOnSkip: Bool = true,
        showFullWorkTimer: Bool = false,
        menuBarCountdownMinutes: Int = 1,
        menuScene: MenuScene = .hourglass,
        breakScreen: BreakScreenPreferences = BreakScreenPreferences(),
        pomodoro: PomodoroConfiguration = .standard
    ) {
        self.gentleDailySkipLimit = gentleDailySkipLimit
        self.firmSkipDelay = firmSkipDelay
        self.firmEscapePhrase = firmEscapePhrase
        self.firmDailySkipLimit = firmDailySkipLimit
        self.strictEscapeHoldDuration = strictEscapeHoldDuration
        self.cameraDetection = cameraDetection
        self.microphoneDetection = microphoneDetection
        self.calendarDetectionEnabled = calendarDetectionEnabled
        self.calendarLookAheadMinutes = calendarLookAheadMinutes
        self.calendarSelectionMode = calendarSelectionMode
        self.selectedCalendarIdentifiers = selectedCalendarIdentifiers
        self.screenSharingDetectionEnabled = screenSharingDetectionEnabled
        self.screenSharingPostDeferral = screenSharingPostDeferral
        self.postponeReturnDelay = postponeReturnDelay
        self.idleDetectionEnabled = idleDetectionEnabled
        self.pauseMediaDuringBreak = pauseMediaDuringBreak
        self.soundBeforeBreak = soundBeforeBreak
        self.soundAfterBreak = soundAfterBreak
        self.lockScreenAfterUnattendedBreak = lockScreenAfterUnattendedBreak
        self.resetIntervalOnSkip = resetIntervalOnSkip
        self.showFullWorkTimer = showFullWorkTimer
        self.menuBarCountdownMinutes = menuBarCountdownMinutes
        self.menuScene = menuScene
        self.breakScreen = breakScreen
        self.pomodoro = pomodoro
    }

    private enum CodingKeys: String, CodingKey {
        case gentleDailySkipLimit
        case firmSkipDelay, firmEscapePhrase, firmDailySkipLimit
        case strictEscapeHoldDuration
        case cameraDetection, microphoneDetection
        case calendarDetectionEnabled, calendarLookAheadMinutes, calendarSelectionMode, selectedCalendarIdentifiers
        case screenSharingDetectionEnabled, screenSharingPostDeferral
        case postponeReturnDelay
        case idleDetectionEnabled
        case pauseMediaDuringBreak, soundBeforeBreak, soundAfterBreak
        case lockScreenAfterUnattendedBreak
        case resetIntervalOnSkip
        case showFullWorkTimer, menuBarCountdownMinutes, menuScene
        case breakScreen
        case pomodoro
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lenient = decoder.readsStoredData
        gentleDailySkipLimit = try c.decodeIfPresent(Int.self, forKey: .gentleDailySkipLimit) ?? 5
        firmSkipDelay = try c.decodeIfPresent(TimeInterval.self, forKey: .firmSkipDelay) ?? 10
        firmEscapePhrase = try c.decodeIfPresent(String.self, forKey: .firmEscapePhrase) ?? AppPreferences.defaultFirmEscapePhrase
        firmDailySkipLimit = try c.decodeIfPresent(Int.self, forKey: .firmDailySkipLimit) ?? 5
        strictEscapeHoldDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .strictEscapeHoldDuration) ?? 10
        cameraDetection = try c.decode(DetectionBehavior.self, forKey: .cameraDetection, fallback: .deferBreak, lenient: lenient)
        microphoneDetection = try c.decode(DetectionBehavior.self, forKey: .microphoneDetection, fallback: .deferBreak, lenient: lenient)
        calendarDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .calendarDetectionEnabled) ?? true
        calendarLookAheadMinutes = try c.decodeIfPresent(Int.self, forKey: .calendarLookAheadMinutes) ?? 5
        calendarSelectionMode = try c.decode(CalendarSelectionMode.self, forKey: .calendarSelectionMode, fallback: .all, lenient: lenient)
        selectedCalendarIdentifiers = try c.decodeIfPresent([String].self, forKey: .selectedCalendarIdentifiers) ?? []
        screenSharingDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .screenSharingDetectionEnabled) ?? true
        screenSharingPostDeferral = try c.decode(PostDeferralBehavior.self, forKey: .screenSharingPostDeferral, fallback: .triggerBreak, lenient: lenient)
        postponeReturnDelay = try c.decodeIfPresent(TimeInterval.self, forKey: .postponeReturnDelay) ?? 120
        idleDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .idleDetectionEnabled) ?? true
        pauseMediaDuringBreak = try c.decodeIfPresent(Bool.self, forKey: .pauseMediaDuringBreak) ?? true
        soundBeforeBreak = try c.decodeIfPresent(Bool.self, forKey: .soundBeforeBreak) ?? false
        soundAfterBreak = try c.decodeIfPresent(Bool.self, forKey: .soundAfterBreak) ?? false
        lockScreenAfterUnattendedBreak = try c.decodeIfPresent(Bool.self, forKey: .lockScreenAfterUnattendedBreak) ?? false
        resetIntervalOnSkip = try c.decodeIfPresent(Bool.self, forKey: .resetIntervalOnSkip) ?? true
        showFullWorkTimer = try c.decodeIfPresent(Bool.self, forKey: .showFullWorkTimer) ?? false
        menuBarCountdownMinutes = try c.decodeIfPresent(Int.self, forKey: .menuBarCountdownMinutes) ?? 1
        // A string, not the enum, so a scene from a newer version falls back even in an import: it
        // changes nothing a break does, unlike the fields an import refuses.
        menuScene = try c.decodeIfPresent(String.self, forKey: .menuScene).flatMap(MenuScene.init(rawValue:)) ?? .hourglass
        breakScreen = try c.decodeIfPresent(BreakScreenPreferences.self, forKey: .breakScreen) ?? BreakScreenPreferences()
        pomodoro = try c.decodeIfPresent(PomodoroConfiguration.self, forKey: .pomodoro) ?? .standard
    }
}

extension AppPreferences {
    /// A specific selection that holds nothing yet starts with every calendar ticked, so the
    /// switch to it changes nothing until the user narrows it down.
    public var needsCalendarPreCheck: Bool {
        calendarSelectionMode == .selected && selectedCalendarIdentifiers.isEmpty
    }

    public mutating func setCalendar(_ id: String, isSelected: Bool) {
        if isSelected {
            if !selectedCalendarIdentifiers.contains(id) { selectedCalendarIdentifiers.append(id) }
        } else {
            selectedCalendarIdentifiers.removeAll { $0 == id }
        }
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

public enum CalendarSelectionMode: String, Codable, Sendable {
    case all
    case selected
}

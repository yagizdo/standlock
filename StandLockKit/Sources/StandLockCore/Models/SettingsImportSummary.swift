import Foundation

/// What loading a settings file would change, for the confirmation shown before it applies.
public struct SettingsImportSummary: Equatable, Sendable {
    /// Settings pages whose values change, in sidebar order.
    public var changedPages: [SettingsPage]
    /// Show help lives in the sidebar footer, not on a page.
    public var changesShowHelp: Bool
    public var addedSchedules: [String]
    public var removedSchedules: [String]
    public var changedSchedules: [String]
    /// The current setting picks specific calendars; the file always carries all calendars.
    public var dropsCalendarSelection: Bool

    public var isEmpty: Bool {
        changedPages.isEmpty && !changesShowHelp
            && addedSchedules.isEmpty && removedSchedules.isEmpty && changedSchedules.isEmpty
    }

    static let pageOrder: [SettingsPage] = [.general, .menuBar, .breakScreen, .discipline, .detection]

    /// - Parameter imported: a decoded file, already portable.
    public init(current: SettingsExport, imported: SettingsExport) {
        // Compared after the same calendar drop the file went through, so a value the file
        // cannot carry does not show as a change on every import.
        dropsCalendarSelection = current.preferences.calendarSelectionMode == .selected
        let current = current.portable
        var pages: Set<SettingsPage> = dropsCalendarSelection ? [.detection] : []
        if current.theme != imported.theme || current.language != imported.language { pages.insert(.general) }
        for field in Self.preferenceFields() where field.differs(current.preferences, imported.preferences) {
            pages.insert(field.page)
        }
        changesShowHelp = current.showHelp != imported.showHelp

        let currentByID = Dictionary(current.schedules.map { ($0.id, $0) }) { first, _ in first }
        let importedIDs = Set(imported.schedules.map(\.id))
        addedSchedules = imported.schedules.filter { currentByID[$0.id] == nil }.map(\.name)
        removedSchedules = current.schedules.filter { !importedIDs.contains($0.id) }.map(\.name)
        changedSchedules = imported.schedules.filter { schedule in
            currentByID[schedule.id].map { $0 != schedule } ?? false
        }.map(\.name)

        changedPages = Self.pageOrder.filter(pages.contains)
    }

    struct PreferenceField {
        let name: String
        let page: SettingsPage
        let differs: (AppPreferences, AppPreferences) -> Bool
    }

    /// Every stored preference and the page that shows it. A test checks this against
    /// `AppPreferences`'s stored properties, so a new preference cannot be left out.
    static func preferenceFields() -> [PreferenceField] {
        func field<Value: Equatable>(_ name: String, _ page: SettingsPage, _ path: KeyPath<AppPreferences, Value>) -> PreferenceField {
            PreferenceField(name: name, page: page) { $0[keyPath: path] != $1[keyPath: path] }
        }
        return [
            field("showFullWorkTimer", .menuBar, \.showFullWorkTimer),
            field("menuBarCountdownMinutes", .menuBar, \.menuBarCountdownMinutes),
            field("menuScene", .menuBar, \.menuScene),
            field("pauseMediaDuringBreak", .breakScreen, \.pauseMediaDuringBreak),
            field("soundBeforeBreak", .breakScreen, \.soundBeforeBreak),
            field("soundAfterBreak", .breakScreen, \.soundAfterBreak),
            field("breakScreen", .breakScreen, \.breakScreen),
            field("gentleDailySkipLimit", .discipline, \.gentleDailySkipLimit),
            field("firmSkipDelay", .discipline, \.firmSkipDelay),
            field("firmEscapePhrase", .discipline, \.firmEscapePhrase),
            field("firmDailySkipLimit", .discipline, \.firmDailySkipLimit),
            field("strictEscapeHoldDuration", .discipline, \.strictEscapeHoldDuration),
            field("resetIntervalOnSkip", .discipline, \.resetIntervalOnSkip),
            field("cameraDetection", .detection, \.cameraDetection),
            field("microphoneDetection", .detection, \.microphoneDetection),
            field("calendarDetectionEnabled", .detection, \.calendarDetectionEnabled),
            field("calendarLookAheadMinutes", .detection, \.calendarLookAheadMinutes),
            field("calendarSelectionMode", .detection, \.calendarSelectionMode),
            field("selectedCalendarIdentifiers", .detection, \.selectedCalendarIdentifiers),
            field("screenSharingDetectionEnabled", .detection, \.screenSharingDetectionEnabled),
            field("screenSharingPostDeferral", .detection, \.screenSharingPostDeferral),
            field("postponeReturnDelay", .detection, \.postponeReturnDelay),
            field("naturalBreakThresholdMinutes", .detection, \.naturalBreakThresholdMinutes),
        ]
    }
}

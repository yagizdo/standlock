import Foundation

/// The settings file a user saves on one Mac and loads on another.
///
/// It carries what the user chose, not what happened: no history, statistics or
/// enforcement counters, so loading a file can never change today's enforcement.
public struct SettingsExport: Codable, Sendable, Equatable {
    /// Marks the file as StandLock's, since the open panel offers any JSON.
    public static let formatIdentifier = "com.yagizdokumaci.standlock.settings"
    public static let currentVersion = 1

    public var format: String
    public var version: Int
    public var preferences: AppPreferences
    public var schedules: [Schedule]
    /// A theme id, or nil to follow the Mac.
    public var theme: String?
    /// A language code, or nil to follow the system.
    public var language: String?
    public var showHelp: Bool

    public init(preferences: AppPreferences, schedules: [Schedule], theme: String?, language: String?, showHelp: Bool) {
        self.format = Self.formatIdentifier
        self.version = Self.currentVersion
        self.preferences = preferences
        self.schedules = schedules
        self.theme = theme
        self.language = language
        self.showHelp = showHelp
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(portable)
    }

    /// Reads a whole file or throws; a caller applies nothing unless this returns.
    public static func decode(_ data: Data) throws -> SettingsExport {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else {
            // `format` sorts first, so a cut-off file of ours still carries the marker.
            throw data.range(of: Data("\"\(formatIdentifier)\"".utf8)) == nil
                ? SettingsImportError.notSettingsFile : SettingsImportError.unreadable
        }
        guard header.format == formatIdentifier,
              let version = header.version, version >= 1
        else { throw SettingsImportError.notSettingsFile }
        guard version <= currentVersion else { throw SettingsImportError.newerVersion }

        guard let export = try? decoder.decode(SettingsExport.self, from: data), export.isRunnable
        else { throw SettingsImportError.unreadable }
        return export.portable
    }

    /// Replaces a theme or language this build does not ship with the current one.
    public func keepingKnownChoices(languages: [String], themes: [String], current: SettingsExport) -> SettingsExport {
        var result = self
        if let theme, !themes.contains(theme) { result.theme = current.theme }
        if let language, !languages.contains(language) { result.language = current.language }
        return result
    }

    /// Calendar identifiers are not sync-proof and differ between Macs; ids that match
    /// nothing would make a selected-calendars setting reject every event.
    var portable: SettingsExport {
        var copy = self
        copy.preferences.calendarSelectionMode = .all
        copy.preferences.selectedCalendarIdentifiers = []
        return copy
    }

    /// Far above any setting a person uses, far below where `Int(...)`, `Duration` and
    /// minute-to-second arithmetic overflow.
    private static let maxDuration: TimeInterval = 366 * 86_400
    private static let maxCount = 100_000

    /// Values the app would trap or loop on. Not the form's ranges: older stored
    /// schedules can sit outside them, such as sub-minute intervals.
    private var isRunnable: Bool {
        let p = preferences
        guard Set(schedules.map(\.id)).count == schedules.count,
              p.strictEscapeHoldDuration.isFinite,
              (0...BreakSafety.maximumEscapeHoldDuration).contains(p.strictEscapeHoldDuration),
              p.firmSkipDelay <= BreakSafety.maximumSkipDelay,
              [p.firmSkipDelay, p.postponeReturnDelay]
                  .allSatisfy({ $0.isFinite && (0...Self.maxDuration).contains($0) }),
              [p.gentleDailySkipLimit, p.firmDailySkipLimit, p.menuBarCountdownMinutes, p.calendarLookAheadMinutes]
                  .allSatisfy({ (0...Self.maxCount).contains($0) })
        else { return false }
        return schedules.allSatisfy { schedule in
            let intervals = [schedule.breakInterval]
                + (schedule.intervalCycle ?? []).map(\.duration)
            let breaks = [schedule.breakDuration]
                + [schedule.repetitionRule?.shortBreakDuration, schedule.repetitionRule?.longBreakDuration].compactMap { $0 }
            return intervals.allSatisfy { $0.isFinite && $0 > 0 && $0 <= Self.maxDuration }
                && breaks.allSatisfy { $0.isFinite && $0 > 0 && $0 <= BreakSafety.maximumBreakDuration }
                && (0...Self.maxCount).contains(schedule.repetitionRule?.shortBreakCount ?? 0)
                && schedule.windows.allSatisfy { window in
                    (0...23).contains(window.startHour) && (0...23).contains(window.endHour)
                        && (0...59).contains(window.startMinute) && (0...59).contains(window.endMinute)
                }
        }
    }

    private struct Header: Decodable {
        var format: String?
        var version: Int?
    }
}

public enum SettingsImportError: Error, Equatable, Sendable {
    /// Not JSON, or JSON that is not a StandLock settings file.
    case notSettingsFile
    /// Made by a newer StandLock with a format this build cannot read.
    case newerVersion
    /// A StandLock settings file whose contents are damaged or hold values this build does not know.
    case unreadable
}

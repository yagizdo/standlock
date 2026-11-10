import SwiftUI
import StandLockCore

extension SettingsPage {
    static let sidebarTopPages: [SettingsPage] = [.general, .menuBar]
    static let sidebarBreakPages: [SettingsPage] = [.breakScreen, .discipline, .detection, .pomodoro]
    static let sidebarBottomPages: [SettingsPage] = [.permissions, .statistics, .about]

    var title: LocalizedStringKey { LocalizedStringKey(titleResource.key) }

    /// The title for text composed outside a `Text`, such as an alert message.
    var titleResource: LocalizedStringResource {
        switch self {
        case .general: "General"
        case .menuBar: "Menu Bar"
        case .breakScreen: "Break Screen"
        case .discipline: "Discipline"
        case .schedule: "Schedules"
        case .newSchedule: "Add Schedule"
        case .detection: "Detection"
        case .pomodoro: "Pomodoro"
        case .permissions: "Permissions"
        case .statistics: "Statistics"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .breakScreen: "clock"
        case .discipline: "hand.raised"
        case .schedule: "calendar.badge.clock"
        case .newSchedule: "plus"
        case .detection: "eye"
        case .pomodoro: "timer"
        case .permissions: "lock.shield"
        case .statistics: "chart.bar.xaxis"
        case .about: "info.circle"
        }
    }

    /// The palette hue of the sidebar chip. Nil is neutral grey.
    var tone: DisciplineLevel? {
        switch self {
        case .general, .schedule, .newSchedule, .permissions, .about: nil
        case .detection: .strict
        case .menuBar, .breakScreen, .statistics: .gentle
        case .discipline, .pomodoro: .firm
        }
    }

    /// What search looks in, besides a schedule's name: the page title, its section and row titles.
    /// Literals, so the build extracts them and a term with no catalog entry surfaces on a sync.
    var searchTerms: [LocalizedStringResource] {
        switch self {
        case .general:
            [
                "General", "Startup", "Launch at Startup", "Language and appearance", "Language", "Appearance",
                "Settings File", "Export Settings", "Import Settings",
            ]
        case .menuBar:
            ["Menu Bar", "Scene", "Timer", "Show Full Work Timer", "Countdown Start", "Preview"]
        case .breakScreen:
            [
                "Break Screen", "Look", "Custom Break Colors", "Background", "Text", "Preview", "Content",
                "Show Statistics", "Show Pomodoro chip", "Break Message", "During a break", "Pause Media",
                "Sound when a break ends", "Sound before a break",
            ]
        case .discipline:
            [
                "Discipline", "Daily skip limits", "Gentle Daily Skip Limit", "Firm Daily Skip Limit", "Strict",
                "Skipping a break does not buy extra work time",
            ]
        case .schedule:
            Self.scheduleFormTerms
        case .newSchedule:
            ["Add Schedule", "New Schedule", "Start from"] + Self.scheduleFormTerms
        case .detection:
            [
                "Detection", "Calls", "Camera Detection", "Microphone Detection", "Return after call",
                "Calendar", "Calendar Integration", "Look-ahead", "Calendars",
                "Screen Sharing", "After sharing ends", "Idle", "Idle as Break",
            ]
        case .pomodoro:
            ["Pomodoro", "Cover the screen", "Focus length", "Short break", "Long break", "Rounds"]
        case .permissions:
            ["Permissions", "Accessibility", "Input Monitoring", "Calendar Access"]
        case .statistics:
            [
                "Statistics", "Period", "Break Activity", "Streak", "Best Streak",
                "Completed", "Skipped", "Break Time", "Completion",
                "Pomodoro", "Focus time", "Rounds", "Finished", "Unfinished",
            ]
        case .about:
            [
                "About", "Updates", "Automatic Updates", "Check for Updates…", "Version",
                "Links", "GitHub", "Website", "Twitter",
            ]
        }
    }

    private static let scheduleFormTerms: [LocalizedStringResource] = [
        "Schedules", "Enabled", "Name", "When", "Hours", "Rhythm", "Break every", "Break lasts",
        "Alternating intervals", "Repetition Cycle", "Short breaks", "Short break", "Long break", "Discipline",
        "Gentle", "Firm", "Strict", "Progressive Enforcement", "Your day",
    ]
}

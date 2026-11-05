import SwiftUI
import StandLockCore

extension SettingsPage {
    static let sidebarPages: [SettingsPage] = [.general, .schedules, .detection, .permissions, .statistics, .about]

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .schedules: "Schedules"
        case .detection: "Detection"
        case .permissions: "Permissions"
        case .statistics: "Statistics"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .schedules: "calendar.badge.clock"
        case .detection: "eye"
        case .permissions: "lock.shield"
        case .statistics: "chart.bar.xaxis"
        case .about: "info.circle"
        }
    }

    /// The palette hue of the sidebar chip. Nil is neutral grey.
    var tone: DisciplineLevel? {
        switch self {
        case .general, .schedules, .permissions, .about: nil
        case .detection: .strict
        case .statistics: .gentle
        }
    }
}

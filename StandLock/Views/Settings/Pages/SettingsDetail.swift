import SwiftUI
import StandLockCore
@preconcurrency import Sparkle

struct SettingsDetail: View {
    @ObservedObject var navigation: SettingsNavigation
    let updater: SPUUpdater

    var body: some View {
        page
            .environment(\.settingsRowTone, navigation.page.tone)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PreferencesSaveOwner())
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.page {
        case .general: GeneralSettingsView()
        case .menuBar: MenuBarSettingsView()
        case .breakScreen: BreakScreenSettingsView()
        case .discipline: DisciplineSettingsView()
        case .schedule(let id): ScheduleDetailView(id: id, navigation: navigation).id(id)
        case .newSchedule: ScheduleDetailView(id: nil, navigation: navigation)
        case .detection: DetectionSettingsView()
        case .pomodoro: PomodoroSettingsView()
        case .permissions: PermissionsView()
        case .statistics: StatisticsView()
        case .about: AboutView(updater: updater)
        }
    }
}

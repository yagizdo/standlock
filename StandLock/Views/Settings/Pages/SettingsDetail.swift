import SwiftUI
import StandLockCore
@preconcurrency import Sparkle

struct SettingsDetail: View {
    @ObservedObject var navigation: SettingsNavigation
    let updater: SPUUpdater

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PreferencesSaveOwner())
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.page {
        case .general: GeneralSettingsView()
        case .menuBar: MenuBarSettingsView()
        case .schedules: ScheduleEditorView()
        case .detection: DetectionSettingsView()
        case .permissions: PermissionsView()
        case .statistics: StatisticsView()
        case .about: AboutView(updater: updater)
        }
    }
}

import SwiftUI
import StandLockCore
@preconcurrency import Sparkle

struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    let updater: SPUUpdater

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selectedTab: $navigation.page)
            Divider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: navigation.page == .statistics ? 580 : 480)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch navigation.page {
        case .general: GeneralSettingsView()
        case .schedules: ScheduleEditorView()
        case .detection: DetectionSettingsView()
        case .permissions: PermissionsView()
        case .statistics: StatisticsView()
        case .about: AboutView(updater: updater)
        }
    }
}

private struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsPage

    private static let tabs: [(SettingsPage, LocalizedStringKey, String)] = [
        (.general, "General", "gearshape"),
        (.schedules, "Schedules", "calendar.badge.clock"),
        (.detection, "Detection", "eye"),
        (.permissions, "Permissions", "lock.shield"),
        (.statistics, "Statistics", "chart.bar.xaxis"),
        (.about, "About", "info.circle"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.tabs, id: \.0) { tab, title, icon in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 20)
                        Text(title)
                            .font(.system(size: 10))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

import SwiftUI

struct SettingsView: View {
    @Binding var selectedTab: AppCoordinator.SettingsTab

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selectedTab: $selectedTab)
            Divider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 480)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general: GeneralSettingsView()
        case .schedules: ScheduleEditorView()
        case .detection: DetectionSettingsView()
        case .permissions: PermissionsView()
        case .about: AboutView()
        }
    }
}

private struct SettingsTabBar: View {
    @Binding var selectedTab: AppCoordinator.SettingsTab

    private static let tabs: [(AppCoordinator.SettingsTab, String, String)] = [
        (.general, "General", "gearshape"),
        (.schedules, "Schedules", "calendar.badge.clock"),
        (.detection, "Detection", "eye"),
        (.permissions, "Permissions", "lock.shield"),
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

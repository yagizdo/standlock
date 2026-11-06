import SwiftUI
@preconcurrency import Sparkle

private let sidebarWidth: CGFloat = 232

/// Picks the window chrome. Page, sidebar and navigation logic stay out of both containers.
struct SettingsView: View {
    let navigation: SettingsNavigation
    let coordinator: AppCoordinator
    let updater: SPUUpdater

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                SplitContainer(navigation: navigation, coordinator: coordinator, updater: updater)
            } else {
                StackContainer(navigation: navigation, coordinator: coordinator, updater: updater)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(WindowCloseGuard(navigation: navigation))
    }
}

/// The system draws the glass here. A custom background in this sidebar would block it.
@available(macOS 26, *)
private struct SplitContainer: View {
    let navigation: SettingsNavigation
    let coordinator: AppCoordinator
    let updater: SPUUpdater

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: pinnedVisibility) {
            // `.toolbar(removing:)` goes inside the width: the other order loses the width.
            SettingsSidebar(navigation: navigation, coordinator: coordinator)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(sidebarWidth)
        } detail: {
            SettingsDetail(navigation: navigation, updater: updater)
        }
    }

    /// `.constant(.all)` does not stop the column collapsing, so the value is written back.
    private var pinnedVisibility: Binding<NavigationSplitViewVisibility> {
        let visibility = $columnVisibility
        return Binding(
            get: { visibility.wrappedValue },
            set: { value in
                visibility.wrappedValue = value
                guard value != .all else { return }
                DispatchQueue.main.async { visibility.wrappedValue = .all }
            }
        )
    }
}

private struct StackContainer: View {
    let navigation: SettingsNavigation
    let coordinator: AppCoordinator
    let updater: SPUUpdater

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(navigation: navigation, coordinator: coordinator)
                .frame(width: sidebarWidth)
                .background(SidebarBackground().ignoresSafeArea())
            Divider()
                .ignoresSafeArea()
            SettingsDetail(navigation: navigation, updater: updater)
        }
    }
}

import SwiftUI
import StandLockCore

struct SettingsSidebar: View {
    @ObservedObject var navigation: SettingsNavigation
    @FocusState private var listFocused: Bool

    var body: some View {
        List(selection: $navigation.page) {
            rows(SettingsPage.sidebarTopPages)

            Section("Breaks") {
                rows(SettingsPage.sidebarBreakPages)
            }
            // macOS 13 lets a sidebar section collapse, which could hide the selected row.
            .collapsible(false)

            // Headerless, so these rows do not read as part of Breaks.
            Section {
                rows(SettingsPage.sidebarBottomPages)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .focused($listFocused)
        .onAppear { listFocused = true }
        .onChange(of: navigation.page) { _ in listFocused = true }
    }

    private func rows(_ pages: [SettingsPage]) -> some View {
        ForEach(pages, id: \.self) { page in
            SettingsSidebarRow(page: page, isSelected: page == navigation.page)
                .tag(page)
        }
    }
}

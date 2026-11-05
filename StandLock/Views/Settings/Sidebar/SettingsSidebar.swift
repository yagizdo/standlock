import SwiftUI
import StandLockCore

struct SettingsSidebar: View {
    @ObservedObject var navigation: SettingsNavigation
    @FocusState private var listFocused: Bool

    var body: some View {
        List(selection: selection) {
            ForEach(SettingsPage.sidebarPages, id: \.self) { page in
                SettingsSidebarRow(page: page, isSelected: page == navigation.page)
                    .tag(page)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .focused($listFocused)
        .onAppear { listFocused = true }
        .onChange(of: navigation.page) { _ in listFocused = true }
    }

    /// A click on empty space writes nil, which must not clear the page.
    private var selection: Binding<SettingsPage?> {
        Binding(
            get: { navigation.page },
            set: { page in
                if let page { navigation.page = page }
            }
        )
    }
}

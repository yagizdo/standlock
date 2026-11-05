import SwiftUI
import StandLockCore

struct SettingsSidebar: View {
    @ObservedObject var navigation: SettingsNavigation
    /// Held, not observed: it publishes every second before a break, and only schedules matter here.
    let coordinator: AppCoordinator
    @State private var schedules: [Schedule]
    @FocusState private var listFocused: Bool
    @AppStorage(SettingsDescription.showHelpKey) private var showHelp = true

    init(navigation: SettingsNavigation, coordinator: AppCoordinator) {
        self.navigation = navigation
        self.coordinator = coordinator
        _schedules = State(initialValue: coordinator.schedules)
    }

    var body: some View {
        // Below the list, not a `safeAreaInset`: rows would scroll under the footer, and a
        // background to stop that would block the glass.
        VStack(spacing: 0) {
            list
            Divider()
            VStack(spacing: SettingsTokens.sidebarFooterSpacing) {
                NextBreakStatus(coordinator: coordinator)
                HStack {
                    Text("Show help")
                    Spacer()
                    // A label beside the switch leaves it nameless to VoiceOver.
                    Toggle("Show help", isOn: $showHelp)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
            .font(SettingsTokens.descriptionFont)
            .foregroundStyle(.secondary)
            .padding(SettingsTokens.sidebarFooterInsets)
        }
    }

    private var list: some View {
        List(selection: selection) {
            rows(SettingsPage.sidebarTopPages)

            Section("Breaks") {
                rows(SettingsPage.sidebarBreakPages)
            }
            // macOS 13 lets a sidebar section collapse, which could hide the selected row.
            .collapsible(false)

            Section {
                ForEach(schedules) { schedule in
                    ScheduleSidebarRow(schedule: schedule)
                        .tag(SettingsPage.schedule(schedule.id))
                }
                rows([.newSchedule])
            } header: {
                HStack {
                    Text("Schedules")
                    Spacer()
                    Text("\(schedules.filter(\.isEnabled).count) on")
                        .padding(.trailing, SettingsTokens.sidebarHeaderInset)
                }
            }
            .collapsible(false)

            // Headerless, so these rows do not read as part of Schedules.
            Section {
                rows(SettingsPage.sidebarBottomPages)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .focused($listFocused)
        .onAppear { listFocused = true }
        .onChange(of: navigation.page) { _ in listFocused = true }
        .onReceive(coordinator.$schedules.removeDuplicates()) { value in
            schedules = value
            navigation.reconcile(scheduleIDs: value.map(\.id))
        }
    }

    private var selection: Binding<SettingsPage> {
        let navigation = navigation
        return Binding(get: { navigation.page }, set: { navigation.select($0) })
    }

    private func rows(_ pages: [SettingsPage]) -> some View {
        ForEach(pages, id: \.self) { page in
            let isSelected = page == navigation.page
            SettingsSidebarRow(page: page, isSelected: isSelected) {
                if page == .permissions {
                    PermissionBadge(schedules: schedules, isSelected: isSelected)
                }
            }
            .tag(page)
        }
    }
}

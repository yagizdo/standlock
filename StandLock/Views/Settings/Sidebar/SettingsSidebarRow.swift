import SwiftUI
import StandLockCore

struct SettingsSidebarRow<Accessory: View>: View {
    let page: SettingsPage
    let isSelected: Bool
    private let accessory: Accessory

    init(page: SettingsPage, isSelected: Bool, @ViewBuilder accessory: () -> Accessory) {
        self.page = page
        self.isSelected = isSelected
        self.accessory = accessory()
    }

    var body: some View {
        Label {
            HStack {
                Text(page.title)
                Spacer(minLength: 0)
                accessory
            }
        } icon: {
            SettingsIconChip(symbol: page.symbol, tone: page.tone, isSelected: isSelected)
        }
    }
}

import SwiftUI
import StandLockCore

struct SettingsSidebarRow: View {
    let page: SettingsPage
    let isSelected: Bool

    var body: some View {
        Label {
            Text(page.title)
        } icon: {
            SettingsIconChip(symbol: page.symbol, tone: page.tone, isSelected: isSelected)
        }
    }
}

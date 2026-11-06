import SwiftUI

struct OpenSettingsCommand: View {
    @Environment(\.openWindow) private var openWindow
    let navigation: SettingsNavigation

    var body: some View {
        Button("Settings...") {
            navigation.open(nil, using: openWindow)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

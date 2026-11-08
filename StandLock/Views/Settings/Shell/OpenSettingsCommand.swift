import SwiftUI

struct OpenSettingsCommand: View {
    @Environment(\.openWindow) private var openWindow
    let navigation: SettingsNavigation

    var body: some View {
        // The commands body runs at launch, so the opener is in place before any reopen.
        let _ = navigation.openWindow = openWindow
        Button("Settings...") {
            navigation.open(nil, using: openWindow)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

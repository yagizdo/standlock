import SwiftUI

/// Saves every preference change while Settings is open. A leaf, so a coordinator publish
/// re-evaluates this body and not the page switch.
struct PreferencesSaveOwner: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .onChange(of: coordinator.preferences) { _ in
                coordinator.savePreferences()
            }
    }
}

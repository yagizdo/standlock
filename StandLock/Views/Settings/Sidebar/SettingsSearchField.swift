import SwiftUI

/// Filters the sidebar. A plain `TextField`: `.searchable` falls back outside a split view.
struct SettingsSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: SettingsTokens.searchFieldSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onExitCommand(perform: onExit)
                .accessibilityLabel("Search settings")
        }
        .padding(SettingsTokens.searchFieldInsets)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: SettingsTokens.searchFieldRadius))
        .background {
            Button("Search settings") { isFocused.wrappedValue = true }
                .keyboardShortcut("f")
                .hidden()
        }
    }
}

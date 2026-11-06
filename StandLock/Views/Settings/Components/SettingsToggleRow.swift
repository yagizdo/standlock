import SwiftUI

struct SettingsToggleRow: View {
    private let title: LocalizedStringKey
    private let symbol: String
    private let description: LocalizedStringKey?
    @Binding private var isOn: Bool

    init(_ title: LocalizedStringKey, symbol: String, description: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.symbol = symbol
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        SettingsRow(title, symbol: symbol, description: description) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

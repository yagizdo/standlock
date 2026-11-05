import SwiftUI

struct SettingsToggleRow: View {
    private let title: LocalizedStringKey
    private let description: LocalizedStringKey?
    @Binding private var isOn: Bool

    init(_ title: LocalizedStringKey, description: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        SettingsRow(title, description: description) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

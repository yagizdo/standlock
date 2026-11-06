import SwiftUI

/// Starts at the row text, past the chip. A block that is not a row keeps a plain `Divider()`.
struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, SettingsTokens.rowTextInset)
    }
}

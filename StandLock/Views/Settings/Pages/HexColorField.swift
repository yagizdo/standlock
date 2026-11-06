import SwiftUI
import StandLockCore

/// Keeps the typed code in its own state so the coordinator's once-a-second updates cannot
/// overwrite an unfinished edit. Commits on Return, when focus leaves or when the page does; an invalid code
/// puts the stored one back.
struct HexColorField: View {
    @Binding var color: HexColor
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Hex Code", text: $text)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .frame(width: 80)
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { focused in
                if !focused { commit() }
            }
            // The colour picker next to the field writes the binding directly.
            .onChange(of: color) { newColor in
                text = newColor.hex
            }
            .onAppear { text = color.hex }
            // Selecting another page removes the field with no focus change to commit on.
            .onDisappear {
                if isFocused { commit() }
            }
    }

    private func commit() {
        if let parsed = HexColor(hex: text) {
            color = parsed
        }
        text = color.hex
    }
}

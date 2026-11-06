import SwiftUI

/// A small speech bubble. The marks are drawing, not text to translate.
struct SceneBubble: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: 0x1B2437))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: 0xF3EFE6)))
    }
}

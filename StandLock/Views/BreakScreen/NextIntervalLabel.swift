import SwiftUI

struct NextIntervalLabel: View {
    let text: String
    let palette: BreakPalette

    var body: some View {
        Text("NEXT: \(text)".uppercased())
            .font(BreakTypography.label(size: 11, weight: .medium))
            .tracking(0.12)
            .foregroundStyle(palette.inkFaint)
    }
}

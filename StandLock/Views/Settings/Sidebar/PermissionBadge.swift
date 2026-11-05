import SwiftUI
import StandLockCore

/// A leaf, so the checker's publishes stop here and never reach the sidebar body.
struct PermissionBadge: View {
    @EnvironmentObject private var checker: PermissionChecker

    let schedules: [Schedule]
    let isSelected: Bool

    var body: some View {
        if schedules.contains(where: checker.strictIsInactive) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                // A fixed hue does not read on the selection fill. `Color.orange` drew white in this
                // sidebar, the AppKit colour did not.
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(Color(nsColor: .systemOrange)))
                .accessibilityLabel(Text("Permission needed"))
        }
    }
}

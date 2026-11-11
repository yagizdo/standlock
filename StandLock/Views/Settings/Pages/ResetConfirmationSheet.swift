import AppKit
import SwiftUI
import StandLockCore

/// The second of the reset's three steps: says what goes and what stays, and keeps Reset off
/// until the phrase is typed. The final alert belongs to `ResetSection`.
struct ResetConfirmationSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var typed = ""

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            Text("Reset StandLock?")
                .font(.headline)

            Text("Your settings, schedules, statistics and break history are deleted, StandLock is removed from your login items, and the app reopens as if newly installed.")
                .fixedSize(horizontal: false, vertical: true)

            Text("Permissions you granted in System Settings (Accessibility, Input Monitoring, Calendars) stay. Remove them there if you want.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Text("Type StandLock to confirm.")
                // No placeholder: a centred "StandLock" in an empty field reads as already typed.
                TextField(text: $typed) {
                    Text("Type StandLock to confirm.")
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive, action: onConfirm) {
                    Text("Reset…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!ResetConfirmation.matches(typed))
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(width: 340)
    }
}

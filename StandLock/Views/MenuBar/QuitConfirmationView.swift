import SwiftUI

/// Asks before the panel's power button quits. A popover, not a modal alert: a break that starts
/// while a modal alert is up would cover the alert and leave the overlay unable to take clicks.
struct QuitConfirmationView: View {
    let cancel: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quit StandLock?")
                    .font(.headline)
                Text("You won't get break reminders until you open StandLock again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Quit", action: quit)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.regular)
        }
        .padding(14)
        .frame(width: 240)
    }
}

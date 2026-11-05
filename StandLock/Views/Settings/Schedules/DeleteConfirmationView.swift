import AppKit
import SwiftUI

struct DeleteConfirmationView: View {
    let scheduleName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Delete Schedule")
                .font(.headline)

            Text("Are you sure you want to delete \"\(scheduleName)\"?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 260)
    }
}

import SwiftUI
import StandLockCore

/// Reset in three steps: this red row, the typed phrase in `ResetConfirmationSheet`, then a
/// final alert. The wipe itself runs in the relaunch shell after this process has exited
/// (`RelaunchScript`): `willTerminate`, `PreferencesSaveOwner` and AppKit's window frames all
/// write on the way out, and a wipe in this process would get those keys back.
struct ResetSection: View {
    @EnvironmentObject private var languageStore: LanguageStore
    @State private var isConfirming = false
    @State private var prompt: Prompt?

    private enum Prompt {
        case finalConfirm
        case blocked
        case failed(message: String)

        var title: LocalizedStringKey {
            switch self {
            case .finalConfirm: "Everything will be deleted"
            case .blocked: "StandLock Cannot Reset Now"
            case .failed: "Could Not Reset StandLock"
            }
        }
    }

    var body: some View {
        SettingsSection("Reset") {
            SettingsRow("Reset StandLock", symbol: "trash", description: "Delete all data and start again from the beginning") {
                Button("Reset…", role: .destructive) { isConfirming = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .sheet(isPresented: $isConfirming) {
            LocalizedRoot(store: languageStore) {
                ResetConfirmationSheet(
                    onCancel: { isConfirming = false },
                    onConfirm: {
                        isConfirming = false
                        // The sheet must be gone before the alert attaches.
                        show(.finalConfirm)
                    }
                )
            }
        }
        // A SwiftUI alert is an attached sheet, so the gate sees it as busy. Never `runModal`:
        // a break can start under it.
        .alert(
            Text(prompt?.title ?? "Everything will be deleted"),
            isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
            presenting: prompt
        ) { prompt in
            switch prompt {
            case .finalConfirm:
                // The alert is still attached while its action runs, and the gate refuses
                // under any sheet, so the reset waits a turn.
                Button("Delete Everything", role: .destructive) { DispatchQueue.main.async(execute: reset) }
                Button("Cancel", role: .cancel) {}
            case .blocked, .failed:
                Button("OK") {}
            }
        } message: { prompt in
            switch prompt {
            case .finalConfirm: Text("This cannot be undone.")
            case .blocked: Text("Try again after the break ends.")
            case .failed(let message): Text(verbatim: message)
            }
        }
    }

    private func show(_ next: Prompt) {
        DispatchQueue.main.async { prompt = next }
    }

    /// Gate and relaunch in one main-actor turn, as `PermissionChecker.relaunch` requires.
    private func reset() {
        guard PermissionChecker.canRelaunchNow else {
            show(.blocked)
            return
        }
        guard let domain = Bundle.main.bundleIdentifier else {
            show(.failed(message: languageStore.string("Could not relaunch StandLock. Please reopen the app manually.")))
            return
        }
        let wasLoginItem = LaunchAtLogin.isRegistered
        // A login item left behind would only open the reset app at the next login, so a
        // failure here does not stop the reset.
        if wasLoginItem { try? LaunchAtLogin.set(false) }
        do {
            try PermissionChecker.relaunch(wipingDefaultsDomain: domain)
        } catch {
            if wasLoginItem { try? LaunchAtLogin.set(true) }
            show(.failed(message: error.localizedDescription))
        }
    }
}

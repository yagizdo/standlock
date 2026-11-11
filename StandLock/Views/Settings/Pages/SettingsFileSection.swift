import AppKit
import SwiftUI
import UniformTypeIdentifiers
import StandLockCore

/// Export and import of settings and schedules as a JSON file. The decisions -- what the
/// file carries, what it refuses, what an import changes -- are in `SettingsExport` and
/// `SettingsImportSummary`; this view runs the panels and applies a confirmed file.
struct SettingsFileSection: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var themeStore: ThemeStore
    @AppStorage(SettingsDescription.showHelpKey) private var showHelp = true
    @State private var prompt: Prompt?

    private enum Prompt {
        case confirm(SettingsExport, message: String)
        case importFailed(message: String)
        case exportFailed(message: String)

        var title: LocalizedStringKey {
            switch self {
            case .confirm: "Import Settings?"
            case .importFailed: "Could Not Import Settings"
            case .exportFailed: "Could Not Export Settings"
            }
        }

        var message: String {
            switch self {
            case .confirm(_, let message), .importFailed(let message), .exportFailed(let message): message
            }
        }
    }

    var body: some View {
        SettingsSection("Settings File") {
            SettingsRow("Export Settings", symbol: "arrow.up.doc", description: "Save your settings and schedules to a file") {
                Button("Export…", action: export)
            }

            SettingsRowDivider()

            SettingsRow(
                "Import Settings",
                symbol: "arrow.down.doc",
                description: "Replace your settings and schedules with the ones in a file"
            ) {
                Button("Import…", action: chooseImport)
            }
        }
        // A SwiftUI alert is an attached sheet on macOS, so the restart gate and the
        // Settings opener treat it as busy. Never `runModal`: a break can start under it.
        .alert(
            Text(prompt?.title ?? "Import Settings?"),
            isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
            presenting: prompt
        ) { prompt in
            switch prompt {
            case .confirm(let export, _):
                Button("Import") { apply(export) }
                Button("Cancel", role: .cancel) {}
            case .importFailed, .exportFailed:
                Button("OK") {}
            }
        } message: { prompt in
            Text(verbatim: prompt.message)
        }
    }

    private var current: SettingsExport {
        SettingsExport(
            preferences: coordinator.preferences,
            schedules: coordinator.schedules,
            theme: themeStore.selection,
            language: languageStore.selection,
            showHelp: showHelp
        )
    }

    private var settingsWindow: NSWindow? {
        NSApp.windows.first { $0.delegate is SettingsWindowDelegate }
    }

    private func export() {
        guard let window = settingsWindow else { return }
        let data: Data
        do {
            data = try current.encoded()
        } catch {
            prompt = .exportFailed(message: error.localizedDescription)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = languageStore.string("StandLock Settings") + ".json"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                show(.exportFailed(message: error.localizedDescription))
            }
        }
    }

    private func chooseImport() {
        guard let window = settingsWindow else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            Task { show(await read(url)) }
        }
    }

    /// The panel's sheet must be gone before the alert attaches, so it waits a turn.
    private func show(_ next: Prompt) {
        DispatchQueue.main.async { prompt = next }
    }

    private func read(_ url: URL) async -> Prompt {
        let error: SettingsImportError
        do {
            let decoded = try await Task.detached(priority: .userInitiated) {
                try SettingsFileReader.read(from: url)
            }.value
            let current = current
            let imported = decoded.keepingKnownChoices(
                languages: languageStore.available,
                themes: themeStore.available.map(\.id),
                current: current
            )
            return .confirm(imported, message: message(for: SettingsImportSummary(current: current, imported: imported)))
        } catch let importError as SettingsImportError {
            error = importError
        } catch {
            // A file the system cannot read reads to the user like a damaged one.
            return .importFailed(message: message(for: .unreadable))
        }
        return .importFailed(message: message(for: error))
    }

    private func apply(_ imported: SettingsExport) {
        coordinator.applyImport(preferences: imported.preferences, schedules: imported.schedules)
        themeStore.select(imported.theme)
        languageStore.select(imported.language)
        showHelp = imported.showHelp
    }

    private func message(for error: SettingsImportError) -> String {
        switch error {
        case .notSettingsFile:
            languageStore.string("This file is not a StandLock settings file.")
        case .newerVersion:
            languageStore.string("This file was made by a newer version of StandLock. Update StandLock to import it.")
        case .unreadable:
            languageStore.string("This file could not be read. It may be damaged or made by a newer version of StandLock.")
        }
    }

    private func message(for summary: SettingsImportSummary) -> String {
        guard !summary.isEmpty else { return languageStore.string("This file matches your current settings.") }
        let formatter = ListFormatter()
        formatter.locale = languageStore.locale
        func list(_ items: [String]) -> String { formatter.string(from: items) ?? items.joined(separator: ", ") }

        var settings = summary.changedPages.map { languageStore.string($0.titleResource) }
        if summary.changesShowHelp { settings.append(languageStore.string("Show help")) }

        var lines: [String] = []
        if !settings.isEmpty { lines.append(languageStore.string("Changes settings: \(list(settings))")) }
        if !summary.addedSchedules.isEmpty { lines.append(languageStore.string("Adds schedules: \(list(summary.addedSchedules))")) }
        if !summary.removedSchedules.isEmpty { lines.append(languageStore.string("Removes schedules: \(list(summary.removedSchedules))")) }
        if !summary.changedSchedules.isEmpty { lines.append(languageStore.string("Changes schedules: \(list(summary.changedSchedules))")) }
        if !summary.turnedOffSchedules.isEmpty {
            lines.append(languageStore.string("Turns off schedules whose hours overlap another: \(list(summary.turnedOffSchedules))"))
        }
        if summary.dropsCalendarSelection {
            lines.append(languageStore.string("Calendar Integration will check all calendars. The file does not carry your calendar choices."))
        }
        return lines.joined(separator: "\n")
    }
}

import Darwin
import Foundation
import Testing
@testable import StandLockCore

@Suite("Settings File Reader")
struct SettingsFileReaderTests {
    private func withFile(_ data: Data, body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("settings.json")
        try data.write(to: file)
        try body(file)
    }

    @Test func normalFileAndSymlinkRemainReadable() throws {
        let export = SettingsExportTests.full()
        try withFile(export.encoded()) { file in
            let decoded = try SettingsFileReader.read(from: file)
            #expect(decoded == export)
            let link = file.deletingLastPathComponent().appendingPathComponent("link.json")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            let linked = try SettingsFileReader.read(from: link)
            #expect(linked == export)
        }
    }

    @Test func oversizedFileIsRejected() throws {
        try withFile(Data(repeating: 0x20, count: SettingsExport.maximumFileSize + 1)) { file in
            #expect(throws: SettingsImportError.tooLarge) { try SettingsFileReader.read(from: file) }
        }
    }

    @Test func fileAtTheByteBudgetRemainsReadable() throws {
        let export = SettingsExportTests.full()
        var data = try export.encoded()
        data.append(Data(repeating: 0x20, count: SettingsExport.maximumFileSize - data.count))
        try withFile(data) { file in
            let decoded = try SettingsFileReader.read(from: file)
            #expect(decoded == export)
        }
    }

    @Test func directoryAndNonFileURLAreRejected() throws {
        try withFile(Data()) { file in
            #expect(throws: SettingsImportError.unreadable) {
                try SettingsFileReader.read(from: file.deletingLastPathComponent())
            }
        }
        #expect(throws: SettingsImportError.unreadable) {
            try SettingsFileReader.read(from: URL(string: "https://example.invalid/settings.json")!)
        }
    }

    @Test func namedPipeIsRejectedWithoutWaitingForAWriter() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        #expect(mkfifo(file.path, 0o600) == 0)
        defer { try? FileManager.default.removeItem(at: file) }
        // A delayed writer lets an accidentally blocking open finish and fail this test.
        let writer = Task.detached {
            try await Task.sleep(for: .seconds(1))
            let descriptor = open(file.path, O_WRONLY | O_NONBLOCK)
            if descriptor >= 0 { close(descriptor) }
        }
        let start = ContinuousClock.now
        #expect(throws: SettingsImportError.unreadable) { try SettingsFileReader.read(from: file) }
        #expect(start.duration(to: .now) < .milliseconds(500))
        try await writer.value
    }
}

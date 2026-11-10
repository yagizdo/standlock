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
        var data = try SettingsExportTests.full().encoded()
        data.append(Data(repeating: 0x20, count: 1_048_577 - data.count))
        try withFile(data) { file in
            #expect(throws: SettingsImportError.unreadable) { try SettingsFileReader.read(from: file) }
        }
    }

    @Test func fileAtTheByteBudgetRemainsReadable() throws {
        let export = SettingsExportTests.full()
        var data = try export.encoded()
        data.append(Data(repeating: 0x20, count: 1_048_576 - data.count))
        try withFile(data) { file in
            let decoded = try SettingsFileReader.read(from: file)
            #expect(decoded == export)
        }
    }

}

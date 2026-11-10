import Foundation

public enum SettingsFileReader {
    /// Rejects settings files larger than 1 MiB before reading and decoding them.
    public static func read(from url: URL) throws -> SettingsExport {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= 1_048_576 else { throw SettingsImportError.unreadable }
        return try SettingsExport.decode(Data(contentsOf: url))
    }
}

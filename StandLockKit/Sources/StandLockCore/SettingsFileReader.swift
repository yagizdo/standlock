import Foundation

public enum SettingsFileReader {
    /// A real settings file is a few KB; anything past this is refused before it is read.
    public static let maxFileSize = 1_048_576

    /// Rejects settings files larger than `maxFileSize` before reading and decoding them.
    public static func read(from url: URL) throws -> SettingsExport {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= maxFileSize else { throw SettingsImportError.unreadable }
        return try SettingsExport.decode(Data(contentsOf: url))
    }
}

import Darwin
import Foundation

public enum SettingsFileReader {
    /// Opens once, accepts regular files, and reads at most the import budget plus one byte.
    public static func read(from url: URL) throws -> SettingsExport {
        guard url.isFileURL, !url.path.utf8.contains(0) else { throw SettingsImportError.unreadable }
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw SettingsImportError.unreadable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw SettingsImportError.unreadable }
        let limit = SettingsExport.maximumFileSize
        guard metadata.st_size <= limit else { throw SettingsImportError.tooLarge }

        var data = Data()
        while data.count <= limit {
            let count = min(64 * 1024, limit + 1 - data.count)
            let chunk = try handle.read(upToCount: count) ?? Data()
            if chunk.isEmpty { return try SettingsExport.decode(data) }
            data.append(chunk)
        }
        throw SettingsImportError.tooLarge
    }
}

import Darwin
import Foundation

/// Checks the executable and the Homebrew code it loads against other accounts' write access.
enum HomebrewTrust {
    static func trustedLink(_ url: URL) -> Bool {
        guard let parent = trustedLocation(url.deletingLastPathComponent()) else { return false }
        let link = parent.appendingPathComponent(url.lastPathComponent)
        var metadata = stat()
        return lstat(link.path, &metadata) == 0
            && metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFLNK)
            && trustedNode(link, metadata: metadata)
    }

    static func executable(in prefix: URL) -> URL? {
        let brew = prefix.appendingPathComponent("bin/brew")
        guard let executable = trustedLocation(brew),
              FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        var metadata = stat()
        guard lstat(executable.path, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { return nil }

        let repository = executable.deletingLastPathComponent().deletingLastPathComponent()
        let environment = ProcessInfo.processInfo.environment
        let configuration = [environment["XDG_CONFIG_HOME"], environment["HOMEBREW_XDG_CONFIG_HOME"]]
            .compactMap { $0 }.first { !$0.isEmpty }
        let userConfig = configuration.map { URL(fileURLWithPath: $0).appendingPathComponent("homebrew") }
            ?? URL(fileURLWithPath: (environment["HOME"] ?? "") + "/.homebrew")
        let sources = ["Library/Homebrew", "Library/Taps", ".git"].map { repository.appendingPathComponent($0) }
            + [prefix.appendingPathComponent("bin"), prefix.appendingPathComponent("etc/homebrew"),
               prefix.appendingPathComponent("Caskroom/standlock/.metadata"),
               URL(fileURLWithPath: "/etc/homebrew"), userConfig]
        for source in sources {
            guard trustedOptionalTree(source) else { return nil }
        }
        return executable
    }

    static func trustedLocation(_ url: URL) -> URL? {
        guard url.isFileURL, !url.path.utf8.contains(0) else { return nil }
        var remaining = Array(url.pathComponents.dropFirst())
        var current = URL(fileURLWithPath: "/")
        var symlinks = 0
        guard trustedNode(current) else { return nil }

        while !remaining.isEmpty {
            let component = remaining.removeFirst()
            if component == "." { continue }
            if component == ".." {
                current.deleteLastPathComponent()
                continue
            }
            let candidate = current.appendingPathComponent(component)
            var metadata = stat()
            guard lstat(candidate.path, &metadata) == 0, trustedNode(candidate, metadata: metadata) else { return nil }
            let kind = metadata.st_mode & mode_t(S_IFMT)
            if kind == mode_t(S_IFLNK) {
                symlinks += 1
                guard symlinks <= 40,
                      let target = try? FileManager.default.destinationOfSymbolicLink(atPath: candidate.path)
                else { return nil }
                var components = (target as NSString).pathComponents
                if target.hasPrefix("/") {
                    current = URL(fileURLWithPath: "/")
                    components.removeFirst()
                }
                remaining = components + remaining
            } else {
                guard remaining.isEmpty || kind == mode_t(S_IFDIR) else { return nil }
                current = candidate
            }
        }
        return current
    }

    private static func trustedNode(_ url: URL, metadata supplied: stat? = nil) -> Bool {
        var metadata = supplied ?? stat()
        guard supplied != nil || lstat(url.path, &metadata) == 0,
              metadata.st_uid == 0 || metadata.st_uid == geteuid() else { return false }
        let kind = metadata.st_mode & mode_t(S_IFMT)
        guard [mode_t(S_IFDIR), mode_t(S_IFREG), mode_t(S_IFLNK)].contains(kind) else { return false }

        // A root-owned sticky directory protects each trusted child's directory entry.
        let stickyRoot = kind == mode_t(S_IFDIR) && metadata.st_uid == 0
            && metadata.st_mode & mode_t(S_ISVTX) != 0
        guard kind == mode_t(S_IFLNK) || stickyRoot || metadata.st_mode & 0o022 == 0 else { return false }
        return hasNoWriteACL(url, metadata: metadata, symbolicLink: kind == mode_t(S_IFLNK))
    }

    private static func hasNoWriteACL(_ url: URL, metadata: stat, symbolicLink: Bool) -> Bool {
        let access = symbolicLink
            ? acl_get_link_np(url.path, ACL_TYPE_EXTENDED)
            : acl_get_file(url.path, ACL_TYPE_EXTENDED)
        guard let access else {
            // Darwin also uses ENOENT for an existing object with no extended ACL.
            guard errno == ENOENT else { return false }
            var current = stat()
            return lstat(url.path, &current) == 0 && current.st_dev == metadata.st_dev
                && current.st_ino == metadata.st_ino && current.st_uid == metadata.st_uid
                && current.st_mode == metadata.st_mode
        }
        defer { acl_free(UnsafeMutableRawPointer(access)) }
        var entry: acl_entry_t?
        var index = Int32(ACL_FIRST_ENTRY.rawValue)
        while acl_get_entry(access, index, &entry) == 0 {
            index = Int32(ACL_NEXT_ENTRY.rawValue)
            guard let entry else { return false }
            var tag = ACL_UNDEFINED_TAG
            var permissions: acl_permset_mask_t = 0
            guard acl_get_tag_type(entry, &tag) == 0,
                  acl_get_permset_mask_np(entry, &permissions) == 0 else { return false }
            let writes = ACL_WRITE_DATA.rawValue | ACL_APPEND_DATA.rawValue | ACL_DELETE.rawValue
                | ACL_DELETE_CHILD.rawValue | ACL_WRITE_ATTRIBUTES.rawValue | ACL_WRITE_EXTATTRIBUTES.rawValue
                | ACL_WRITE_SECURITY.rawValue | ACL_CHANGE_OWNER.rawValue
            if tag == ACL_EXTENDED_ALLOW, permissions & acl_permset_mask_t(writes) != 0 { return false }
        }
        return errno == EINVAL
    }

    private static func trustedOptionalTree(_ root: URL) -> Bool {
        var existing = root
        var metadata = stat()
        while lstat(existing.path, &metadata) != 0 {
            guard errno == ENOENT, existing.path != "/" else { return false }
            existing.deleteLastPathComponent()
        }
        // Checking the existing ancestor also prevents a writable directory from supplying
        // an absent configuration file between validation and invocation.
        guard trustedLocation(existing) != nil else { return false }
        if existing != root { return true }
        return trustedTree(root)
    }

    private static func trustedTree(_ root: URL) -> Bool {
        var pending = [root]
        var visited: Set<String> = []
        while let item = pending.popLast() {
            guard let location = trustedLocation(item), visited.count < 50_000 else { return false }
            guard visited.insert(location.path).inserted else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: location.path, isDirectory: &isDirectory) else { return false }
            if isDirectory.boolValue {
                guard let children = try? FileManager.default.contentsOfDirectory(
                    at: location, includingPropertiesForKeys: nil
                ) else { return false }
                pending.append(contentsOf: children)
            }
        }
        return true
    }
}

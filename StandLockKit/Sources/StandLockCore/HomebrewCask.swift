import Foundation

/// The tap's cask, which decides what a Homebrew install can upgrade to. The appcast can be
/// ahead of it: the release workflow pushes the cask last.
public enum HomebrewCask {
    public static let fullName = "yagizdo/tap/standlock"
    /// `reinstall`, not `upgrade`: a swap that failed and could not roll back leaves its backup
    /// in the Caskroom, and `upgrade` then stops at "already an App". Measured 2026-11-07.
    public static let manualCommand = "brew reinstall --cask \(fullName)"
    public static let sourceURL = URL(
        string: "https://raw.githubusercontent.com/yagizdo/homebrew-tap/master/Casks/standlock.rb"
    )!

    public static func version(inCaskSource source: String) -> String? {
        let prefix = "version \""
        for line in source.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else { continue }
            let value = trimmed.dropFirst(prefix.count).prefix { $0 != "\"" }
            return value.isEmpty ? nil : String(value)
        }
        return nil
    }

    /// ponytail: `0.11` reads as older than `0.11.0` here. Tags are always `X.Y.Z`, so that
    /// pair never occurs; a prerelease tag would need a real comparator.
    public static func isNewer(_ candidate: String, than installed: String) -> Bool {
        candidate.compare(installed, options: .numeric) == .orderedDescending
    }

    /// `brew upgrade` exits 0 with nothing changed when the tap is stale or the receipt is
    /// current, so the version on disk is the only proof.
    public static func upgradeLanded(target: String, diskVersion: String?) -> Bool {
        guard let diskVersion else { return false }
        return !isNewer(target, than: diskVersion)
    }
}

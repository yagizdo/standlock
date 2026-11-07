import Foundation

/// Whether Homebrew owns this bundle. Cask apps are moved to the app folder and Homebrew keeps
/// a symlink to them in the Caskroom, so the bundle's own path shows nothing.
public enum HomebrewInstall {
    public static let caskroomURLs = [
        URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
        URL(fileURLWithPath: "/usr/local/Caskroom"),
    ]

    /// The prefix that owns this bundle. A read-only cask folder returns nil on purpose:
    /// Sparkle can ask for admin rights on a shared Mac, and a sudo-free `brew` cannot.
    public static func prefix(
        appBundleURL: URL,
        caskroomURLs: [URL] = HomebrewInstall.caskroomURLs
    ) -> URL? {
        let manager = FileManager.default
        let bundle = appBundleURL.resolvingSymlinksInPath().standardizedFileURL

        for caskroom in caskroomURLs {
            let token = caskroom.appendingPathComponent("standlock", isDirectory: true)
            guard manager.isWritableFile(atPath: token.path),
                  let versions = try? manager.contentsOfDirectory(
                      at: token,
                      includingPropertiesForKeys: nil,
                      options: .skipsHiddenFiles
                  ) else { continue }

            let linked = versions.contains { version in
                let artifact = version.appendingPathComponent("StandLock.app")
                return (try? manager.destinationOfSymbolicLink(atPath: artifact.path)) != nil
                    && artifact.resolvingSymlinksInPath().standardizedFileURL == bundle
            }
            let prefix = caskroom.deletingLastPathComponent()
            if linked, manager.isExecutableFile(atPath: prefix.appendingPathComponent("bin/brew").path) {
                return prefix
            }
        }
        return nil
    }
}

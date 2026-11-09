import Foundation
import StandLockCore

/// Stands in for Sparkle on a copy Homebrew owns: `brew` keeps the cask receipt right, and the
/// tap, not the appcast, decides what it can install. Sparkle stays unstarted there, so this
/// is the only writer of `UpdateObserver`.
@MainActor
final class HomebrewUpdater {
    private static let lastCheckKey = "homebrewLastCheckDate"

    private let prefix: URL
    private let observer: UpdateObserver
    private let automaticChecks: @MainActor () -> Bool
    private let canRestart: @MainActor () -> Bool
    private var isChecking = false

    init(
        prefix: URL,
        observer: UpdateObserver,
        automaticChecks: @escaping @MainActor () -> Bool,
        canRestart: @escaping @MainActor () -> Bool
    ) {
        self.prefix = prefix
        self.observer = observer
        self.automaticChecks = automaticChecks
        self.canRestart = canRestart
        observer.finishedCheckDate = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    /// Checks at every launch on purpose: a found version lives in memory only. The wait keeps
    /// the first fetch off a network that is still coming up at login.
    func start() {
        Task {
            try? await Task.sleep(for: .seconds(60))
            while !Task.isCancelled {
                if automaticChecks() { check() }
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    func check() {
        guard !isChecking, !observer.homebrewUpgrade.isBusy else { return }
        isChecking = true
        observer.homebrewUpgrade = .idle
        Task {
            await performCheck()
            isChecking = false
        }
    }

    func upgrade() {
        guard !observer.homebrewUpgrade.isBusy, let target = observer.availableVersion else { return }
        guard canRestart() else {
            observer.homebrewUpgrade = .blocked
            return
        }
        observer.homebrewUpgrade = .running
        Task { await performUpgrade(to: target) }
    }

    private func performCheck() async {
        var request = URLRequest(url: HomebrewCask.sourceURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        var latest: String?
        if let (data, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            latest = HomebrewCask.version(inCaskSource: String(decoding: data, as: UTF8.self))
        }

        if let latest, let installed = Self.version(in: Bundle.main.infoDictionary) {
            let isNewer = HomebrewCask.isNewer(latest, than: installed)
            observer.updateAvailable = isNewer
            observer.availableVersion = isNewer ? latest : nil
            observer.onLatestVersion = !isNewer
        } else {
            observer.onLatestVersion = false
        }

        let now = Date()
        observer.finishedCheckDate = now
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
    }

    private func performUpgrade(to target: String) async {
        // Tolerated: an unrelated broken tap fails this too. If our tap stayed stale the upgrade
        // changes nothing, and the version read below reports it.
        guard await run(["update"], timeout: .seconds(120)) else {
            observer.homebrewUpgrade = .failed
            return
        }

        // ponytail: no timeout, so a hung brew leaves the row on running until quit. Killing it
        // mid-swap could leave a broken bundle. `upgrade`, not `reinstall`, because only
        // `upgrade` keeps a backup; a bundle older than a current receipt ends in failed, and
        // the manual `reinstall` command shown then covers it.
        guard await run(["upgrade", "--cask", HomebrewCask.fullName], extraEnvironment: ["HOMEBREW_NO_AUTO_UPDATE": "1"]) else {
            observer.homebrewUpgrade = .failed
            return
        }

        // Not `Bundle`: it keeps returning the running version after the swap.
        let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        let diskVersion = Self.version(in: NSDictionary(contentsOf: plist) as? [String: Any])
        guard HomebrewCask.upgradeLanded(target: target, diskVersion: diskVersion) else {
            observer.homebrewUpgrade = .failed
            return
        }

        while !canRestart() {
            observer.homebrewUpgrade = .waitingToRestart
            try? await Task.sleep(for: .seconds(5))
        }
        do {
            try PermissionChecker.relaunch()
        } catch {
            observer.homebrewUpgrade = .failed
        }
    }

    private static func version(in info: [String: Any]?) -> String? {
        info?["CFBundleShortVersionString"] as? String
    }

    /// A successful launch still needs the on-disk version check to establish an upgrade.
    private func run(
        _ arguments: [String],
        extraEnvironment: [String: String] = [:],
        timeout: Duration? = nil
    ) async -> Bool {
        guard let brew = HomebrewInstall.trustedExecutable(in: prefix) else { return false }
        let process = Process()
        process.executableURL = brew
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment
            .merging([
                "HOMEBREW_NO_SUDO": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "HOMEBREW_NO_INSTALL_CLEANUP": "1",
                "HOMEBREW_NO_UPGRADE_QUIT_CASKS": "1",
            ]) { _, new in new }
            .merging(extraEnvironment) { _, new in new }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            process.terminationHandler = { _ in continuation.resume(returning: true) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: false)
                return
            }
            if let timeout {
                Task {
                    try? await Task.sleep(for: timeout)
                    if process.isRunning { process.terminate() }
                }
            }
        }
    }
}

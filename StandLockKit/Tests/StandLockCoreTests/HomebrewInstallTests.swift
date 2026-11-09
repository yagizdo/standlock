import Foundation
import Testing
@testable import StandLockCore

@Suite("Homebrew Install Tests")
struct HomebrewInstallTests {
    /// A prefix with `bin/brew` and an empty `Caskroom/standlock`, beside a real app bundle.
    private struct Fixture {
        let root: URL
        let prefix: URL
        let caskroom: URL
        let app: URL

        init(prefixName: String = "homebrew") throws {
            let manager = FileManager.default
            root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            prefix = root.appendingPathComponent(prefixName)
            caskroom = prefix.appendingPathComponent("Caskroom")
            app = root.appendingPathComponent("Applications/StandLock.app")

            try manager.createDirectory(at: app, withIntermediateDirectories: true)
            try manager.createDirectory(
                at: caskroom.appendingPathComponent("standlock"),
                withIntermediateDirectories: true
            )
            try addBrew(to: prefix)
        }

        func addBrew(to prefix: URL, executable: Bool = true) throws {
            let manager = FileManager.default
            let bin = prefix.appendingPathComponent("bin")
            try manager.createDirectory(at: bin, withIntermediateDirectories: true)
            let brew = bin.appendingPathComponent("brew")
            manager.createFile(atPath: brew.path, contents: Data())
            try manager.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: brew.path)
        }

        func link(version: String = "0.11.0", in caskroom: URL? = nil, to target: URL? = nil) throws {
            let folder = (caskroom ?? self.caskroom).appendingPathComponent("standlock/\(version)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(
                at: folder.appendingPathComponent("StandLock.app"),
                withDestinationURL: target ?? app
            )
        }

        func cleanUp() {
            let token = caskroom.appendingPathComponent("standlock")
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: token.path)
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func samePath(_ first: URL?, _ second: URL) -> Bool {
        first?.resolvingSymlinksInPath().standardizedFileURL
            == second.resolvingSymlinksInPath().standardizedFileURL
    }

    @Test func aLinkToThisBundleGivesThePrefix() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()

        let prefix = HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom])

        #expect(samePath(prefix, fixture.prefix))
    }

    @Test func aSecondCopyElsewhereIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let copy = fixture.root.appendingPathComponent("Elsewhere/StandLock.app")
        try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)

        #expect(HomebrewInstall.prefix(appBundleURL: copy, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func noCaskroomEntryIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aRealFolderInsteadOfALinkIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let staged = fixture.caskroom.appendingPathComponent("standlock/0.11.0/StandLock.app")
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)

        #expect(HomebrewInstall.prefix(appBundleURL: staged, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aMissingBrewIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        try FileManager.default.removeItem(at: fixture.prefix.appendingPathComponent("bin/brew"))

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aBrewThatCannotRunIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        try FileManager.default.removeItem(at: fixture.prefix.appendingPathComponent("bin/brew"))
        try fixture.addBrew(to: fixture.prefix, executable: false)

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aReadOnlyCaskFolderIsNotBrewManaged() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: fixture.caskroom.appendingPathComponent("standlock").path
        )

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func ofTwoCaskroomsOnlyTheOneResolvingToThisBundleCounts() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()

        let otherPrefix = fixture.root.appendingPathComponent("local")
        let otherCaskroom = otherPrefix.appendingPathComponent("Caskroom")
        let otherApp = fixture.root.appendingPathComponent("Other/StandLock.app")
        try FileManager.default.createDirectory(at: otherApp, withIntermediateDirectories: true)
        try fixture.addBrew(to: otherPrefix)
        try fixture.link(in: otherCaskroom, to: otherApp)

        let prefix = HomebrewInstall.prefix(
            appBundleURL: fixture.app,
            caskroomURLs: [otherCaskroom, fixture.caskroom]
        )

        #expect(samePath(prefix, fixture.prefix))
    }

    @Test func aVersionFolderOlderThanTheBundleStillMatches() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link(version: "0.1.0")

        let prefix = HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom])

        #expect(samePath(prefix, fixture.prefix))
    }

    @Test(arguments: ["", "bin", "bin/brew", "Caskroom", "Caskroom/standlock", "Caskroom/standlock/0.11.0"])
    func writableUpdaterPathsAreNotBrewManaged(relativePath: String) throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let path = relativePath.isEmpty ? fixture.prefix : fixture.prefix.appendingPathComponent(relativePath)
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: path.path)

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aWritableSymlinkTargetAncestorIsRejected() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let manager = FileManager.default
        let writable = fixture.root.appendingPathComponent("Shared")
        try manager.createDirectory(at: writable, withIntermediateDirectories: true)
        try manager.setAttributes([.posixPermissions: 0o777], ofItemAtPath: writable.path)
        let safeBrew = fixture.prefix.appendingPathComponent("bin/brew")
        let intermediate = writable.appendingPathComponent("brew")
        try manager.moveItem(at: safeBrew, to: fixture.root.appendingPathComponent("brew"))
        try manager.createSymbolicLink(at: intermediate, withDestinationURL: fixture.root.appendingPathComponent("brew"))
        try manager.createSymbolicLink(at: safeBrew, withDestinationURL: intermediate)

        #expect(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]) == nil)
    }

    @Test func aTrustedSymlinkedExecutableStillMatches() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let manager = FileManager.default
        let brew = fixture.prefix.appendingPathComponent("bin/brew")
        let repository = fixture.prefix.appendingPathComponent("Homebrew")
        try fixture.addBrew(to: repository)
        try manager.removeItem(at: brew)
        try manager.createSymbolicLink(atPath: brew.path, withDestinationPath: "../Homebrew/bin/brew")

        #expect(samePath(HomebrewInstall.prefix(appBundleURL: fixture.app, caskroomURLs: [fixture.caskroom]), fixture.prefix))
        #expect(samePath(HomebrewInstall.trustedExecutable(in: fixture.prefix), repository.appendingPathComponent("bin/brew")))
    }

    @Test(arguments: ["Library/Homebrew/brew.sh", "Library/Taps/example/tool.rb", ".git/config",
                      "etc/homebrew/brew.env", "bin/git", "Caskroom/standlock/.metadata/1/1/Casks/standlock.rb"])
    func writableLoadedCodeIsRejected(relativePath: String) throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let file = fixture.prefix.appendingPathComponent(relativePath)
        let manager = FileManager.default
        try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        manager.createFile(atPath: file.path, contents: Data())
        try manager.setAttributes([.posixPermissions: 0o666], ofItemAtPath: file.path)

        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) == nil)
    }

    @Test func absentConfigurationCannotBeCreatedThroughWritableParent() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let directory = fixture.prefix.appendingPathComponent("etc")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: directory.path)

        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) == nil)
    }

    @Test func invocationRechecksChangedPermissions() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) != nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o775], ofItemAtPath: fixture.prefix.appendingPathComponent("bin").path)
        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) == nil)
    }

    private func chmod(_ arguments: [String], at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = arguments + [url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func writeACLIsRejected() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let brew = fixture.prefix.appendingPathComponent("bin/brew")
        try chmod(["+a", "everyone allow write"], at: brew)
        defer { try? chmod(["-N"], at: brew) }

        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) == nil)
    }

    @Test func denyOnlyACLStillAllowsTrustedExecutable() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.link()
        let brew = fixture.prefix.appendingPathComponent("bin/brew")
        try chmod(["+a", "everyone deny delete"], at: brew)
        defer { try? chmod(["-N"], at: brew) }

        #expect(HomebrewInstall.trustedExecutable(in: fixture.prefix) != nil)
    }
}

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
}

import Foundation
import Testing
@testable import StandLockCore

/// Runs the real script against a throwaway defaults domain. The bundle path does not exist,
/// so `open` fails and nothing launches.
@Suite("Relaunch Script", .serialized)
struct RelaunchScriptTests {

    private let missingBundle = "/nonexistent/StandLock-relaunch-test.app"

    @Test func wipesTheDomainOnlyAfterTheOldProcessExits() async throws {
        let domain = Self.makeDomain()
        defer { Self.remove(domain) }
        #expect(Self.defaults("write", domain, "probe", "1") == 0)

        let (oldProcess, stdin) = try Self.startWaitingProcess()
        let script = try Self.run(RelaunchScript.arguments(
            bundlePath: missingBundle,
            pid: oldProcess.processIdentifier,
            wipingDefaultsDomain: domain
        ))

        try await Task.sleep(for: .milliseconds(600))
        #expect(script.isRunning)
        #expect(Self.defaults("read", domain, "probe") == 0)

        try stdin.fileHandleForWriting.close()
        oldProcess.waitUntilExit()
        script.waitUntilExit()
        // `defaults read` of the whole domain prints `{}` and exits 0 after a delete.
        #expect(Self.defaults("read", domain, "probe") != 0)
    }

    @Test func keepsTheDomainWithoutAWipe() throws {
        let domain = Self.makeDomain()
        defer { Self.remove(domain) }
        #expect(Self.defaults("write", domain, "probe", "1") == 0)

        let gone = try Self.run(["-c", "exit 0"])
        gone.waitUntilExit()
        let script = try Self.run(RelaunchScript.arguments(
            bundlePath: missingBundle,
            pid: gone.processIdentifier,
            wipingDefaultsDomain: nil
        ))
        script.waitUntilExit()
        #expect(Self.defaults("read", domain, "probe") == 0)
    }

    private static func makeDomain() -> String {
        "com.yagizdokumaci.standlock.tests.relaunch-\(UUID().uuidString)"
    }

    /// `defaults delete` leaves an empty plist behind, so the file goes too.
    private static func remove(_ domain: String) {
        defaults("delete", domain)
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(domain).plist")
        try? FileManager.default.removeItem(at: plist)
    }

    /// A process that lives until its stdin closes, so the test decides when it exits.
    private static func startWaitingProcess() throws -> (Process, Pipe) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/cat")
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        return (process, stdin)
    }

    private static func run(_ shellArguments: [String]) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = shellArguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    @discardableResult
    private static func defaults(_ arguments: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

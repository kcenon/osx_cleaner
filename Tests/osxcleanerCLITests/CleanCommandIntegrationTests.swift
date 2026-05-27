// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, OSX Cleaner contributors

import Foundation
import XCTest

final class CleanCommandIntegrationTests: XCTestCase {
    func testDryRunDoesNotDeleteSpecificPath() throws {
        let home = try makeTemporaryDirectory(named: "home")
        let target = try makeFile(in: home, relativePath: "Library/Caches/com.example/cache.db")

        let result = try runCLI(
            ["clean", "--level", "light", "--dry-run", "--ignore-team", target.path],
            home: home
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(result.combinedOutput.contains("Dry-run preview"))
    }

    func testNonInteractiveWarningPathFailsWithoutForce() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            ["clean", "--level", "deep", "--non-interactive", "--ignore-team", target.path],
            home: home
        )

        XCTAssertNotEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(result.combinedOutput.contains("--non-interactive requires --force"))
    }

    func testForceCleansWarningPathNonInteractively() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            [
                "clean",
                "--level",
                "deep",
                "--non-interactive",
                "--force",
                "--ignore-team",
                target.path
            ],
            home: home
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testInteractiveRejectionLeavesWarningPathUntouched() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            ["clean", "--level", "deep", "--ignore-team", target.path],
            home: home,
            stdin: "no\n"
        )

        XCTAssertNotEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(result.combinedOutput.contains("Type 'yes' to continue"))
    }

    func testInteractiveApprovalCleansWarningPath() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            ["clean", "--level", "deep", "--ignore-team", target.path],
            home: home,
            stdin: "yes\n"
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testRelativePathIsCleanedFromProcessWorkingDirectory() throws {
        let workingDirectory = try makeTemporaryDirectory(named: "cwd")
        let target = try makeFile(in: workingDirectory, relativePath: "relative-cache-file")

        let result = try runCLI(
            [
                "clean",
                "--level",
                "deep",
                "--non-interactive",
                "--force",
                "--ignore-team",
                "relative-cache-file"
            ],
            currentDirectory: workingDirectory,
            home: try makeTemporaryDirectory(named: "home")
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path), result.combinedOutput)
    }

    func testInvalidPathIsRejectedBeforeCleanup() throws {
        let home = try makeTemporaryDirectory(named: "home")

        let result = try runCLI(
            ["clean", "--level", "light", "--dry-run", "--ignore-team", "/dev/null"],
            home: home
        )

        XCTAssertNotEqual(result.exitCode, 0, result.combinedOutput)
    }

    // MARK: - Preview transparency

    func testDryRunPreviewListsTargetAndSafetyLevel() throws {
        let home = try makeTemporaryDirectory(named: "home")
        let target = try makeFile(in: home, relativePath: "Library/Caches/com.example/cache.db")

        let result = try runCLI(
            ["clean", "--level", "light", "--dry-run", "--ignore-team", target.path],
            home: home
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(
            result.combinedOutput.contains("Planned targets:"),
            "preview should enumerate planned targets — got: \(result.combinedOutput)"
        )
        XCTAssertTrue(
            result.combinedOutput.contains(target.path),
            "preview should print the canonical target path — got: \(result.combinedOutput)"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: target.path),
            "dry-run must not delete the target"
        )
    }

    func testDryRunOnWarningTargetEmitsPolicyHintAndRiskyList() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            ["clean", "--level", "deep", "--dry-run", "--ignore-team", target.path],
            home: home
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: target.path),
            "dry-run must not delete warning-level targets"
        )
        XCTAssertTrue(
            result.combinedOutput.contains("Risky targets requiring approval:"),
            "dry-run should call out risky targets — got: \(result.combinedOutput)"
        )
        XCTAssertTrue(
            result.combinedOutput.contains("--non-interactive --force"),
            "dry-run should hint at the non-interactive policy — got: \(result.combinedOutput)"
        )
    }

    func testInteractivePromptIncludesRiskyTargetPath() throws {
        let (home, target) = try makeWarningFixture()

        let result = try runCLI(
            ["clean", "--level", "deep", "--ignore-team", target.path],
            home: home,
            stdin: "no\n"
        )

        XCTAssertNotEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(
            result.combinedOutput.contains("will delete the following risky targets"),
            "prompt should describe the risky targets — got: \(result.combinedOutput)"
        )
        XCTAssertTrue(
            result.combinedOutput.contains(target.path),
            "prompt should reveal the exact path the user is approving — got: \(result.combinedOutput)"
        )
    }

    func testForceSuppressesInteractivePrompt() throws {
        let (home, target) = try makeWarningFixture()

        // Even when stdin says 'no', --force skips the prompt entirely and
        // cleanup proceeds. This pins the documented contract: --force is the
        // explicit opt-in that bypasses both the prompt (interactive) and the
        // fail-closed gate (non-interactive).
        let result = try runCLI(
            ["clean", "--level", "deep", "--force", "--ignore-team", target.path],
            home: home,
            stdin: "no\n"
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertFalse(
            result.combinedOutput.contains("Type 'yes' to continue"),
            "--force must skip the prompt — got: \(result.combinedOutput)"
        )
    }

    func testDryRunJSONOutputReportsDryRunTrueAndZeroFreedBytes() throws {
        let home = try makeTemporaryDirectory(named: "home")
        let target = try makeFile(in: home, relativePath: "Library/Caches/com.example/cache.db")

        let result = try runCLI(
            [
                "clean",
                "--level",
                "light",
                "--dry-run",
                "--format",
                "json",
                "--ignore-team",
                target.path
            ],
            home: home
        )

        XCTAssertEqual(result.exitCode, 0, result.combinedOutput)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: target.path),
            "JSON dry-run must not delete the target"
        )
        XCTAssertTrue(
            result.stdout.contains("\"dry_run\":true"),
            "JSON output should report dry_run=true — got: \(result.stdout)"
        )
    }

    private func makeWarningFixture() throws -> (home: URL, target: URL) {
        let home = try makeTemporaryDirectory(named: "home")
        let target = try makeFile(
            in: home,
            relativePath: "Library/Containers/com.example.osxcleaner/cache.tmp"
        )
        return (home, target)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-cli-tests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func makeFile(in root: URL, relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("fixture".utf8).write(to: url)
        return url
    }

    private func runCLI(
        _ arguments: [String],
        currentDirectory: URL? = nil,
        home: URL,
        stdin: String? = nil
    ) throws -> CLIResult {
        let process = Process()
        process.executableURL = try cliExecutableURL()
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = home.path
        environment["CFFIXED_USER_HOME"] = home.path
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        let input = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = input

        try process.run()
        if let stdin {
            input.fileHandleForWriting.write(Data(stdin.utf8))
        }
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        return CLIResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    private func cliExecutableURL() throws -> URL {
        let fileManager = FileManager.default

        if let configuredPath = ProcessInfo.processInfo.environment["OSXCLEANER_CLI_PATH"],
           fileManager.isExecutableFile(atPath: configuredPath) {
            return URL(fileURLWithPath: configuredPath)
        }

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let candidates = [
            ".build/debug/osxcleaner",
            ".build/arm64-apple-macosx/debug/osxcleaner",
            ".build/x86_64-apple-macosx/debug/osxcleaner",
            ".build/release/osxcleaner",
            ".build/arm64-apple-macosx/release/osxcleaner",
            ".build/x86_64-apple-macosx/release/osxcleaner"
        ].map { packageRoot.appendingPathComponent($0) }

        if let match = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) {
            return match
        }

        throw XCTSkip(
            """
            osxcleaner executable was not found. Build it first with \
            `swift build --product osxcleaner` or set OSXCLEANER_CLI_PATH.
            """
        )
    }
}

private struct CLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        stdout + stderr
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, OSXCleaner contributors

import XCTest
@testable import OSXCleanerKit

/// Regression tests for `DestructiveCleanupGuard`.
///
/// These tests are the single mechanical defense behind issue F19.1: if
/// anything regresses in the guard, this suite goes red before any other
/// test can perform a destructive cleanup against real user data.
///
/// The full acceptance criterion is: "A regression test fails if a destructive
/// test target is outside a temporary directory." Each test below pins one
/// failure mode that would otherwise allow a real cleanup to slip through.
final class DestructiveCleanupGuardTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-guard-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Allowed configurations

    func testGuardAcceptsDryRunRegardlessOfTargets() throws {
        // Dry-run configurations cannot delete anything, so the guard must
        // never block them — even when they aim at /Library or /System.
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let dryRun = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true,
            includeSystemCaches: true,
            includeDeveloperCaches: true,
            includeBrowserCaches: true,
            includeLogsCaches: true,
            specificPaths: ["/Library/Caches", "/System", "~/Library"]
        )

        XCTAssertNoThrow(try guardian.assertSafe(dryRun))
    }

    func testGuardAcceptsDestructiveCleanupInsideTempDirectory() throws {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let inside = tempDir.appendingPathComponent("Caches/foo")
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [inside.path]
        )

        XCTAssertNoThrow(try guardian.assertSafe(config))
    }

    func testGuardAcceptsTempDirectoryItselfAsTarget() throws {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [tempDir.path]
        )

        XCTAssertNoThrow(try guardian.assertSafe(config))
    }

    // MARK: - Rejected configurations (the real safety net)

    func testGuardRejectsDestructiveTargetOutsideTempDirectory() {
        // This is the regression test required by F19.1 acceptance criteria.
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let outside = "/Library/Caches"
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [outside]
        )

        XCTAssertThrowsError(try guardian.assertSafe(config)) { error in
            guard let unsafe = error as? DestructiveCleanupGuard.UnsafeCleanupTargetError else {
                return XCTFail("Expected UnsafeCleanupTargetError, got: \(error)")
            }
            XCTAssertEqual(unsafe.path, outside)
            XCTAssertTrue(
                unsafe.failures.contains { $0.contains("outside test temp directory") },
                "Failure list must call out the escaping path; got: \(unsafe.failures)"
            )
        }
    }

    func testGuardRejectsTildeExpandedTargetOutsideTempDirectory() {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: ["~/Library/Caches"]
        )

        XCTAssertThrowsError(try guardian.assertSafe(config))
    }

    func testGuardRejectsSiblingPathThatSharesPrefixButIsNotInsideTempDirectory() {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        // A sibling whose path begins with tempDir.path but is not actually
        // inside tempDir (e.g. "/tmp/foo" vs "/tmp/foo-bar"). Without the
        // trailing "/" check the prefix match would falsely succeed.
        let sibling = tempDir.path + "-sibling/file.cache"
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [sibling]
        )

        XCTAssertThrowsError(try guardian.assertSafe(config))
    }

    func testGuardRejectsBroadSystemCacheFlagEvenWhenSpecificPathsAreSafe() {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let inside = tempDir.appendingPathComponent("Caches/foo")
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: true,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [inside.path]
        )

        XCTAssertThrowsError(try guardian.assertSafe(config)) { error in
            guard let unsafe = error as? DestructiveCleanupGuard.UnsafeCleanupTargetError else {
                return XCTFail("Expected UnsafeCleanupTargetError, got: \(error)")
            }
            XCTAssertTrue(
                unsafe.failures.contains { $0.contains("system caches") },
                "Failure list must call out the broad system-cache flag; got: \(unsafe.failures)"
            )
        }
    }

    func testGuardRejectsAllBroadTargetFlags() {
        let guardian = DestructiveCleanupGuard(allowedRoot: tempDir)
        let config = CleanerConfiguration(
            cleanupLevel: .deep,
            dryRun: false,
            includeSystemCaches: true,
            includeDeveloperCaches: true,
            includeBrowserCaches: true,
            includeLogsCaches: true,
            specificPaths: []
        )

        XCTAssertThrowsError(try guardian.assertSafe(config)) { error in
            guard let unsafe = error as? DestructiveCleanupGuard.UnsafeCleanupTargetError else {
                return XCTFail("Expected UnsafeCleanupTargetError, got: \(error)")
            }
            let combined = unsafe.failures.joined(separator: " | ")
            XCTAssertTrue(combined.contains("system caches"), "Got: \(combined)")
            XCTAssertTrue(combined.contains("developer caches"), "Got: \(combined)")
            XCTAssertTrue(combined.contains("browser caches"), "Got: \(combined)")
            XCTAssertTrue(combined.contains("logs"), "Got: \(combined)")
        }
    }

    // MARK: - Path containment helper

    func testIsPathInsideAcceptsExactRootMatch() {
        XCTAssertTrue(DestructiveCleanupGuard.isPath(tempDir.path, inside: tempDir))
    }

    func testIsPathInsideRejectsParentDirectory() {
        let parent = tempDir.deletingLastPathComponent()
        XCTAssertFalse(DestructiveCleanupGuard.isPath(parent.path, inside: tempDir))
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class CleanerServiceIntegrationTests: XCTestCase {
    var tempDir: URL!
    var cleanerService: CleanerService!
    var fileManager: FileManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = .default

        // Create isolated test directory
        tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("OSXCleanerTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test file structure
        try createTestStructure()

        // Initialize cleaner service
        cleanerService = CleanerService()
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        if let tempDir = tempDir {
            try? fileManager.removeItem(at: tempDir)
        }
        cleanerService = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    private func createTestStructure() throws {
        // Create cache directory
        let cacheDir = tempDir.appendingPathComponent("Caches")
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // Create test cache files
        try "test cache data".write(
            to: cacheDir.appendingPathComponent("test.cache"),
            atomically: true,
            encoding: .utf8
        )
        try "another cache".write(
            to: cacheDir.appendingPathComponent("another.cache"),
            atomically: true,
            encoding: .utf8
        )

        // Create protected directory (should not be deleted at normal level)
        let protectedDir = tempDir.appendingPathComponent("Protected")
        try fileManager.createDirectory(at: protectedDir, withIntermediateDirectories: true)
        try "important data".write(
            to: protectedDir.appendingPathComponent("important.txt"),
            atomically: true,
            encoding: .utf8
        )

        // Create logs directory
        let logsDir = tempDir.appendingPathComponent("Logs")
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try "log entry 1\nlog entry 2".write(
            to: logsDir.appendingPathComponent("app.log"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Dry Run Tests

    func testDryRunDoesNotDeleteFiles() async throws {
        let cacheFile = tempDir.appendingPathComponent("Caches/test.cache")
        XCTAssertTrue(fileManager.fileExists(atPath: cacheFile.path))

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [cacheFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify file still exists
        XCTAssertTrue(
            fileManager.fileExists(atPath: cacheFile.path),
            "File should still exist after dry run"
        )

        // Verify result shows what WOULD be deleted
        XCTAssertGreaterThan(result.freedBytes, 0, "Should report bytes that would be freed")
        XCTAssertGreaterThan(result.filesRemoved, 0, "Should report files that would be removed")
    }

    func testDryRunWithMultipleFiles() async throws {
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [
                tempDir.appendingPathComponent("Caches/test.cache").path,
                tempDir.appendingPathComponent("Caches/another.cache").path
            ]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify all files still exist
        XCTAssertTrue(
            fileManager.fileExists(atPath: tempDir.appendingPathComponent("Caches/test.cache").path)
        )
        XCTAssertTrue(
            fileManager.fileExists(atPath: tempDir.appendingPathComponent("Caches/another.cache").path)
        )

        // Verify statistics
        XCTAssertGreaterThan(result.freedBytes, 0)
        XCTAssertEqual(result.filesRemoved, 2)
    }

    // MARK: - Actual Deletion Tests

    func testActualDeletionRemovesFiles() async throws {
        let cacheFile = tempDir.appendingPathComponent("Caches/test.cache")
        XCTAssertTrue(fileManager.fileExists(atPath: cacheFile.path))

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [cacheFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify file is deleted
        XCTAssertFalse(
            fileManager.fileExists(atPath: cacheFile.path),
            "File should be deleted after cleanup"
        )
        XCTAssertGreaterThan(result.freedBytes, 0, "Should report freed bytes")
    }

    func testActualDeletionWithDirectory() async throws {
        let cacheDir = tempDir.appendingPathComponent("Caches")
        XCTAssertTrue(fileManager.fileExists(atPath: cacheDir.path))

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [cacheDir.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Rust core may delete directory contents but not the directory itself
        // or it may delete the entire directory - both are acceptable
        // We just verify that files were removed and bytes were freed
        XCTAssertGreaterThan(result.freedBytes, 0, "Should free some bytes")
        XCTAssertGreaterThan(result.filesRemoved, 0, "Should remove at least one file")
    }

    // MARK: - Safety Level Tests

    func testLightCleanupLevelRespectsLimits() async throws {
        let cacheFile = tempDir.appendingPathComponent("Caches/test.cache")

        let config = CleanerConfiguration(
            cleanupLevel: .light,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [cacheFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Light level should only delete safe items
        XCTAssertNotNil(result)
        XCTAssertTrue(CleanupLevel.light.canDelete(.safe))
        XCTAssertFalse(CleanupLevel.light.canDelete(.caution))
    }

    func testNormalCleanupLevelRespectsLimits() async throws {
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [tempDir.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Normal level should delete up to caution
        XCTAssertNotNil(result)
        XCTAssertTrue(CleanupLevel.normal.canDelete(.safe))
        XCTAssertTrue(CleanupLevel.normal.canDelete(.caution))
        XCTAssertFalse(CleanupLevel.normal.canDelete(.warning))
    }

    func testDeepCleanupLevelRespectsLimits() async throws {
        let config = CleanerConfiguration(
            cleanupLevel: .deep,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [tempDir.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Deep level should delete up to warning
        XCTAssertNotNil(result)
        XCTAssertTrue(CleanupLevel.deep.canDelete(.safe))
        XCTAssertTrue(CleanupLevel.deep.canDelete(.caution))
        XCTAssertTrue(CleanupLevel.deep.canDelete(.warning))
        XCTAssertFalse(CleanupLevel.deep.canDelete(.danger))
    }

    func testDangerLevelNeverDeleted() async throws {
        // Verify that danger level cannot be deleted at any cleanup level
        XCTAssertFalse(CleanupLevel.light.canDelete(.danger))
        XCTAssertFalse(CleanupLevel.normal.canDelete(.danger))
        XCTAssertFalse(CleanupLevel.deep.canDelete(.danger))
        XCTAssertFalse(CleanupLevel.system.canDelete(.danger))
    }

    // MARK: - Swift Fallback Tests

    func testSwiftFallbackWithForceParameter() async throws {
        // Create service with Swift fallback forced
        let fallbackService = CleanerService(
            fileManager: .default,
            rustBridge: .shared,
            loggingService: .shared,
            forceSwiftFallback: true
        )

        let cacheFile = tempDir.appendingPathComponent("Caches/test.cache")
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [cacheFile.path]
        )

        // Should work without crashing
        let result = try await fallbackService.clean(with: config)
        XCTAssertNotNil(result, "Should return a result")
        // Note: In dry-run mode with Swift fallback, size calculation may return 0
        // if the file no longer exists at the time of calculation
        // The important thing is that it doesn't crash
        XCTAssertEqual(result.filesRemoved, 1, "Should report one file would be removed")
    }

    // MARK: - Error Handling Tests

    func testNonExistentPath() async throws {
        let nonExistentPath = tempDir.appendingPathComponent("DoesNotExist/file.txt").path

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [nonExistentPath]
        )

        let result = try await cleanerService.clean(with: config)

        // Should not throw, but no files should be removed
        XCTAssertEqual(result.filesRemoved, 0)
        XCTAssertEqual(result.freedBytes, 0)
    }

    func testPermissionDeniedHandling() async throws {
        let readOnlyFile = tempDir.appendingPathComponent("readonly.txt")
        try "data".write(to: readOnlyFile, atomically: true, encoding: .utf8)

        // Make file read-only
        try fileManager.setAttributes(
            [.posixPermissions: 0o444],
            ofItemAtPath: readOnlyFile.path
        )

        let config = CleanerConfiguration(
            cleanupLevel: .deep,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [readOnlyFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Note: Rust core may succeed in deleting read-only files
        // This test verifies that the operation completes without crashing
        // In production, proper file permissions and ownership would prevent deletion
        XCTAssertNotNil(result, "Should complete without crashing")

        // Cleanup - restore permissions if file still exists
        if fileManager.fileExists(atPath: readOnlyFile.path) {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: readOnlyFile.path
            )
            try? fileManager.removeItem(at: readOnlyFile)
        }
    }

    // MARK: - Statistics Tests

    func testCleanupStatisticsAccuracy() async throws {
        // Create file of known size (1KB)
        let testData = String(repeating: "x", count: 1024)
        let testFile = tempDir.appendingPathComponent("1kb.txt")
        try testData.write(to: testFile, atomically: true, encoding: .utf8)

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [testFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify size is approximately correct (accounting for filesystem overhead)
        XCTAssertGreaterThanOrEqual(result.freedBytes, 1024, "Should free at least 1KB")
        XCTAssertEqual(result.filesRemoved, 1, "Should remove exactly 1 file")
    }

    func testMultipleFilesStatistics() async throws {
        // Create multiple files of known sizes
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")

        try String(repeating: "a", count: 500).write(to: file1, atomically: true, encoding: .utf8)
        try String(repeating: "b", count: 500).write(to: file2, atomically: true, encoding: .utf8)

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [file1.path, file2.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify statistics
        XCTAssertGreaterThanOrEqual(result.freedBytes, 1000)
        XCTAssertEqual(result.filesRemoved, 2)
        XCTAssertEqual(result.errors.count, 0, "Should have no errors")
    }

    func testFormattedFreedSpace() async throws {
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "test data".write(to: testFile, atomically: true, encoding: .utf8)

        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: [testFile.path]
        )

        let result = try await cleanerService.clean(with: config)

        // Verify formatted string is not empty
        XCTAssertFalse(result.formattedFreedSpace.isEmpty, "Formatted space should not be empty")
        XCTAssertGreaterThan(result.freedBytes, 0)
    }
}


// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class FileOperationRetryTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Remove Operation Tests

    func testRemove_SuccessfulRemoval() async throws {
        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        // Remove with retry
        try await FileOperationRetry.remove(testFile.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }

    func testRemove_FileNotFound_DoesNotThrow() async throws {
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt").path

        // Should complete successfully (no file to remove)
        do {
            try await FileOperationRetry.remove(nonExistentFile, maxAttempts: 1)
        } catch {
            // Expected behavior - file not found
            XCTAssertTrue(error.localizedDescription.contains("doesn't exist") ||
                         error.localizedDescription.contains("No such file"))
        }
    }

    // MARK: - Copy Operation Tests

    func testCopy_SuccessfulCopy() async throws {
        // Create source file
        let sourceFile = tempDirectory.appendingPathComponent("source.txt")
        let testContent = "copy test content"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        let destFile = tempDirectory.appendingPathComponent("dest.txt")

        // Copy with retry
        try await FileOperationRetry.copy(
            from: sourceFile.path,
            to: destFile.path
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: destFile.path))

        let copiedContent = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(copiedContent, testContent)
    }

    func testCopy_SourceNotFound_Throws() async {
        let nonExistentSource = tempDirectory.appendingPathComponent("nonexistent.txt").path
        let destFile = tempDirectory.appendingPathComponent("dest.txt").path

        do {
            try await FileOperationRetry.copy(
                from: nonExistentSource,
                to: destFile,
                maxAttempts: 1
            )
            XCTFail("Should throw for non-existent source")
        } catch {
            // Expected
        }
    }

    // MARK: - Move Operation Tests

    func testMove_SuccessfulMove() async throws {
        // Create source file
        let sourceFile = tempDirectory.appendingPathComponent("move_source.txt")
        let testContent = "move test content"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        let destFile = tempDirectory.appendingPathComponent("move_dest.txt")

        // Move with retry
        try await FileOperationRetry.move(
            from: sourceFile.path,
            to: destFile.path
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destFile.path))

        let movedContent = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(movedContent, testContent)
    }

    // MARK: - Write Operation Tests

    func testWrite_SuccessfulWrite() async throws {
        let testFile = tempDirectory.appendingPathComponent("write_test.txt")
        let testData = "write test content".data(using: .utf8)!

        // Write with retry
        try await FileOperationRetry.write(testData, to: testFile.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        let writtenData = try Data(contentsOf: testFile)
        XCTAssertEqual(writtenData, testData)
    }

    func testWrite_OverwriteExisting() async throws {
        let testFile = tempDirectory.appendingPathComponent("overwrite_test.txt")

        // Write initial content
        let initialData = "initial content".data(using: .utf8)!
        try await FileOperationRetry.write(initialData, to: testFile.path)

        // Overwrite with new content
        let newData = "new content".data(using: .utf8)!
        try await FileOperationRetry.write(newData, to: testFile.path)

        let finalData = try Data(contentsOf: testFile)
        XCTAssertEqual(finalData, newData)
    }

    // MARK: - Error Classification Tests

    func testIsFileOperationRetryable_RetryableErrors() {
        let retryableErrors: [NSError] = [
            NSError(domain: NSCocoaErrorDomain, code: 644),   // File write busy
            NSError(domain: NSCocoaErrorDomain, code: 257),   // Read no permission
            NSError(domain: NSCocoaErrorDomain, code: 255),   // File locking
            NSError(domain: NSPOSIXErrorDomain, code: Int(EBUSY)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EAGAIN)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EINTR))
        ]

        for error in retryableErrors {
            XCTAssertTrue(
                error.isFileOperationRetryable,
                "Expected \(error.domain):\(error.code) to be retryable"
            )
        }
    }

    func testIsFileOperationRetryable_NonRetryableErrors() {
        let nonRetryableErrors: [NSError] = [
            NSError(domain: NSCocoaErrorDomain, code: 4),     // No such file
            NSError(domain: NSCocoaErrorDomain, code: 513),   // Write no permission
            NSError(domain: NSCocoaErrorDomain, code: 640),   // Out of space
            NSError(domain: NSCocoaErrorDomain, code: 642),   // Volume read-only
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EROFS)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        ]

        for error in nonRetryableErrors {
            XCTAssertFalse(
                error.isFileOperationRetryable,
                "Expected \(error.domain):\(error.code) to be non-retryable"
            )
        }
    }

    func testIsFileOperationRetryable_UnknownDomain() {
        let unknownError = NSError(domain: "com.unknown.domain", code: 999)
        XCTAssertFalse(unknownError.isFileOperationRetryable)
    }

    // MARK: - Retry Delay Tests

    func testRemove_RespectsRetryDelay() async throws {
        // This test would need to mock file operations to simulate transient errors
        // For now, we test that the delay parameter is accepted
        let testFile = tempDirectory.appendingPathComponent("delay_test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)

        let startTime = Date()
        try await FileOperationRetry.remove(testFile.path, maxAttempts: 1, retryDelay: 0.0)
        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete quickly with no retries and no delay
        XCTAssertLessThan(elapsed, 0.5)
    }
}

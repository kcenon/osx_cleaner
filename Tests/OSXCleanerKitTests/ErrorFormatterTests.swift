// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest

@testable import OSXCleanerKit

final class ErrorFormatterTests: XCTestCase {
    // MARK: - DetailedError Formatting Tests

    func testFormat_ValidationError_IncludesProblem() {
        let error = ValidationError.pathNotFound("/nonexistent/path")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Error:"))
        XCTAssertTrue(formatted.contains("/nonexistent/path"))
    }

    func testFormat_ValidationError_IncludesContext() {
        let error = ValidationError.systemPathNotAllowed("/System/Library")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("protected"))
    }

    func testFormat_ValidationError_IncludesSolution() {
        let error = ValidationError.invalidCleanupLevel(99)
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Suggestion:"))
        XCTAssertTrue(formatted.contains("Valid cleanup levels"))
    }

    func testFormat_ValidationError_IncludesDocumentation() {
        let error = ValidationError.invalidCleanupLevel(99)
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Learn more:"))
        XCTAssertTrue(formatted.contains("github.com"))
    }

    // MARK: - CleanupError Tests

    func testFormat_CleanupError_SystemPathProtected() {
        let error = CleanupError.systemPathProtected("/System/Library")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Cannot clean system directory"))
        XCTAssertTrue(formatted.contains("/System/Library"))
        XCTAssertTrue(formatted.contains("protected"))
        XCTAssertTrue(formatted.contains("Suggestion:"))
    }

    func testFormat_CleanupError_InsufficientPermissions() {
        let error = CleanupError.insufficientPermissions("/Library/Caches")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Permission denied"))
        XCTAssertTrue(formatted.contains("sudo"))
    }

    func testFormat_CleanupError_DiskFull() {
        let error = CleanupError.diskFull(available: 100_000_000, required: 500_000_000)
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Insufficient disk space"))
        XCTAssertTrue(formatted.contains("Free up space"))
    }

    // MARK: - RustBridgeError Tests

    func testFormat_RustBridgeError_InitializationFailed() {
        let error = RustBridgeError.initializationFailed
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Rust core initialization failed"))
        XCTAssertTrue(formatted.contains("dylib"))
        XCTAssertTrue(formatted.contains("Reinstall"))
    }

    func testFormat_RustBridgeError_InvalidString() {
        let error = RustBridgeError.invalidString("contains null byte")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Invalid string"))
        XCTAssertTrue(formatted.contains("UTF-8"))
    }

    // MARK: - Color Formatting Tests

    func testFormat_WithColors_IncludesANSICodes() {
        let error = ValidationError.emptyPath
        let formatted = ErrorFormatter.format(error, useColors: true)

        XCTAssertTrue(formatted.contains("\u{001B}["))
    }

    func testFormat_WithoutColors_NoANSICodes() {
        let error = ValidationError.emptyPath
        let formatted = ErrorFormatter.format(error, useColors: false)

        XCTAssertFalse(formatted.contains("\u{001B}["))
    }

    // MARK: - Non-DetailedError Tests

    func testFormat_GenericError_ShowsLocalizedDescription() {
        struct GenericError: Error, LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }

        let error = GenericError()
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Error:"))
        XCTAssertTrue(formatted.contains("Something went wrong"))
    }

    // MARK: - ANSI Color Tests

    func testTerminalSupportsColors_IsAccessible() {
        // This test verifies the property is accessible
        _ = ErrorFormatter.terminalSupportsColors
    }

    func testANSIColor_Reset_IsCorrectValue() {
        XCTAssertEqual(ANSIColor.reset.rawValue, "0")
    }

    func testANSIColor_Red_IsCorrectValue() {
        XCTAssertEqual(ANSIColor.red.rawValue, "31")
    }

    // MARK: - Edge Cases

    func testFormat_EmptyPathError_HasAllComponents() {
        let error = ValidationError.emptyPath
        let formatted = ErrorFormatter.format(error)

        // Should have problem
        XCTAssertTrue(formatted.contains("No path specified"))

        // Should have context
        XCTAssertTrue(formatted.contains("target path is required"))

        // Should have solution
        XCTAssertTrue(formatted.contains("Specify a path"))
    }

    func testFormat_ConflictingOptionsError_ShowsMessage() {
        let error = ValidationError.conflictingOptions("Cannot use --quiet with --verbose")
        let formatted = ErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("Conflicting options"))
        XCTAssertTrue(formatted.contains("--quiet"))
        XCTAssertTrue(formatted.contains("--verbose"))
    }
}

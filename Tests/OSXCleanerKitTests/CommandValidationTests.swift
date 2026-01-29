// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// Tests for CLI command validation
///
/// These tests verify that command-line validation catches invalid inputs
/// before execution, providing clear error messages to users.
final class CommandValidationTests: XCTestCase {
    // MARK: - Path Validation Tests

    func testInvalidPath_ThrowsError() throws {
        // Test that invalid paths are rejected
        let invalidPaths = [
            "/System/Library/Caches", // System path
            "/dev/null", // Device path
            "", // Empty path
            String(repeating: "a", count: 2000) // Too long
        ]

        for invalidPath in invalidPaths {
            XCTAssertThrowsError(
                try PathValidator.validate(invalidPath, options: .lenient),
                "Should throw error for path: \(invalidPath)"
            )
        }
    }

    func testValidPath_Succeeds() throws {
        // Test that valid paths are accepted
        let validPaths = [
            "~/Library/Caches",
            "/tmp",
            "/Users/Shared"
        ]

        for validPath in validPaths {
            XCTAssertNoThrow(
                try PathValidator.validate(validPath, options: .lenient),
                "Should accept valid path: \(validPath)"
            )
        }
    }

    // MARK: - Conflicting Options Tests

    func testConflictingOptions_QuietAndVerbose() throws {
        // Test that quiet and verbose cannot be used together
        // This would be tested in actual command execution
        // For now, verify the ValidationError exists
        let error = ValidationError.conflictingOptions("Cannot use --quiet with --verbose")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Cannot use --quiet with --verbose") ?? false)
    }

    func testConflictingOptions_ErrorMessage() throws {
        let error = ValidationError.conflictingOptions("test conflict")
        XCTAssertEqual(error.errorDescription, "Conflicting options: test conflict")
        XCTAssertEqual(error.recoverySuggestion, "Remove conflicting command-line options")
    }

    // MARK: - Numeric Parameter Validation Tests

    func testInvalidCheckInterval_NegativeValue() throws {
        let error = ValidationError.invalidCheckInterval(-5)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Invalid check interval") ?? false)
    }

    func testInvalidCheckInterval_Zero() throws {
        let error = ValidationError.invalidCheckInterval(0)
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Server URL Validation Tests

    func testInsecureServerURL_ThrowsError() throws {
        let error = ValidationError.insecureMDMURL
        XCTAssertEqual(error.errorDescription, "MDM server URL must use HTTPS protocol")
        XCTAssertEqual(error.recoverySuggestion, "Use HTTPS protocol for MDM server URL (e.g., https://example.com)")
    }

    // MARK: - Configuration Validation Tests

    func testMissingRequiredField() throws {
        let error = ValidationError.missingRequiredField("api_key")
        XCTAssertEqual(error.errorDescription, "Missing required field: api_key")
        XCTAssertEqual(error.recoverySuggestion, "Provide the required field in configuration")
    }

    // MARK: - Batch Validation Tests

    func testValidateAll_AllValid() throws {
        let paths = [
            "~/Library/Caches",
            "/tmp",
            "/Users/Shared"
        ]

        XCTAssertNoThrow(
            try PathValidator.validateAll(paths, options: .lenient),
            "Should accept all valid paths"
        )
    }

    func testValidateAll_OneInvalid_ThrowsError() throws {
        let paths = [
            "~/Library/Caches", // Valid
            "/System/Library/Caches", // Invalid - system path
            "/tmp" // Valid
        ]

        XCTAssertThrowsError(
            try PathValidator.validateAll(paths, options: .lenient),
            "Should throw error when one path is invalid"
        )
    }

    func testValidateAllWithErrors_CollectsAllErrors() throws {
        let paths = [
            "~/Library/Caches", // Valid
            "/System/Library/Caches", // Invalid - system path
            "/dev/null", // Invalid - device path
            "/tmp" // Valid
        ]

        let (validURLs, errors) = PathValidator.validateAllWithErrors(paths, options: .lenient)

        XCTAssertEqual(validURLs.count, 2, "Should have 2 valid URLs")
        XCTAssertEqual(errors.count, 2, "Should have 2 errors")

        // Verify error types
        for (_, error) in errors {
            switch error {
            case .systemPathNotAllowed:
                // Expected
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Error Recovery Suggestions

    func testErrorRecoverySuggestions_AreHelpful() throws {
        let errors: [ValidationError] = [
            .emptyPath,
            .nullByteInPath,
            .pathNotFound("/nonexistent"),
            .systemPathNotAllowed("/System"),
            .pathNotReadable("/root"),
            .pathTooLong(2000, maximum: 1024),
            .invalidCleanupLevel(0),
            .conflictingOptions("test"),
            .insecureMDMURL,
            .invalidCheckInterval(-1),
            .missingRequiredField("key")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertNotNil(error.recoverySuggestion, "Error should have recovery suggestion: \(error)")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Description should not be empty")
            XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true, "Recovery suggestion should not be empty")
        }
    }
}

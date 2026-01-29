// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// Tests for RustBridge FFI input validation
///
/// These tests verify that the FFI boundary properly validates
/// input strings before passing them to Rust, preventing:
/// - Null bytes in C strings
/// - Invalid UTF-8 sequences
/// - DoS attacks via extremely long strings
final class RustBridgeValidationTests: XCTestCase {

    var bridge: RustBridge!

    override func setUp() {
        super.setUp()
        bridge = RustBridge.shared
        try? bridge.initialize()
    }

    // MARK: - Null Byte Validation Tests

    func testAnalyzePath_NullByte_ThrowsError() {
        // Null bytes are invalid in C strings
        let pathWithNull = "/tmp\u{0000}/test"

        XCTAssertThrowsError(try bridge.analyzePath(pathWithNull)) { error in
            guard let bridgeError = error as? RustBridgeError else {
                XCTFail("Expected RustBridgeError, got \(type(of: error))")
                return
            }

            if case .invalidString(let message) = bridgeError {
                XCTAssertTrue(message.contains("null byte"),
                             "Error message should mention null byte: \(message)")
            } else {
                XCTFail("Expected invalidString error, got \(bridgeError)")
            }
        }
    }

    func testCalculateSafety_NullByte_ThrowsError() {
        let pathWithNull = "/usr/bin\u{0000}malicious"

        XCTAssertThrowsError(try bridge.calculateSafety(for: pathWithNull)) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString(let message) = bridgeError else {
                XCTFail("Expected invalidString error")
                return
            }
            XCTAssertTrue(message.contains("null byte"))
        }
    }

    func testCleanPath_NullByte_ThrowsError() {
        let pathWithNull = "/tmp/cache\u{0000}inject"

        XCTAssertThrowsError(
            try bridge.cleanPath(pathWithNull, cleanupLevel: .light, dryRun: true)
        ) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString(let message) = bridgeError else {
                XCTFail("Expected invalidString error")
                return
            }
            XCTAssertTrue(message.contains("null byte"))
        }
    }

    // MARK: - Length Limit Tests

    func testAnalyzePath_TooLong_ThrowsError() {
        // String exceeding 4096 character limit
        let longPath = "/" + String(repeating: "a", count: 5000)

        XCTAssertThrowsError(try bridge.analyzePath(longPath)) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString(let message) = bridgeError else {
                XCTFail("Expected invalidString error")
                return
            }
            XCTAssertTrue(message.contains("maximum length") || message.contains("4096"),
                         "Error message should mention maximum length: \(message)")
        }
    }

    func testCalculateSafety_TooLong_ThrowsError() {
        let longPath = String(repeating: "/very/long/path", count: 300)

        XCTAssertThrowsError(try bridge.calculateSafety(for: longPath)) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString(let message) = bridgeError else {
                XCTFail("Expected invalidString error")
                return
            }
            XCTAssertTrue(message.contains("maximum length") || message.contains("4096"))
        }
    }

    func testCleanPath_TooLong_ThrowsError() {
        let longPath = String(repeating: "x", count: 5000)

        XCTAssertThrowsError(
            try bridge.cleanPath(longPath, cleanupLevel: .normal, dryRun: true)
        ) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString(let message) = bridgeError else {
                XCTFail("Expected invalidString error")
                return
            }
            XCTAssertTrue(message.contains("maximum length") || message.contains("4096"))
        }
    }

    // MARK: - Valid String Tests

    func testAnalyzePath_ValidString_Succeeds() {
        // Normal valid path should work
        let validPath = "/tmp"

        // Should not throw (might fail for other reasons like permissions)
        _ = try? bridge.analyzePath(validPath)
    }

    func testAnalyzePath_EmptyString_HandledGracefully() {
        // Empty string should be handled (might fail validation in Rust, but not in Swift)
        let emptyPath = ""

        // Should not crash - may throw other errors
        _ = try? bridge.analyzePath(emptyPath)
    }

    func testAnalyzePath_UnicodeCharacters_Succeeds() {
        // Valid Unicode should work
        let unicodePaths = [
            "/tmp/한글",
            "/tmp/中文",
            "/tmp/日本語",
            "/tmp/Русский"
        ]

        for path in unicodePaths {
            // Should not throw invalidString error
            do {
                _ = try bridge.analyzePath(path)
            } catch let error as RustBridgeError {
                // InvalidString should not be thrown for valid Unicode
                if case .invalidString = error {
                    XCTFail("Valid Unicode path should not throw invalidString: \(path)")
                }
            } catch {
                // Other errors (like path not found) are acceptable
            }
        }
    }

    func testCalculateSafety_ValidString_Succeeds() throws {
        let validPath = "/tmp"

        // Should return a valid safety level
        let safetyLevel = try bridge.calculateSafety(for: validPath)
        XCTAssertTrue((1...4).contains(safetyLevel.rawValue))
    }

    // MARK: - Boundary Cases

    func testAnalyzePath_ExactlyMaxLength_Succeeds() {
        // String exactly at 4096 character limit should succeed
        let maxPath = "/" + String(repeating: "a", count: 4095)

        // Should not throw invalidString error
        do {
            _ = try bridge.analyzePath(maxPath)
        } catch let error as RustBridgeError {
            if case .invalidString = error {
                XCTFail("Path at exactly max length should not throw invalidString")
            }
        } catch {
            // Other errors are acceptable
        }
    }

    func testAnalyzePath_OneBeyondMaxLength_ThrowsError() {
        // String at 4097 characters should fail
        let tooLongPath = "/" + String(repeating: "b", count: 4096)

        XCTAssertThrowsError(try bridge.analyzePath(tooLongPath)) { error in
            guard let bridgeError = error as? RustBridgeError,
                  case .invalidString = bridgeError else {
                XCTFail("Expected invalidString error for path exceeding max length")
                return
            }
        }
    }

    // MARK: - Error Message Clarity Tests

    func testNullByteError_HasClearMessage() {
        let pathWithNull = "/test\u{0000}injection"

        do {
            _ = try bridge.analyzePath(pathWithNull)
            XCTFail("Expected error to be thrown")
        } catch let error as RustBridgeError {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(description.contains("null byte") || description.contains("invalid"),
                         "Error description should be clear: \(description)")
        } catch {
            XCTFail("Expected RustBridgeError")
        }
    }

    func testLengthLimitError_HasClearMessage() {
        let longPath = String(repeating: "x", count: 5000)

        do {
            _ = try bridge.analyzePath(longPath)
            XCTFail("Expected error to be thrown")
        } catch let error as RustBridgeError {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(description.contains("length") || description.contains("4096"),
                         "Error description should mention length limit: \(description)")
        } catch {
            XCTFail("Expected RustBridgeError")
        }
    }

    // MARK: - Security Tests (Fuzzing-style)

    func testMultipleNullBytes_AllRejected() {
        let pathsWithNullBytes = [
            "\u{0000}/tmp",
            "/tmp/\u{0000}",
            "/\u{0000}tmp\u{0000}/test",
            "\u{0000}\u{0000}\u{0000}"
        ]

        for path in pathsWithNullBytes {
            XCTAssertThrowsError(try bridge.analyzePath(path),
                                "Path with null bytes should be rejected: \(path.debugDescription)")
        }
    }

    func testVeryLongStrings_AllRejected() {
        let lengths = [5000, 10000, 100000]

        for length in lengths {
            let longPath = String(repeating: "a", count: length)
            XCTAssertThrowsError(try bridge.analyzePath(longPath),
                                "Path exceeding max length should be rejected: \(length) chars")
        }
    }

    // MARK: - All FFI Methods Validation

    func testAllFFIMethods_RejectNullBytes() {
        let pathWithNull = "/test\u{0000}malicious"

        // analyzePath
        XCTAssertThrowsError(try bridge.analyzePath(pathWithNull))

        // calculateSafety
        XCTAssertThrowsError(try bridge.calculateSafety(for: pathWithNull))

        // cleanPath
        XCTAssertThrowsError(
            try bridge.cleanPath(pathWithNull, cleanupLevel: .light, dryRun: true)
        )
    }

    func testAllFFIMethods_RejectTooLong() {
        let longPath = String(repeating: "x", count: 5000)

        // analyzePath
        XCTAssertThrowsError(try bridge.analyzePath(longPath))

        // calculateSafety
        XCTAssertThrowsError(try bridge.calculateSafety(for: longPath))

        // cleanPath
        XCTAssertThrowsError(
            try bridge.cleanPath(longPath, cleanupLevel: .normal, dryRun: true)
        )
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class FFIErrorRecoveryTests: XCTestCase {
    // MARK: - Retry Logic Tests

    func testWithRetry_SuccessOnFirstAttempt() async throws {
        var callCount = 0

        let result = try await FFIErrorRecovery.withRetry {
            callCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1)
    }

    func testWithRetry_SuccessOnSecondAttempt() async throws {
        var callCount = 0

        let result = try await FFIErrorRecovery.withRetry(maxAttempts: 3, baseDelay: 0.1) {
            callCount += 1
            if callCount == 1 {
                // First attempt: simulate transient error
                throw RustBridgeError.rustError("temporarily unavailable")
            }
            return "success after retry"
        }

        XCTAssertEqual(result, "success after retry")
        XCTAssertEqual(callCount, 2)
    }

    func testWithRetry_ExhaustsAllAttempts() async {
        var callCount = 0

        do {
            _ = try await FFIErrorRecovery.withRetry(maxAttempts: 3, baseDelay: 0.1) {
                callCount += 1
                throw RustBridgeError.rustError("resource busy")
            }
            XCTFail("Should have thrown after exhausting retries")
        } catch let error as RustBridgeError {
            XCTAssertEqual(callCount, 3)
            if case .rustError(let message) = error {
                XCTAssertEqual(message, "resource busy")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWithRetry_PermanentErrorFailsImmediately() async {
        var callCount = 0

        do {
            _ = try await FFIErrorRecovery.withRetry(maxAttempts: 3, baseDelay: 0.1) {
                callCount += 1
                throw RustBridgeError.invalidString("null byte in string")
            }
            XCTFail("Should have thrown immediately for permanent error")
        } catch {
            // Should fail on first attempt without retry
            XCTAssertEqual(callCount, 1)
        }
    }

    // MARK: - Error Classification Tests

    func testIsTransient_TransientErrors() {
        let transientErrors: [RustBridgeError] = [
            .rustError("temporarily unavailable"),
            .rustError("resource busy, try again"),
            .rustError("allocation failed"),
            .rustError("threading error occurred"),
            .rustError("timeout exceeded"),
            .initializationFailed
        ]

        for error in transientErrors {
            XCTAssertTrue(
                error.isTransient,
                "Expected \(error) to be transient"
            )
        }
    }

    func testIsTransient_PermanentErrors() {
        let permanentErrors: [RustBridgeError] = [
            .nullPointer,
            .invalidUTF8,
            .invalidString("test"),
            .jsonParsingError("test"),
            .rustError("invalid argument")
        ]

        for error in permanentErrors {
            XCTAssertFalse(
                error.isTransient,
                "Expected \(error) to be permanent"
            )
        }
    }

    // MARK: - Async Retry Tests

    func testWithRetryAsync_SuccessAfterRetry() async throws {
        var callCount = 0

        let result = try await FFIErrorRecovery.withRetryAsync(
            maxAttempts: 3,
            baseDelay: 0.1
        ) {
            callCount += 1
            if callCount < 2 {
                throw RustBridgeError.rustError("try again")
            }
            return 42
        }

        XCTAssertEqual(result, 42)
        XCTAssertEqual(callCount, 2)
    }

    func testWithRetryAsync_ExponentialBackoff() async {
        let startTime = Date()
        var callCount = 0

        do {
            _ = try await FFIErrorRecovery.withRetryAsync(
                maxAttempts: 3,
                baseDelay: 0.2
            ) {
                callCount += 1
                throw RustBridgeError.rustError("timeout")
            }
        } catch {
            // Expected to fail
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should have delays: 0.2s (after attempt 1) + 0.4s (after attempt 2)
        // Total minimum: 0.6s
        XCTAssertGreaterThanOrEqual(elapsed, 0.6)
        XCTAssertEqual(callCount, 3)
    }

    // MARK: - Edge Cases

    func testWithRetry_MaxAttemptsOne() async {
        var callCount = 0

        do {
            _ = try await FFIErrorRecovery.withRetry(maxAttempts: 1, baseDelay: 0.1) {
                callCount += 1
                throw RustBridgeError.rustError("error")
            }
            XCTFail("Should throw on first attempt")
        } catch {
            XCTAssertEqual(callCount, 1)
        }
    }

    func testWithRetry_ZeroDelay() async throws {
        var callCount = 0

        let result = try await FFIErrorRecovery.withRetry(
            maxAttempts: 3,
            baseDelay: 0.0
        ) {
            callCount += 1
            if callCount == 1 {
                throw RustBridgeError.rustError("try again")
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 2)
    }
}

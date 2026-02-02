// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class NetworkRetryPolicyTests: XCTestCase {
    // MARK: - Policy Configuration Tests

    func testDefaultPolicy_Configuration() {
        let policy = NetworkRetryPolicy.default

        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.baseDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 60.0)
        XCTAssertTrue(policy.useJitter)
    }

    func testAggressivePolicy_Configuration() {
        let policy = NetworkRetryPolicy.aggressive

        XCTAssertEqual(policy.maxAttempts, 10)
        XCTAssertEqual(policy.baseDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 120.0)
        XCTAssertTrue(policy.useJitter)
    }

    func testConservativePolicy_Configuration() {
        let policy = NetworkRetryPolicy.conservative

        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.baseDelay, 2.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertTrue(policy.useJitter)
    }

    // MARK: - Retry Logic Tests

    func testExecute_SuccessOnFirstAttempt() async throws {
        let policy = NetworkRetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0
        )

        var callCount = 0

        let result = try await policy.execute {
            callCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1)
    }

    func testExecute_SuccessAfterRetry() async throws {
        let policy = NetworkRetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0
        )

        var callCount = 0

        let result = try await policy.execute {
            callCount += 1
            if callCount < 2 {
                throw URLError(.timedOut)
            }
            return "success after retry"
        }

        XCTAssertEqual(result, "success after retry")
        XCTAssertEqual(callCount, 2)
    }

    func testExecute_ExhaustsAllAttempts() async {
        let policy = NetworkRetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0
        )

        var callCount = 0

        do {
            _ = try await policy.execute {
                callCount += 1
                throw URLError(.networkConnectionLost)
            }
            XCTFail("Should have thrown after exhausting retries")
        } catch {
            XCTAssertEqual(callCount, 3)
        }
    }

    func testExecute_NonRetryableErrorFailsImmediately() async {
        let policy = NetworkRetryPolicy(
            maxAttempts: 5,
            baseDelay: 0.1,
            maxDelay: 1.0
        )

        var callCount = 0

        do {
            _ = try await policy.execute {
                callCount += 1
                throw URLError(.badURL)
            }
            XCTFail("Should have thrown immediately for non-retryable error")
        } catch {
            XCTAssertEqual(callCount, 1)
        }
    }

    // MARK: - Custom Retry Predicate Tests

    func testExecute_CustomShouldRetry() async throws {
        let policy = NetworkRetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0
        )

        var callCount = 0

        let result = try await policy.execute(shouldRetry: { error in
            // Custom logic: retry only specific error
            (error as? CustomError)?.shouldRetry ?? false
        }) {
            callCount += 1
            if callCount < 2 {
                throw CustomError(shouldRetry: true)
            }
            return "custom retry success"
        }

        XCTAssertEqual(result, "custom retry success")
        XCTAssertEqual(callCount, 2)
    }

    // MARK: - URLError Classification Tests

    func testURLError_IsRetryable_RetryableErrors() {
        let retryableErrors: [URLError.Code] = [
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .resourceUnavailable,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed
        ]

        for errorCode in retryableErrors {
            let error = URLError(errorCode)
            XCTAssertTrue(
                error.isRetryable,
                "Expected \(errorCode) to be retryable"
            )
        }
    }

    func testURLError_IsRetryable_NonRetryableErrors() {
        let nonRetryableErrors: [URLError.Code] = [
            .badURL,
            .unsupportedURL,
            .cancelled,
            .userCancelledAuthentication,
            .badServerResponse,
            .zeroByteResource,
            .cannotDecodeRawData,
            .cannotDecodeContentData,
            .secureConnectionFailed,
            .serverCertificateHasBadDate,
            .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot,
            .serverCertificateNotYetValid,
            .clientCertificateRequired,
            .clientCertificateRejected
        ]

        for errorCode in nonRetryableErrors {
            let error = URLError(errorCode)
            XCTAssertFalse(
                error.isRetryable,
                "Expected \(errorCode) to be non-retryable"
            )
        }
    }

    // MARK: - HTTPURLResponse Tests

    func testHTTPURLResponse_IsRetryable_RetryableStatusCodes() {
        let retryableStatusCodes = [408, 429, 500, 502, 503, 504]

        for statusCode in retryableStatusCodes {
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!

            XCTAssertTrue(
                response.isRetryable,
                "Expected status code \(statusCode) to be retryable"
            )
        }
    }

    func testHTTPURLResponse_IsRetryable_NonRetryableStatusCodes() {
        let nonRetryableStatusCodes = [200, 201, 400, 401, 403, 404]

        for statusCode in nonRetryableStatusCodes {
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!

            XCTAssertFalse(
                response.isRetryable,
                "Expected status code \(statusCode) to be non-retryable"
            )
        }
    }

    func testHTTPURLResponse_RetryAfter_Seconds() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )!

        XCTAssertEqual(response.retryAfter, 60.0)
    }

    func testHTTPURLResponse_RetryAfter_HTTPDate() {
        // Create a date 120 seconds in the future
        let futureDate = Date(timeIntervalSinceNow: 120)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        let dateString = dateFormatter.string(from: futureDate)

        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": dateString]
        )!

        if let retryAfter = response.retryAfter {
            // Should be approximately 120 seconds (allow 5 second tolerance)
            XCTAssertGreaterThan(retryAfter, 115.0)
            XCTAssertLessThan(retryAfter, 125.0)
        } else {
            XCTFail("Failed to parse Retry-After HTTP date")
        }
    }

    func testHTTPURLResponse_RetryAfter_Missing() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!

        XCTAssertNil(response.retryAfter)
    }

    // MARK: - Exponential Backoff Tests

    func testExecute_ExponentialBackoff() async {
        let policy = NetworkRetryPolicy(
            maxAttempts: 4,
            baseDelay: 0.2,
            maxDelay: 10.0,
            useJitter: false  // Disable jitter for predictable timing
        )

        var callCount = 0
        let startTime = Date()

        do {
            _ = try await policy.execute {
                callCount += 1
                throw URLError(.timedOut)
            }
        } catch {
            // Expected to fail
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Expected delays: 0.2s (after attempt 1) + 0.4s (after attempt 2) + 0.8s (after attempt 3)
        // Total minimum: 1.4s
        XCTAssertGreaterThanOrEqual(elapsed, 1.4)
        XCTAssertEqual(callCount, 4)
    }

    func testExecute_MaxDelayRespected() async {
        let policy = NetworkRetryPolicy(
            maxAttempts: 5,
            baseDelay: 1.0,
            maxDelay: 2.0,  // Cap at 2 seconds
            useJitter: false
        )

        var callCount = 0
        let startTime = Date()

        do {
            _ = try await policy.execute {
                callCount += 1
                throw URLError(.networkConnectionLost)
            }
        } catch {
            // Expected
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Expected delays: 1s + 2s (capped) + 2s (capped) + 2s (capped)
        // Total minimum: 7s
        XCTAssertGreaterThanOrEqual(elapsed, 7.0)
        XCTAssertEqual(callCount, 5)
    }
}

// MARK: - Test Helpers

private struct CustomError: Error {
    let shouldRetry: Bool
}

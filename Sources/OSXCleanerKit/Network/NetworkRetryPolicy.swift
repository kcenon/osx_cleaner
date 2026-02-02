// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Network operation retry policy with exponential backoff
///
/// This module provides automatic retry logic for network operations that may fail
/// due to transient network conditions (timeouts, connection loss, etc.).
///
/// # Retry Strategy
///
/// - **Exponential Backoff**: Delay doubles with each retry (1s, 2s, 4s, 8s, ...)
/// - **Jitter**: Random variation (0-30%) added to prevent thundering herd
/// - **Max Delay**: Capped at configurable maximum (default: 60s)
/// - **Retryable Errors**: Only network-related errors are retried
///
/// # Example
///
/// ```swift
/// let policy = NetworkRetryPolicy.default
/// let data = try await policy.execute {
///     try await URLSession.shared.data(from: url)
/// }
/// ```
public struct NetworkRetryPolicy {
    /// Maximum number of retry attempts
    public let maxAttempts: Int

    /// Base delay between retry attempts (in seconds)
    public let baseDelay: TimeInterval

    /// Maximum delay between retry attempts (in seconds)
    public let maxDelay: TimeInterval

    /// Whether to add random jitter to delays
    public let useJitter: Bool

    /// Default retry policy for network operations
    ///
    /// - 5 attempts maximum
    /// - 1 second base delay
    /// - 60 seconds max delay
    /// - Jitter enabled
    public static let `default` = NetworkRetryPolicy(
        maxAttempts: 5,
        baseDelay: 1.0,
        maxDelay: 60.0,
        useJitter: true
    )

    /// Aggressive retry policy for critical operations
    ///
    /// - 10 attempts maximum
    /// - 0.5 second base delay
    /// - 120 seconds max delay
    /// - Jitter enabled
    public static let aggressive = NetworkRetryPolicy(
        maxAttempts: 10,
        baseDelay: 0.5,
        maxDelay: 120.0,
        useJitter: true
    )

    /// Conservative retry policy for non-critical operations
    ///
    /// - 3 attempts maximum
    /// - 2 seconds base delay
    /// - 30 seconds max delay
    /// - Jitter enabled
    public static let conservative = NetworkRetryPolicy(
        maxAttempts: 3,
        baseDelay: 2.0,
        maxDelay: 30.0,
        useJitter: true
    )

    /// Create a custom retry policy
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (including initial attempt)
    ///   - baseDelay: Base delay between retries in seconds
    ///   - maxDelay: Maximum delay between retries in seconds
    ///   - useJitter: Whether to add random jitter to delays (default: true)
    public init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        useJitter: Bool = true
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.useJitter = useJitter
    }

    /// Execute a network operation with automatic retry
    ///
    /// This method will retry the operation if it fails with a retryable network error.
    /// Non-retryable errors (e.g., 404, 401) fail immediately without retry.
    ///
    /// ## Retry Logic
    ///
    /// 1. Execute operation
    /// 2. If success, return result
    /// 3. If retryable error, wait with exponential backoff + jitter and retry
    /// 4. If non-retryable error, throw immediately
    /// 5. After max attempts, throw last error
    ///
    /// ## Backoff Formula
    ///
    /// ```
    /// delay = min(baseDelay * 2^(attempt-1), maxDelay)
    /// if useJitter:
    ///     delay += random(0, 0.3 * delay)
    /// ```
    ///
    /// - Parameter operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error encountered if all attempts fail
    public func execute<T>(
        operation: () async throws -> T
    ) async throws -> T {
        var attempt = 0

        while true {
            attempt += 1

            do {
                return try await operation()
            } catch let error as URLError {
                // Check if error is retryable
                guard error.isRetryable else {
                    // Non-retryable error - fail immediately
                    throw error
                }

                // Check if we've exhausted attempts
                guard attempt < maxAttempts else {
                    AppLogger.shared.error(
                        "Network operation failed after \(maxAttempts) attempts: \(error)"
                    )
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = calculateDelay(for: attempt)

                AppLogger.shared.info(
                    "Network request failed (attempt \(attempt)/\(maxAttempts)), retrying in \(String(format: "%.1f", delay))s: \(error.localizedDescription)"
                )

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // Non-URLError - don't retry
                throw error
            }
        }
    }

    /// Execute a network operation with automatic retry and custom error handling
    ///
    /// This variant allows custom error classification via the `shouldRetry` closure.
    ///
    /// - Parameters:
    ///   - shouldRetry: Closure to determine if an error should be retried
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error encountered if all attempts fail
    public func execute<T>(
        shouldRetry: (Error) -> Bool,
        operation: () async throws -> T
    ) async throws -> T {
        var attempt = 0

        while true {
            attempt += 1

            do {
                return try await operation()
            } catch {
                guard shouldRetry(error) else {
                    throw error
                }

                guard attempt < maxAttempts else {
                    AppLogger.shared.error(
                        "Operation failed after \(maxAttempts) attempts: \(error)"
                    )
                    throw error
                }

                let delay = calculateDelay(for: attempt)

                AppLogger.shared.info(
                    "Operation failed (attempt \(attempt)/\(maxAttempts)), retrying in \(String(format: "%.1f", delay))s"
                )

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Calculate retry delay with exponential backoff and optional jitter
    ///
    /// - Parameter attempt: Current attempt number (1-based)
    /// - Returns: Delay in seconds
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^(attempt-1)
        var delay = min(
            baseDelay * pow(2.0, Double(attempt - 1)),
            maxDelay
        )

        // Add jitter to prevent thundering herd
        if useJitter {
            let jitter = Double.random(in: 0 ... 0.3) * delay
            delay += jitter
        }

        return delay
    }
}

// MARK: - URLError Extensions

extension URLError {
    /// Determines if a network error should be retried
    ///
    /// ## Retryable Errors
    /// - Timeouts
    /// - Connection lost
    /// - Network unavailable
    /// - Cannot find/connect to host (DNS/routing issues)
    ///
    /// ## Non-Retryable Errors
    /// - Bad URL (programming error)
    /// - Unsupported URL (programming error)
    /// - Cancelled (user action)
    /// - HTTP errors (handled separately)
    ///
    /// - Returns: True if the error is transient and should be retried
    var isRetryable: Bool {
        switch code {
        // Network connectivity issues (temporary)
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true

        // Host resolution/connection issues (may be temporary)
        case .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return true

        // Resource temporarily unavailable
        case .resourceUnavailable:
            return true

        // Programming errors (permanent)
        case .badURL,
             .unsupportedURL:
            return false

        // User action (don't retry)
        case .cancelled,
             .userCancelledAuthentication:
            return false

        // HTTP errors should be handled by HTTP status code check
        case .badServerResponse,
             .zeroByteResource,
             .cannotDecodeRawData,
             .cannotDecodeContentData:
            return false

        // Security errors (permanent)
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .clientCertificateRequired,
             .clientCertificateRejected:
            return false

        // Default to not retrying unknown errors
        default:
            return false
        }
    }
}

// MARK: - HTTPURLResponse Extensions

extension HTTPURLResponse {
    /// Determines if an HTTP response indicates a retryable condition
    ///
    /// ## Retryable Status Codes
    /// - 408: Request Timeout
    /// - 429: Too Many Requests (rate limiting)
    /// - 500: Internal Server Error
    /// - 502: Bad Gateway
    /// - 503: Service Unavailable
    /// - 504: Gateway Timeout
    ///
    /// ## Non-Retryable Status Codes
    /// - 4xx (except 408, 429): Client errors (bad request, unauthorized, etc.)
    /// - 2xx: Success (shouldn't be retrying)
    ///
    /// - Returns: True if the status code indicates a retryable condition
    var isRetryable: Bool {
        switch statusCode {
        case 408,  // Request Timeout
             429,  // Too Many Requests
             500,  // Internal Server Error
             502,  // Bad Gateway
             503,  // Service Unavailable
             504:  // Gateway Timeout
            return true

        default:
            return false
        }
    }

    /// Get recommended retry delay from response headers
    ///
    /// Checks for:
    /// - `Retry-After` header (seconds or HTTP date)
    ///
    /// - Returns: Recommended delay in seconds, or nil if not specified
    var retryAfter: TimeInterval? {
        guard let retryAfterValue = value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        // Try parsing as seconds
        if let seconds = TimeInterval(retryAfterValue) {
            return seconds
        }

        // Try parsing as HTTP date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

        if let retryDate = dateFormatter.date(from: retryAfterValue) {
            return retryDate.timeIntervalSinceNow
        }

        return nil
    }
}

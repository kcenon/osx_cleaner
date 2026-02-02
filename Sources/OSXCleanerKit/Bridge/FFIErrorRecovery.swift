// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// FFI Error Recovery mechanism for transient failures
///
/// This module provides automatic retry logic for FFI operations that may fail
/// due to transient conditions (temporary resource unavailability, threading conflicts, etc.).
///
/// # Retry Strategy
///
/// - **Transient Errors**: Automatically retried with exponential backoff
/// - **Permanent Errors**: Fail immediately without retry
/// - **Max Attempts**: Configurable (default: 3)
/// - **Delay**: Configurable base delay with exponential increase
///
/// # Example
///
/// ```swift
/// let result = try await FFIErrorRecovery.withRetry(maxAttempts: 3) {
///     try bridge.analyzePath("/path/to/analyze")
/// }
/// ```
public struct FFIErrorRecovery {
    /// Default maximum retry attempts for FFI operations
    public static let defaultMaxAttempts = 3

    /// Default base delay between retry attempts (in seconds)
    public static let defaultBaseDelay: TimeInterval = 0.5

    /// Execute an FFI operation with automatic retry for transient errors
    ///
    /// This method will retry the operation if it fails with a transient error.
    /// Permanent errors (e.g., invalid input) fail immediately without retry.
    ///
    /// ## Retry Logic
    ///
    /// 1. Execute operation
    /// 2. If success, return result
    /// 3. If transient error, wait with exponential backoff and retry
    /// 4. If permanent error, throw immediately
    /// 5. After max attempts, throw last error
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - baseDelay: Base delay between retries in seconds (default: 0.5s)
    ///   - operation: The FFI operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error encountered if all attempts fail
    public static func withRetry<T>(
        maxAttempts: Int = defaultMaxAttempts,
        baseDelay: TimeInterval = defaultBaseDelay,
        operation: () throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try operation()
            } catch let error as RustBridgeError {
                lastError = error

                // Check if error is transient (retryable)
                guard error.isTransient else {
                    // Permanent error - fail immediately
                    throw error
                }

                // Log retry attempt
                AppLogger.shared.warning(
                    "FFI operation failed with transient error (attempt \(attempt)/\(maxAttempts)): \(error)"
                )

                // Don't wait after last attempt
                if attempt < maxAttempts {
                    let delay = baseDelay * Double(attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries exhausted
        throw lastError!
    }

    /// Execute an async FFI operation with automatic retry
    ///
    /// Similar to `withRetry`, but for async operations.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - baseDelay: Base delay between retries in seconds (default: 0.5s)
    ///   - operation: The async FFI operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error encountered if all attempts fail
    public static func withRetryAsync<T>(
        maxAttempts: Int = defaultMaxAttempts,
        baseDelay: TimeInterval = defaultBaseDelay,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as RustBridgeError {
                lastError = error

                guard error.isTransient else {
                    throw error
                }

                AppLogger.shared.warning(
                    "Async FFI operation failed with transient error (attempt \(attempt)/\(maxAttempts)): \(error)"
                )

                if attempt < maxAttempts {
                    let delay = baseDelay * Double(attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError!
    }
}

// MARK: - RustBridgeError Extensions

extension RustBridgeError {
    /// Determines if an error is transient (should be retried)
    ///
    /// ## Transient Errors
    /// - Memory allocation failures (may succeed on retry)
    /// - Threading errors (resource temporarily locked)
    /// - Temporary unavailability
    ///
    /// ## Permanent Errors
    /// - Invalid input (null bytes, invalid UTF-8)
    /// - Null pointers (programming error)
    /// - Invalid result format (incompatible versions)
    ///
    /// - Returns: True if the error is transient and should be retried
    var isTransient: Bool {
        switch self {
        case .rustError(let message):
            // Analyze error message for transient conditions
            let transientPatterns = [
                "temporarily unavailable",
                "resource busy",
                "try again",
                "timeout",
                "allocation failed",
                "threading error",
            ]
            return transientPatterns.contains { message.lowercased().contains($0) }

        case .initializationFailed:
            // Initialization failures may be transient (dylib loading, etc.)
            return true

        case .nullPointer, .invalidUTF8, .invalidString, .jsonParsingError:
            // These are permanent errors (programming bugs or incompatibility)
            return false
        }
    }
}

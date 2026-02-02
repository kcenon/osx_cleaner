// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// File operation retry mechanism for transient file system errors
///
/// This module provides automatic retry logic for file operations that may fail
/// due to transient conditions (file locks, permission delays, resource busy, etc.).
///
/// # Retry Strategy
///
/// - **Retryable Errors**: EBUSY, EACCES, EAGAIN
/// - **Non-Retryable Errors**: ENOENT, EINVAL, EPERM
/// - **Max Attempts**: Configurable (default: 3)
/// - **Delay**: Fixed delay between retries (default: 0.5s)
///
/// # Example
///
/// ```swift
/// try await FileOperationRetry.remove("/path/to/file")
/// ```
public struct FileOperationRetry {
    /// Default maximum retry attempts for file operations
    public static let defaultMaxAttempts = 3

    /// Default delay between retry attempts (in seconds)
    public static let defaultRetryDelay: TimeInterval = 0.5

    /// Remove a file or directory with automatic retry
    ///
    /// This method will retry the remove operation if it fails with a transient error.
    /// Permanent errors (e.g., file not found, invalid argument) fail immediately.
    ///
    /// ## Retryable Errors
    /// - `NSFileWriteBusyError`: File is being written
    /// - `NSFileReadNoPermissionError`: Permission temporarily unavailable
    /// - `NSFileLockingError`: File is locked
    ///
    /// ## Non-Retryable Errors
    /// - `NSFileNoSuchFileError`: File doesn't exist
    /// - `NSFileWriteNoPermissionError`: Permanent permission denied
    ///
    /// - Parameters:
    ///   - path: Path to the file or directory to remove
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 0.5s)
    /// - Throws: The last error encountered if all attempts fail
    public static func remove(
        _ path: String,
        maxAttempts: Int = defaultMaxAttempts,
        retryDelay: TimeInterval = defaultRetryDelay
    ) async throws {
        for attempt in 1...maxAttempts {
            do {
                try FileManager.default.removeItem(atPath: path)

                // Log successful removal if it took retries
                if attempt > 1 {
                    AppLogger.shared.info(
                        "File operation succeeded after \(attempt) attempts: \(path)"
                    )
                }

                return
            } catch let error as NSError {
                // Check if error is retryable
                let isRetryable = error.isFileOperationRetryable

                // Log retry or final error
                if isRetryable && attempt < maxAttempts {
                    AppLogger.shared.warning(
                        "File operation failed (attempt \(attempt)/\(maxAttempts)), retrying: \(path) - \(error.localizedDescription)"
                    )
                } else if !isRetryable {
                    AppLogger.shared.error(
                        "File operation failed with non-retryable error: \(path) - \(error.localizedDescription)"
                    )
                    throw error
                } else {
                    // Last attempt failed
                    AppLogger.shared.error(
                        "File operation failed after \(maxAttempts) attempts: \(path) - \(error.localizedDescription)"
                    )
                    throw error
                }

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }

    /// Copy a file with automatic retry
    ///
    /// - Parameters:
    ///   - source: Source file path
    ///   - destination: Destination file path
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 0.5s)
    /// - Throws: The last error encountered if all attempts fail
    public static func copy(
        from source: String,
        to destination: String,
        maxAttempts: Int = defaultMaxAttempts,
        retryDelay: TimeInterval = defaultRetryDelay
    ) async throws {
        for attempt in 1...maxAttempts {
            do {
                try FileManager.default.copyItem(atPath: source, toPath: destination)

                if attempt > 1 {
                    AppLogger.shared.info(
                        "Copy operation succeeded after \(attempt) attempts: \(source) -> \(destination)"
                    )
                }

                return
            } catch let error as NSError {
                let isRetryable = error.isFileOperationRetryable

                if isRetryable && attempt < maxAttempts {
                    AppLogger.shared.warning(
                        "Copy operation failed (attempt \(attempt)/\(maxAttempts)), retrying: \(source) - \(error.localizedDescription)"
                    )
                } else if !isRetryable {
                    throw error
                } else {
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }

    /// Move a file with automatic retry
    ///
    /// - Parameters:
    ///   - source: Source file path
    ///   - destination: Destination file path
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 0.5s)
    /// - Throws: The last error encountered if all attempts fail
    public static func move(
        from source: String,
        to destination: String,
        maxAttempts: Int = defaultMaxAttempts,
        retryDelay: TimeInterval = defaultRetryDelay
    ) async throws {
        for attempt in 1...maxAttempts {
            do {
                try FileManager.default.moveItem(atPath: source, toPath: destination)

                if attempt > 1 {
                    AppLogger.shared.info(
                        "Move operation succeeded after \(attempt) attempts: \(source) -> \(destination)"
                    )
                }

                return
            } catch let error as NSError {
                let isRetryable = error.isFileOperationRetryable

                if isRetryable && attempt < maxAttempts {
                    AppLogger.shared.warning(
                        "Move operation failed (attempt \(attempt)/\(maxAttempts)), retrying: \(source) - \(error.localizedDescription)"
                    )
                } else if !isRetryable {
                    throw error
                } else {
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }

    /// Write data to a file with automatic retry
    ///
    /// - Parameters:
    ///   - data: Data to write
    ///   - path: File path to write to
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 0.5s)
    /// - Throws: The last error encountered if all attempts fail
    public static func write(
        _ data: Data,
        to path: String,
        maxAttempts: Int = defaultMaxAttempts,
        retryDelay: TimeInterval = defaultRetryDelay
    ) async throws {
        for attempt in 1...maxAttempts {
            do {
                try data.write(to: URL(fileURLWithPath: path))

                if attempt > 1 {
                    AppLogger.shared.info(
                        "Write operation succeeded after \(attempt) attempts: \(path)"
                    )
                }

                return
            } catch let error as NSError {
                let isRetryable = error.isFileOperationRetryable

                if isRetryable && attempt < maxAttempts {
                    AppLogger.shared.warning(
                        "Write operation failed (attempt \(attempt)/\(maxAttempts)), retrying: \(path) - \(error.localizedDescription)"
                    )
                } else if !isRetryable {
                    throw error
                } else {
                    throw error
                }

                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }
}

// MARK: - NSError Extensions

extension NSError {
    /// Determines if a file operation error should be retried
    ///
    /// ## Retryable Errors
    /// - `NSFileWriteBusyError`: File is being written to
    /// - `NSFileReadNoPermissionError`: Permission temporarily unavailable
    /// - `NSFileLockingError`: File is locked by another process
    /// - POSIX `EBUSY`: Resource busy
    /// - POSIX `EAGAIN`: Try again
    /// - POSIX `EINTR`: Interrupted system call
    ///
    /// ## Non-Retryable Errors
    /// - `NSFileNoSuchFileError`: File doesn't exist
    /// - `NSFileWriteNoPermissionError`: Permanent permission denied
    /// - POSIX `ENOENT`: No such file or directory
    /// - POSIX `EINVAL`: Invalid argument
    /// - POSIX `EPERM`: Operation not permitted
    ///
    /// - Returns: True if the error is transient and should be retried
    var isFileOperationRetryable: Bool {
        // Check Cocoa errors
        if domain == NSCocoaErrorDomain {
            switch code {
            // Retryable errors (using numeric codes)
            case 644,  // NSFileWriteBusyError (approximate, file being written)
                 257,  // NSFileReadNoPermissionError
                 255:  // NSFileLockingError
                return true

            // Non-retryable errors
            case 4,    // NSFileNoSuchFileError
                 513,  // NSFileWriteNoPermissionError
                 640,  // NSFileWriteOutOfSpaceError
                 642:  // NSFileWriteVolumeReadOnlyError
                return false

            default:
                return false
            }
        }

        // Check POSIX errors
        if domain == NSPOSIXErrorDomain {
            switch code {
            // Retryable
            case Int(EBUSY),    // Resource busy
                 Int(EAGAIN),   // Try again
                 Int(EINTR):    // Interrupted
                return true

            // Non-retryable
            case Int(ENOENT),   // No such file
                 Int(EINVAL),   // Invalid argument
                 Int(EPERM),    // Not permitted
                 Int(EACCES),   // Permission denied (permanent)
                 Int(EROFS),    // Read-only filesystem
                 Int(ENOSPC):   // No space left
                return false

            default:
                return false
            }
        }

        // Unknown error domain - don't retry
        return false
    }
}

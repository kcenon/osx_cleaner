// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during input validation
public enum ValidationError: LocalizedError {
    // MARK: - Path Validation Errors

    /// Empty path provided
    case emptyPath

    /// Path contains null byte character
    case nullByteInPath

    /// Path not found in filesystem
    case pathNotFound(String)

    /// System path access not allowed
    case systemPathNotAllowed(String)

    /// Path is not readable
    case pathNotReadable(String)

    /// Path exceeds maximum length
    case pathTooLong(Int, maximum: Int)

    // MARK: - Configuration Validation Errors

    /// Invalid cleanup level (must be 1-4)
    case invalidCleanupLevel(Int32)

    /// Conflicting command options
    case conflictingOptions(String)

    /// Invalid MDM server URL
    case insecureMDMURL

    /// Invalid check interval
    case invalidCheckInterval(Int)

    /// Missing required field
    case missingRequiredField(String)

    // MARK: - FFI Validation Errors

    /// Invalid string for FFI boundary
    case invalidFFIString(String)

    /// String exceeds maximum FFI length
    case ffiStringTooLong(Int, maximum: Int)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        // Path validation errors
        case .emptyPath:
            return "Path cannot be empty"

        case .nullByteInPath:
            return "Path contains invalid null byte character"

        case .pathNotFound(let path):
            return "Path not found: \(path)"

        case .systemPathNotAllowed(let path):
            return "Access to system path not allowed: \(path)"

        case .pathNotReadable(let path):
            return "Path is not readable: \(path)"

        case .pathTooLong(let length, let maximum):
            return "Path length (\(length)) exceeds maximum allowed (\(maximum))"

        // Configuration validation errors
        case .invalidCleanupLevel(let level):
            return "Invalid cleanup level: \(level) (must be 1-4)"

        case .conflictingOptions(let message):
            return "Conflicting options: \(message)"

        case .insecureMDMURL:
            return "MDM server URL must use HTTPS protocol"

        case .invalidCheckInterval(let interval):
            return "Invalid check interval: \(interval) (must be positive)"

        case .missingRequiredField(let field):
            return "Missing required field: \(field)"

        // FFI validation errors
        case .invalidFFIString(let reason):
            return "Invalid string for FFI: \(reason)"

        case .ffiStringTooLong(let length, let maximum):
            return "String length (\(length)) exceeds FFI maximum (\(maximum))"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyPath:
            return "Provide a valid file path"

        case .nullByteInPath:
            return "Remove null byte characters from the path"

        case .pathNotFound:
            return "Verify the path exists and is accessible"

        case .systemPathNotAllowed:
            return "Choose a path outside system directories (/System, /Library/System, /dev, /etc, /private/var/db)"

        case .pathNotReadable:
            return "Check file permissions and ensure you have read access"

        case .pathTooLong:
            return "Use a shorter path or move the target to a location with a shorter path"

        case .invalidCleanupLevel:
            return "Use a cleanup level between 1 (light) and 4 (system)"

        case .conflictingOptions:
            return "Remove conflicting command-line options"

        case .insecureMDMURL:
            return "Use HTTPS protocol for MDM server URL (e.g., https://example.com)"

        case .invalidCheckInterval:
            return "Use a positive number for check interval"

        case .missingRequiredField:
            return "Provide the required field in configuration"

        case .invalidFFIString:
            return "Ensure the string contains valid UTF-8 characters and no null bytes"

        case .ffiStringTooLong:
            return "Reduce string length to fit within FFI limits"
        }
    }
}

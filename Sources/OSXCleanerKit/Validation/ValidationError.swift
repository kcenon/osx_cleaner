// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during input validation
public enum ValidationError: DetailedError {
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

    // MARK: - DetailedError Implementation

    public var problem: String {
        switch self {
        // Path validation errors
        case .emptyPath:
            return "No path specified"

        case .nullByteInPath:
            return "Path contains invalid null byte character"

        case .pathNotFound(let path):
            return "Path not found: '\(path)'"

        case .systemPathNotAllowed(let path):
            return "Access to system path not allowed: '\(path)'"

        case .pathNotReadable(let path):
            return "Path is not readable: '\(path)'"

        case .pathTooLong(let length, let maximum):
            return "Path length (\(length)) exceeds maximum allowed (\(maximum))"

        // Configuration validation errors
        case .invalidCleanupLevel(let level):
            return "Invalid cleanup level: \(level)"

        case .conflictingOptions(let message):
            return "Conflicting options: \(message)"

        case .insecureMDMURL:
            return "MDM server URL must use HTTPS protocol"

        case .invalidCheckInterval(let interval):
            return "Invalid check interval: \(interval)"

        case .missingRequiredField(let field):
            return "Missing required field: '\(field)'"

        // FFI validation errors
        case .invalidFFIString(let reason):
            return "Invalid string for FFI: \(reason)"

        case .ffiStringTooLong(let length, let maximum):
            return "String length (\(length)) exceeds FFI maximum (\(maximum))"
        }
    }

    public var context: String? {
        switch self {
        case .emptyPath:
            return "A target path is required for this operation."

        case .nullByteInPath:
            return "Null bytes are not allowed in file paths."

        case .pathNotFound:
            return "The specified path does not exist or has been moved."

        case .systemPathNotAllowed:
            return "System directories are protected to prevent macOS damage."

        case .pathNotReadable:
            return "You don't have read permission for this path."

        case .pathTooLong:
            return "macOS has a maximum path length limit."

        case .invalidCleanupLevel:
            return "Cleanup level determines which files can be safely deleted."

        case .conflictingOptions:
            return "The specified options cannot be used together."

        case .insecureMDMURL:
            return "MDM connections require encrypted HTTPS for security."

        case .invalidCheckInterval:
            return "Check interval must be a positive number."

        case .missingRequiredField:
            return "This field is required for the operation to proceed."

        case .invalidFFIString:
            return "The string contains characters that cannot cross the FFI boundary."

        case .ffiStringTooLong:
            return "Strings passed to the Rust core have a length limit for safety."
        }
    }

    public var solution: String? {
        switch self {
        case .emptyPath:
            return """
                Specify a path to clean:
                  osxcleaner clean ~/Library/Caches
                  osxcleaner analyze ~/Downloads

                Or use --help to see all options.
                """

        case .nullByteInPath:
            return "Remove null byte characters from the path string."

        case .pathNotFound(let path):
            return """
                Verify the path exists:
                  ls -la '\(path)'

                Or use tab-completion to find the correct path.
                """

        case .systemPathNotAllowed:
            return """
                Choose a path outside system directories:
                  - /System/*
                  - /Library/System/*
                  - /dev/*
                  - /etc/*
                  - /private/var/db/*

                Use user directories instead:
                  osxcleaner clean ~/Library/Caches
                """

        case .pathNotReadable:
            return """
                Check file permissions:
                  ls -la '<path>'

                Or grant read access:
                  chmod +r '<path>'
                """

        case .pathTooLong:
            return "Use a shorter path or move the target to a location with a shorter path."

        case .invalidCleanupLevel:
            return """
                Valid cleanup levels are 1-4:
                  1 (light):  Safe items only (browser cache, Trash)
                  2 (normal): Light + caches requiring rebuild
                  3 (deep):   Normal + developer caches
                  4 (system): Deep + system caches (use with caution)

                Example: osxcleaner clean ~/Library --level 2
                """

        case .conflictingOptions:
            return "Remove one of the conflicting options and try again."

        case .insecureMDMURL:
            return "Use HTTPS protocol for MDM server URL (e.g., https://mdm.example.com)"

        case .invalidCheckInterval:
            return """
                Use a positive number for check interval:
                  --interval 300  (5 minutes)
                  --interval 3600 (1 hour)
                """

        case .missingRequiredField(let field):
            return "Provide the '\(field)' field in your configuration or command."

        case .invalidFFIString:
            return "Ensure the string contains valid UTF-8 characters and no null bytes."

        case .ffiStringTooLong(_, let maximum):
            return "Reduce string length to \(maximum) characters or less."
        }
    }

    public var documentation: URL? {
        switch self {
        case .emptyPath, .pathNotFound, .pathNotReadable, .pathTooLong:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Paths")
        case .systemPathNotAllowed:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Safety")
        case .invalidCleanupLevel:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Cleanup-Levels")
        case .insecureMDMURL:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/MDM-Integration")
        case .nullByteInPath, .conflictingOptions, .invalidCheckInterval, .missingRequiredField:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/CLI-Reference")
        case .invalidFFIString, .ffiStringTooLong:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Troubleshooting")
        }
    }
}

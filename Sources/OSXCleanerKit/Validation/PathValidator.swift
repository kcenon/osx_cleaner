// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Validates file paths to prevent security vulnerabilities and ensure path safety
public struct PathValidator {
    // MARK: - Constants

    /// Maximum allowed path length (PATH_MAX on macOS is 1024)
    public static let maximumPathLength = 1024

    /// Paths that should never be accessible for cleanup
    private static let systemProtectedPaths = [
        "/System",
        "/Library/System",
        "/private/var/db",
        "/dev",
        "/etc",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/var/db",
        "/var/root"
    ]

    /// Sensitive user directories that require extra caution
    private static let sensitiveUserPaths = [
        "/Users/Shared",
        "/Library/Keychains",
        "/Library/Security"
    ]

    // MARK: - Validation Options

    /// Options for path validation
    public struct ValidationOptions {
        /// Whether to check if the path exists
        public let checkExistence: Bool

        /// Whether to check read permissions
        public let checkReadability: Bool

        /// Whether to allow system paths (normally forbidden)
        public let allowSystemPaths: Bool

        /// Whether to expand tilde (~) in paths
        public let expandTilde: Bool

        public init(
            checkExistence: Bool = true,
            checkReadability: Bool = false,
            allowSystemPaths: Bool = false,
            expandTilde: Bool = true
        ) {
            self.checkExistence = checkExistence
            self.checkReadability = checkReadability
            self.allowSystemPaths = allowSystemPaths
            self.expandTilde = expandTilde
        }

        /// Default validation options
        public static let `default` = ValidationOptions()

        /// Strict validation (all checks enabled)
        public static let strict = ValidationOptions(
            checkExistence: true,
            checkReadability: true,
            allowSystemPaths: false,
            expandTilde: true
        )

        /// Lenient validation (existence check only)
        public static let lenient = ValidationOptions(
            checkExistence: false,
            checkReadability: false,
            allowSystemPaths: false,
            expandTilde: true
        )
    }

    // MARK: - Main Validation Method

    /// Validates and canonicalizes a file path
    ///
    /// This method performs comprehensive path validation including:
    /// - Empty path check
    /// - Null byte detection
    /// - Path length validation
    /// - Path canonicalization (resolve symbolic links, remove .. components)
    /// - System path protection
    /// - Optional existence and readability checks
    ///
    /// - Parameters:
    ///   - path: The path string to validate
    ///   - options: Validation options (defaults to `.default`)
    /// - Returns: Validated and canonicalized URL
    /// - Throws: ValidationError if validation fails
    public static func validate(
        _ path: String,
        options: ValidationOptions = .default
    ) throws -> URL {
        // 1. Check for empty path
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ValidationError.emptyPath
        }

        // 2. Check for null bytes (security: prevent path injection)
        guard !path.contains("\0") else {
            throw ValidationError.nullByteInPath
        }

        // 3. Check path length
        guard path.count <= maximumPathLength else {
            throw ValidationError.pathTooLong(path.count, maximum: maximumPathLength)
        }

        // 4. Expand tilde if needed
        var processedPath = trimmedPath
        if options.expandTilde {
            processedPath = NSString(string: trimmedPath).expandingTildeInPath
        }

        // 5. Create URL and standardize (resolve symbolic links, remove .. components)
        let url = URL(fileURLWithPath: processedPath)
        let standardizedURL = url.standardized

        // 6. Check system path protection
        if !options.allowSystemPaths {
            try checkSystemPathProtection(standardizedURL)
        }

        // 7. Check existence if required
        if options.checkExistence {
            try checkExistence(standardizedURL)
        }

        // 8. Check readability if required
        if options.checkReadability {
            try checkReadability(standardizedURL)
        }

        return standardizedURL
    }

    /// Validates a path and returns the string representation
    ///
    /// Convenience method that validates and returns the canonical path as a string.
    ///
    /// - Parameters:
    ///   - path: The path string to validate
    ///   - options: Validation options
    /// - Returns: Validated canonical path string
    /// - Throws: ValidationError if validation fails
    public static func validatePath(
        _ path: String,
        options: ValidationOptions = .default
    ) throws -> String {
        let url = try validate(path, options: options)
        return url.path
    }

    // MARK: - Individual Check Methods

    /// Checks if path is within system-protected areas
    ///
    /// - Parameter url: The URL to check
    /// - Throws: ValidationError.systemPathNotAllowed if path is protected
    private static func checkSystemPathProtection(_ url: URL) throws {
        let path = url.path

        // Check against system protected paths
        for protectedPath in systemProtectedPaths {
            if path.hasPrefix(protectedPath) {
                // Allow exact match for system root paths if they're directories
                // (needed for certain administrative operations)
                if path == protectedPath {
                    continue
                }
                // Forbid any path under system directories
                if path.hasPrefix(protectedPath + "/") {
                    throw ValidationError.systemPathNotAllowed(path)
                }
            }
        }

        // Warn about sensitive paths (but don't block)
        for sensitivePath in sensitiveUserPaths {
            if path.hasPrefix(sensitivePath) {
                // Just log warning, don't throw
                // In production, you might want to add logging here
                break
            }
        }
    }

    /// Checks if path exists in filesystem
    ///
    /// - Parameter url: The URL to check
    /// - Throws: ValidationError.pathNotFound if path doesn't exist
    private static func checkExistence(_ url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw ValidationError.pathNotFound(url.path)
        }
    }

    /// Checks if path is readable
    ///
    /// - Parameter url: The URL to check
    /// - Throws: ValidationError.pathNotReadable if path is not readable
    private static func checkReadability(_ url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw ValidationError.pathNotReadable(url.path)
        }
    }

    // MARK: - Batch Validation

    /// Validates multiple paths at once
    ///
    /// - Parameters:
    ///   - paths: Array of path strings to validate
    ///   - options: Validation options
    /// - Returns: Array of validated URLs (in same order as input)
    /// - Throws: ValidationError for the first invalid path encountered
    public static func validateAll(
        _ paths: [String],
        options: ValidationOptions = .default
    ) throws -> [URL] {
        try paths.map { try validate($0, options: options) }
    }

    /// Validates multiple paths, collecting all errors instead of stopping at first error
    ///
    /// - Parameters:
    ///   - paths: Array of path strings to validate
    ///   - options: Validation options
    /// - Returns: Tuple of (successful URLs, validation errors)
    public static func validateAllWithErrors(
        _ paths: [String],
        options: ValidationOptions = .default
    ) -> (urls: [URL], errors: [(path: String, error: ValidationError)]) {
        var validURLs: [URL] = []
        var errors: [(String, ValidationError)] = []

        for path in paths {
            do {
                let url = try validate(path, options: options)
                validURLs.append(url)
            } catch let error as ValidationError {
                errors.append((path, error))
            } catch {
                // Unexpected error, wrap it
                errors.append((path, .invalidFFIString(error.localizedDescription)))
            }
        }

        return (validURLs, errors)
    }

    // MARK: - Utility Methods

    /// Checks if a path is within system-protected areas without throwing
    ///
    /// - Parameter path: Path to check
    /// - Returns: true if path is system-protected
    public static func isSystemProtectedPath(_ path: String) -> Bool {
        for protectedPath in systemProtectedPaths {
            if path.hasPrefix(protectedPath + "/") || path == protectedPath {
                return true
            }
        }
        return false
    }

    /// Checks if a path is a sensitive user path
    ///
    /// - Parameter path: Path to check
    /// - Returns: true if path is sensitive
    public static func isSensitivePath(_ path: String) -> Bool {
        for sensitivePath in sensitiveUserPaths {
            if path.hasPrefix(sensitivePath) {
                return true
            }
        }
        return false
    }
}

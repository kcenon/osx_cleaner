// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Validates CleanerConfiguration settings to ensure valid cleanup levels,
/// paths, and configuration consistency
public struct ConfigValidator {
    // MARK: - Main Validation

    /// Validates a CleanerConfiguration instance
    ///
    /// This method performs comprehensive configuration validation including:
    /// - Cleanup level range validation (1-4)
    /// - Custom path validation using PathValidator
    /// - Conflicting options detection
    ///
    /// - Parameter config: The CleanerConfiguration to validate
    /// - Throws: ValidationError if validation fails
    public static func validate(_ config: CleanerConfiguration) throws {
        // 1. Validate cleanup level (1-4)
        try validateCleanupLevel(config.cleanupLevel)

        // 2. Validate specific paths
        if !config.specificPaths.isEmpty {
            try validatePaths(config.specificPaths)
        }

        // 3. Check for conflicting options
        try checkConflictingOptions(config)
    }

    /// Validates an MDM configuration
    ///
    /// - Parameter config: The MDM configuration to validate
    /// - Throws: ValidationError if validation fails
    public static func validate(_ config: MDMConfiguration) throws {
        // 1. Validate server URL uses HTTPS
        guard config.serverURL.scheme == "https" else {
            throw ValidationError.insecureMDMURL
        }

        // 2. Validate sync interval is positive
        guard config.syncInterval > 0 else {
            throw ValidationError.invalidCheckInterval(Int(config.syncInterval))
        }

        // 3. Validate request timeout is positive
        guard config.requestTimeout > 0 else {
            throw ValidationError.invalidCheckInterval(Int(config.requestTimeout))
        }
    }

    // MARK: - Individual Validation Methods

    /// Validates cleanup level is in valid range (1-4)
    ///
    /// - Parameter level: The cleanup level to validate
    /// - Throws: ValidationError.invalidCleanupLevel if level is out of range
    private static func validateCleanupLevel(_ level: CleanupLevel) throws {
        let rawValue = level.rawValue
        guard (1...4).contains(rawValue) else {
            throw ValidationError.invalidCleanupLevel(rawValue)
        }
    }

    /// Validates an array of paths using PathValidator
    ///
    /// - Parameter paths: Array of path strings to validate
    /// - Throws: ValidationError if any path is invalid
    private static func validatePaths(_ paths: [String]) throws {
        // Use PathValidator with lenient options (don't require existence)
        let options = PathValidator.ValidationOptions.lenient
        _ = try PathValidator.validateAll(paths, options: options)
    }

    /// Checks for conflicting configuration options
    ///
    /// - Parameter config: The configuration to check
    /// - Throws: ValidationError.conflictingOptions if conflicts are detected
    private static func checkConflictingOptions(_ config: CleanerConfiguration) throws {
        // Cannot use system-level cleanup with dry run
        // (system cleanup is typically more dangerous and requires explicit execution)
        if config.cleanupLevel == .system && config.dryRun {
            throw ValidationError.conflictingOptions(
                "System-level cleanup should not be used with dry-run mode"
            )
        }
    }

    // MARK: - Batch Validation

    /// Validates multiple CleanerConfiguration instances
    ///
    /// - Parameter configs: Array of configurations to validate
    /// - Throws: ValidationError for the first invalid configuration
    public static func validateAll(_ configs: [CleanerConfiguration]) throws {
        for config in configs {
            try validate(config)
        }
    }

    /// Validates multiple CleanerConfiguration instances, collecting all errors
    ///
    /// - Parameter configs: Array of configurations to validate
    /// - Returns: Array of validation errors (empty if all valid)
    public static func validateAllWithErrors(
        _ configs: [CleanerConfiguration]
    ) -> [ValidationError] {
        var errors: [ValidationError] = []

        for config in configs {
            do {
                try validate(config)
            } catch let error as ValidationError {
                errors.append(error)
            } catch {
                // Unexpected error, wrap it
                errors.append(.invalidFFIString(error.localizedDescription))
            }
        }

        return errors
    }
}

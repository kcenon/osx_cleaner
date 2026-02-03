// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Detailed errors that can occur during cleanup operations
///
/// This enum provides actionable error messages with context and solutions
/// for cleanup-related failures.
public enum CleanupError: DetailedError {
    /// Attempted to clean a system-protected path
    case systemPathProtected(String)

    /// Insufficient permissions to access path
    case insufficientPermissions(String)

    /// Path does not exist
    case pathNotFound(String)

    /// Not enough disk space for operation
    case diskFull(available: Int64, required: Int64)

    /// Operation was cancelled by user
    case operationCancelled

    /// File is locked or in use
    case fileLocked(String)

    /// Cleanup operation timed out
    case timeout(operation: String, durationSeconds: Int)

    // MARK: - DetailedError Implementation

    public var problem: String {
        switch self {
        case .systemPathProtected(let path):
            return "Cannot clean system directory '\(path)'"
        case .insufficientPermissions(let path):
            return "Permission denied for '\(path)'"
        case .pathNotFound(let path):
            return "Directory not found: '\(path)'"
        case .diskFull(let available, let required):
            return "Insufficient disk space: need \(formatBytes(required)), have \(formatBytes(available))"
        case .operationCancelled:
            return "Cleanup operation was cancelled"
        case .fileLocked(let path):
            return "File is locked or in use: '\(path)'"
        case .timeout(let operation, let duration):
            return "Operation '\(operation)' timed out after \(duration) seconds"
        }
    }

    public var context: String? {
        switch self {
        case .systemPathProtected:
            return "System directories are protected to prevent macOS damage."
        case .insufficientPermissions:
            return "You don't have permission to modify this location."
        case .pathNotFound:
            return "The specified path does not exist or has been moved."
        case .diskFull:
            return "Not enough free space to complete the operation safely."
        case .operationCancelled:
            return "The cleanup was interrupted before completion."
        case .fileLocked:
            return "Another application is using this file."
        case .timeout:
            return "The operation took longer than expected."
        }
    }

    public var solution: String? {
        switch self {
        case .systemPathProtected:
            return """
                Use --level light or specify a user directory instead:
                  osxcleaner clean ~/Library/Caches
                  osxcleaner clean ~/Library/Logs --level normal
                """
        case .insufficientPermissions(let path):
            if path.hasPrefix("/Library") {
                return "Try running with sudo: sudo osxcleaner clean '\(path)'"
            } else {
                return """
                    Check file permissions:
                      ls -la '\(path)'

                    Or change ownership:
                      sudo chown -R $(whoami) '\(path)'
                    """
            }
        case .pathNotFound(let path):
            return """
                Verify the path exists:
                  ls -la '\(path)'

                Or use tab-completion to find the correct path.
                """
        case .diskFull:
            return """
                Free up space first:
                  1. Empty Trash
                  2. Remove large files: osxcleaner analyze --top 10
                  3. Try again with --dry-run to estimate space needed
                """
        case .operationCancelled:
            return "Run the command again to restart the cleanup."
        case .fileLocked(let path):
            return """
                Close applications that may be using this file:
                  lsof '\(path)'

                Or try again after closing the application.
                """
        case .timeout:
            return """
                Try again with a smaller scope:
                  osxcleaner clean --level light
                  osxcleaner clean ~/Library/Caches

                Or increase timeout with --timeout option.
                """
        }
    }

    public var documentation: URL? {
        switch self {
        case .systemPathProtected:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Safety")
        case .insufficientPermissions:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Permissions")
        default:
            return URL(string: "https://github.com/kcenon/osx_cleaner/wiki/Troubleshooting")
        }
    }

    // MARK: - Private Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

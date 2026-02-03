// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Formats detailed errors for CLI output
///
/// Provides consistent formatting for error messages including:
/// - Problem description
/// - Context (if available)
/// - Solution suggestions
/// - Documentation links
///
/// # Example
///
/// ```swift
/// let error = ValidationError.pathNotFound("/invalid/path")
/// let message = ErrorFormatter.format(error)
/// // Error: Directory not found: '/invalid/path'
/// //
/// // The specified path does not exist or has been moved.
/// //
/// // Suggestion: Verify the path exists:
/// //   ls -la '/invalid/path'
/// ```
public struct ErrorFormatter {
    /// ANSI escape sequence prefix
    private static let escape = "\u{1B}["

    /// Format a detailed error for CLI display
    ///
    /// - Parameter error: The error to format
    /// - Returns: Formatted error message string
    public static func format(_ error: DetailedError) -> String {
        var lines: [String] = []

        lines.append("Error: \(error.problem)")

        if let context = error.context {
            lines.append("")
            lines.append(context)
        }

        if let solution = error.solution {
            lines.append("")
            lines.append("Suggestion: \(solution)")
        }

        if let docs = error.documentation {
            lines.append("")
            lines.append("Learn more: \(docs.absoluteString)")
        }

        return lines.joined(separator: "\n")
    }

    /// Format a detailed error with ANSI colors for terminal display
    ///
    /// - Parameters:
    ///   - error: The error to format
    ///   - useColors: Whether to use ANSI color codes (default: true)
    /// - Returns: Formatted error message string with optional colors
    public static func format(_ error: DetailedError, useColors: Bool) -> String {
        guard useColors else {
            return format(error)
        }

        var lines: [String] = []

        let red = "\(escape)\(ANSIColor.red.rawValue)m"
        let yellow = "\(escape)\(ANSIColor.yellow.rawValue)m"
        let cyan = "\(escape)\(ANSIColor.cyan.rawValue)m"
        let dim = "\(escape)\(ANSIColor.dim.rawValue)m"
        let underline = "\(escape)\(ANSIColor.underline.rawValue)m"
        let reset = "\(escape)\(ANSIColor.reset.rawValue)m"

        lines.append("\(red)Error:\(reset) \(error.problem)")

        if let context = error.context {
            lines.append("")
            lines.append("\(dim)\(context)\(reset)")
        }

        if let solution = error.solution {
            lines.append("")
            lines.append("\(yellow)Suggestion:\(reset) \(solution)")
        }

        if let docs = error.documentation {
            lines.append("")
            lines.append("\(cyan)Learn more:\(reset) \(underline)\(docs.absoluteString)\(reset)")
        }

        return lines.joined(separator: "\n")
    }

    /// Format any error for CLI display
    ///
    /// If the error conforms to `DetailedError`, uses the detailed format.
    /// Otherwise, falls back to the error's localized description.
    ///
    /// - Parameter error: The error to format
    /// - Returns: Formatted error message string
    public static func format(_ error: Error) -> String {
        if let detailedError = error as? DetailedError {
            return format(detailedError)
        }
        return "Error: \(error.localizedDescription)"
    }

    /// Format any error with optional colors
    ///
    /// - Parameters:
    ///   - error: The error to format
    ///   - useColors: Whether to use ANSI color codes
    /// - Returns: Formatted error message string
    public static func format(_ error: Error, useColors: Bool) -> String {
        if let detailedError = error as? DetailedError {
            return format(detailedError, useColors: useColors)
        }
        if useColors {
            let red = "\(escape)\(ANSIColor.red.rawValue)m"
            let reset = "\(escape)\(ANSIColor.reset.rawValue)m"
            return "\(red)Error:\(reset) \(error.localizedDescription)"
        }
        return "Error: \(error.localizedDescription)"
    }

    /// Check if the terminal supports colors
    public static var terminalSupportsColors: Bool {
        guard let term = ProcessInfo.processInfo.environment["TERM"] else {
            return false
        }
        return !term.isEmpty && term != "dumb"
    }
}

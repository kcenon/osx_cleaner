// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Protocol for errors that provide detailed, actionable information
///
/// Errors conforming to this protocol can provide:
/// - **Problem**: What exactly went wrong
/// - **Context**: Additional information about when/where the error occurred
/// - **Solution**: How to fix the issue
/// - **Documentation**: Link to relevant documentation
///
/// # Example
///
/// ```swift
/// enum MyError: DetailedError {
///     case fileNotFound(String)
///
///     var problem: String {
///         switch self {
///         case .fileNotFound(let path):
///             return "File not found: '\(path)'"
///         }
///     }
///
///     var solution: String? {
///         "Verify the file path exists and try again."
///     }
/// }
/// ```
public protocol DetailedError: Error {
    /// The main problem description - what went wrong
    var problem: String { get }

    /// Additional context about when/where the error occurred
    var context: String? { get }

    /// Suggested solution or steps to fix the problem
    var solution: String? { get }

    /// URL to relevant documentation
    var documentation: URL? { get }
}

// MARK: - Default Implementations

public extension DetailedError {
    var context: String? { nil }
    var solution: String? { nil }
    var documentation: URL? { nil }
}

// MARK: - LocalizedError Conformance

extension DetailedError {
    public var errorDescription: String? {
        problem
    }

    public var recoverySuggestion: String? {
        solution
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Protocol defining the interface for cleanup operations
///
/// This protocol abstracts the CleanerService to allow dependency injection
/// and easier testing. It defines the core cleanup operations that any
/// cleaner implementation must support.
public protocol CleanerServiceProtocol: Sendable {
    /// Perform cleanup with the specified configuration
    ///
    /// - Parameter config: The cleanup configuration
    /// - Returns: The result of the cleanup operation
    /// - Throws: CleanError if cleanup fails
    func clean(with config: CleanerConfiguration) async throws -> CleanResult

    /// Perform cleanup with specified trigger type
    ///
    /// - Parameters:
    ///   - config: The cleanup configuration
    ///   - triggerType: The type of trigger that initiated the cleanup
    /// - Returns: The result of the cleanup operation
    /// - Throws: CleanError if cleanup fails
    func clean(
        with config: CleanerConfiguration,
        triggerType: CleanupSession.TriggerType
    ) async throws -> CleanResult
}

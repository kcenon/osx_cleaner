// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
@testable import OSXCleanerKit

/// Mock implementation of CleanerServiceProtocol for testing
///
/// This mock allows tests to control the behavior of cleanup operations
/// without performing actual file system operations.
final class MockCleanerService: CleanerServiceProtocol, @unchecked Sendable {
    // MARK: - Call Tracking

    var cleanCallCount = 0
    var lastCleanConfiguration: CleanerConfiguration?
    var lastTriggerType: CleanupSession.TriggerType?

    // MARK: - Stubbed Responses

    var cleanResult: CleanResult?
    var cleanError: Error?

    // MARK: - CleanerServiceProtocol Implementation

    func clean(with config: CleanerConfiguration) async throws -> CleanResult {
        cleanCallCount += 1
        lastCleanConfiguration = config
        lastTriggerType = nil

        if let error = cleanError {
            throw error
        }

        return cleanResult ?? CleanResult(
            freedBytes: 1024,
            filesRemoved: 5,
            directoriesRemoved: 1,
            errors: []
        )
    }

    func clean(
        with config: CleanerConfiguration,
        triggerType: CleanupSession.TriggerType
    ) async throws -> CleanResult {
        cleanCallCount += 1
        lastCleanConfiguration = config
        lastTriggerType = triggerType

        if let error = cleanError {
            throw error
        }

        return cleanResult ?? CleanResult(
            freedBytes: 1024,
            filesRemoved: 5,
            directoriesRemoved: 1,
            errors: []
        )
    }

    // MARK: - Test Helpers

    /// Reset all tracked state
    func reset() {
        cleanCallCount = 0
        lastCleanConfiguration = nil
        lastTriggerType = nil
        cleanResult = nil
        cleanError = nil
    }
}

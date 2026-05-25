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

    // MARK: - Safety Guard

    private var allowedDestructiveRoot: URL?
    private var enforcesSafeDestructiveTargets = false

    // MARK: - CleanerServiceProtocol Implementation

    func clean(with config: CleanerConfiguration) async throws -> CleanResult {
        cleanCallCount += 1
        lastCleanConfiguration = config
        lastTriggerType = nil

        try validateSafeDestructiveTargets(in: config)

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

        try validateSafeDestructiveTargets(in: config)

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
        allowedDestructiveRoot = nil
        enforcesSafeDestructiveTargets = false
    }

    /// Require destructive cleanup requests to target only paths inside a test temp directory.
    func requireDestructiveTargets(inside temporaryDirectory: URL) {
        allowedDestructiveRoot = temporaryDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()
        enforcesSafeDestructiveTargets = true
    }

    private func validateSafeDestructiveTargets(in config: CleanerConfiguration) throws {
        guard enforcesSafeDestructiveTargets, !config.dryRun else {
            return
        }

        var failures: [String] = []

        let broadTargetFlags = [
            (config.includeSystemCaches, "system caches"),
            (config.includeDeveloperCaches, "developer caches"),
            (config.includeBrowserCaches, "browser caches"),
            (config.includeLogsCaches, "logs")
        ]
        let broadTargets = broadTargetFlags.compactMap { target in
            target.0 ? target.1 : nil
        }

        if !broadTargets.isEmpty {
            failures.append("broad targets: \(broadTargets.joined(separator: ", "))")
        }

        if !config.specificPaths.isEmpty {
            guard let root = allowedDestructiveRoot else {
                failures.append("no allowed destructive root configured")
                throw unsafeCleanupError(path: config.specificPaths.joined(separator: ", "), failures: failures)
            }

            for path in config.specificPaths where !isPath(path, containedIn: root) {
                failures.append("outside test temp directory: \(path)")
            }
        }

        if !failures.isEmpty {
            throw unsafeCleanupError(
                path: config.specificPaths.first ?? "<broad-target>",
                failures: failures
            )
        }
    }

    private func unsafeCleanupError(path: String, failures: [String]) -> UnsafeCleanupTargetError {
        UnsafeCleanupTargetError(
            path: path,
            failures: failures
        )
    }

    private func isPath(_ path: String, containedIn root: URL) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let candidatePath = URL(fileURLWithPath: expandedPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        let rootPath = root.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private struct UnsafeCleanupTargetError: LocalizedError {
        let path: String
        let failures: [String]

        var errorDescription: String? {
            "Refusing unsafe cleanup in test at \(path) (\(failures.joined(separator: "; ")))"
        }
    }
}

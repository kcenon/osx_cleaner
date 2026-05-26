// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, OSXCleaner contributors

import Foundation
@testable import OSXCleanerKit

/// Safety guard that rejects destructive cleanup configurations whose targets
/// escape the test temporary directory.
///
/// This is the single source of truth used by both `MockCleanerService` and the
/// integration test suites. It exists so that no Swift test can accidentally
/// invoke a real cleanup against `~/Library`, `/Library`, system caches, or
/// any other location outside an explicit per-test temporary fixture.
///
/// Usage:
/// ```swift
/// let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
/// try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
/// let guardian = DestructiveCleanupGuard(allowedRoot: temp)
/// try guardian.assertSafe(config)
/// ```
struct DestructiveCleanupGuard {

    /// Directory the cleanup target paths must stay inside.
    let allowedRoot: URL

    /// Failure raised when a destructive configuration references paths or
    /// broad-target flags that the guard does not allow.
    struct UnsafeCleanupTargetError: LocalizedError, Equatable {
        let path: String
        let failures: [String]

        var errorDescription: String? {
            "Refusing unsafe cleanup in test at \(path) (\(failures.joined(separator: "; ")))"
        }
    }

    init(allowedRoot: URL) {
        self.allowedRoot = allowedRoot
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    /// Validate a `CleanerConfiguration` and throw if it would perform
    /// destructive work outside the allowed temporary directory.
    ///
    /// Dry-run configurations are always allowed because they cannot delete
    /// anything. Destructive configurations must:
    /// - Not enable broad-target flags (`includeSystemCaches`, etc.).
    /// - Declare every entry in `specificPaths` to be inside `allowedRoot`.
    func assertSafe(_ config: CleanerConfiguration) throws {
        guard !config.dryRun else { return }

        var failures: [String] = []

        let broadTargets: [(Bool, String)] = [
            (config.includeSystemCaches, "system caches"),
            (config.includeDeveloperCaches, "developer caches"),
            (config.includeBrowserCaches, "browser caches"),
            (config.includeLogsCaches, "logs")
        ]
        let enabledBroad = broadTargets.compactMap { $0.0 ? $0.1 : nil }
        if !enabledBroad.isEmpty {
            failures.append("broad targets: \(enabledBroad.joined(separator: ", "))")
        }

        for path in config.specificPaths where !isPath(path, inside: allowedRoot) {
            failures.append("outside test temp directory: \(path)")
        }

        if !failures.isEmpty {
            throw UnsafeCleanupTargetError(
                path: config.specificPaths.first ?? "<broad-target>",
                failures: failures
            )
        }
    }

    /// Returns true when `path` is exactly `root` or sits beneath it after
    /// tilde expansion, standardization, and symlink resolution.
    static func isPath(_ path: String, inside root: URL) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        let candidate = URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let rootPath = root
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return candidate == rootPath || candidate.hasPrefix(rootPath + "/")
    }

    private func isPath(_ path: String, inside root: URL) -> Bool {
        Self.isPath(path, inside: root)
    }
}

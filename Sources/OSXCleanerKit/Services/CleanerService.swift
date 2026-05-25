// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Result of a cleanup operation
public struct CleanResult {
    public let freedBytes: UInt64
    public let filesRemoved: Int
    public let directoriesRemoved: Int
    public let errors: [CleanError]

    public var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(freedBytes), countStyle: .file)
    }

    public init(
        freedBytes: UInt64,
        filesRemoved: Int,
        directoriesRemoved: Int = 0,
        errors: [CleanError] = []
    ) {
        self.freedBytes = freedBytes
        self.filesRemoved = filesRemoved
        self.directoriesRemoved = directoriesRemoved
        self.errors = errors
    }
}

/// Error during cleanup
public struct CleanError: Error {
    public let path: String
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

/// Service for performing cleanup operations
///
/// This service uses the Rust core library for high-performance file cleanup
/// with safety validation. Falls back to Swift implementation if Rust core
/// is not available.
public final class CleanerService: CleanerServiceProtocol {
    private let fileManager: FileManager
    private let rustBridge: RustBridge
    private let loggingService: AutomatedCleanupLoggingService
    private var useRustCore: Bool = true
    private var hasNotifiedRustFailure: Bool = false
    private var rustInitError: Error?

    public init(
        fileManager: FileManager = .default,
        rustBridge: RustBridge = .shared,
        loggingService: AutomatedCleanupLoggingService = .shared,
        forceSwiftFallback: Bool = false
    ) {
        self.fileManager = fileManager
        self.rustBridge = rustBridge
        self.loggingService = loggingService

        // Force Swift fallback if requested (for testing)
        if forceSwiftFallback {
            useRustCore = false
            AppLogger.shared.info("Using Swift fallback (forced for testing)")
            return
        }

        // Try to initialize Rust core
        do {
            try rustBridge.initialize()
            AppLogger.shared.info("Rust core initialized successfully")
        } catch {
            AppLogger.shared.warning("Rust core unavailable, using Swift fallback: \(error)")
            useRustCore = false
            rustInitError = error
        }
    }

    public func clean(with config: CleanerConfiguration) async throws -> CleanResult {
        try await clean(with: config, triggerType: .manual)
    }

    /// Perform cleanup with specified trigger type for logging purposes
    /// - Parameters:
    ///   - config: The cleanup configuration
    ///   - triggerType: The type of trigger that initiated the cleanup
    /// - Returns: The cleanup result
    public func clean(
        with config: CleanerConfiguration,
        triggerType: CleanupSession.TriggerType
    ) async throws -> CleanResult {
        // Notify about Rust core failure on first cleanup
        if let error = rustInitError, !hasNotifiedRustFailure {
            await notifyRustCoreFailure(error: error)
        }

        let startTime = Date()
        var session = CleanupSession(
            triggerType: triggerType,
            cleanupLevel: "\(config.cleanupLevel)"
        )

        // Log session start for automated cleanups
        if triggerType != .manual {
            loggingService.logSessionStart(session)
        }

        AppLogger.shared.operation("Starting cleanup with level \(config.cleanupLevel)")

        var totalFreed: UInt64 = 0
        var filesRemoved = 0
        var directoriesRemoved = 0
        var errors: [CleanError] = []

        let targets = collectTargets(from: config)

        for target in targets {
            do {
                let result: CleanResult
                if useRustCore {
                    result = try await cleanTargetWithRust(target, config: config)
                } else {
                    result = try await cleanTargetWithSwift(target, config: config)
                }
                totalFreed += result.freedBytes
                filesRemoved += result.filesRemoved
                directoriesRemoved += result.directoriesRemoved
                errors.append(contentsOf: result.errors)
            } catch {
                let cleanError = CleanError(
                    path: target.path,
                    reason: error.localizedDescription
                )
                errors.append(cleanError)

                // Log errors for automated cleanups
                if triggerType != .manual {
                    loggingService.logError(
                        sessionId: session.sessionId,
                        path: target.path,
                        error: error.localizedDescription
                    )
                }
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        AppLogger.shared.success("Cleanup completed: \(filesRemoved) files, \(directoriesRemoved) directories, \(totalFreed) bytes freed")

        // Log session end for automated cleanups
        if triggerType != .manual {
            session.endTime = endTime
            session.result = CleanupSessionResult(
                freedBytes: totalFreed,
                filesRemoved: filesRemoved,
                directoriesRemoved: directoriesRemoved,
                errorsCount: errors.count,
                durationSeconds: duration
            )
            loggingService.logSessionEnd(session)
        }

        return CleanResult(
            freedBytes: totalFreed,
            filesRemoved: filesRemoved,
            directoriesRemoved: directoriesRemoved,
            errors: errors
        )
    }

    // MARK: - Rust Core Cleanup

    private func cleanTargetWithRust(_ target: CleanTarget, config: CleanerConfiguration) async throws -> CleanResult {
        guard fileManager.fileExists(atPath: target.path) else {
            return CleanResult(freedBytes: 0, filesRemoved: 0)
        }

        let rustResult = try rustBridge.cleanPath(
            target.path,
            cleanupLevel: config.cleanupLevel,
            dryRun: config.dryRun
        )

        let errors = rustResult.errors.map { errorInfo in
            CleanError(path: errorInfo.path, reason: errorInfo.reason)
        }

        return CleanResult(
            freedBytes: rustResult.freedBytes,
            filesRemoved: rustResult.filesRemoved,
            directoriesRemoved: rustResult.directoriesRemoved,
            errors: errors
        )
    }

    // MARK: - Swift Fallback Cleanup

    private func cleanTargetWithSwift(_ target: CleanTarget, config: CleanerConfiguration) async throws -> CleanResult {
        let canonicalPath: String
        do {
            canonicalPath = try PathValidator.validatePath(
                target.path,
                options: PathValidator.ValidationOptions(
                    checkExistence: true,
                    checkReadability: false,
                    allowSystemPaths: true,
                    expandTilde: true
                )
            )
        } catch ValidationError.pathNotFound(_) {
            return CleanResult(freedBytes: 0, filesRemoved: 0)
        } catch let error as ValidationError {
            return skippedTargetResult(path: target.path, reason: error.problem)
        }

        let safetyLevel = try safetyLevel(for: target, canonicalPath: canonicalPath)
        guard safetyLevel != .danger else {
            return skippedTargetResult(
                path: canonicalPath,
                reason: "Safety policy blocked danger-level cleanup target"
            )
        }

        guard config.cleanupLevel.canDelete(safetyLevel) else {
            return skippedTargetResult(
                path: canonicalPath,
                reason: """
                Safety policy requires \(requiredCleanupLevel(for: safetyLevel).description) \
                for \(safetyLevel.description)
                """
            )
        }

        let size = try calculateSize(at: canonicalPath)

        if !config.dryRun {
            // Use FileOperationRetry for resilient file removal
            try await FileOperationRetry.remove(canonicalPath)
        }

        AppLogger.shared.info("Cleaned: \(canonicalPath) (\(size) bytes)")

        return CleanResult(freedBytes: size, filesRemoved: 1)
    }

    private func skippedTargetResult(path: String, reason: String) -> CleanResult {
        CleanResult(
            freedBytes: 0,
            filesRemoved: 0,
            errors: [CleanError(path: path, reason: reason)]
        )
    }

    private func safetyLevel(for target: CleanTarget, canonicalPath: String) throws -> SafetyLevel {
        switch target.category {
        case .browserCache:
            return .safe
        case .logs:
            return .caution
        case .systemCache, .developerCache, .custom:
            return try PathValidator.safetyLevel(for: canonicalPath)
        }
    }

    private func requiredCleanupLevel(for safetyLevel: SafetyLevel) -> CleanupLevel {
        switch safetyLevel {
        case .safe:
            return .light
        case .caution:
            return .normal
        case .warning:
            return .deep
        case .danger:
            return .system
        }
    }

    private func collectTargets(from config: CleanerConfiguration) -> [CleanTarget] {
        var targets: [CleanTarget] = []

        if config.includeSystemCaches {
            targets.append(contentsOf: systemCacheTargets())
        }

        if config.includeDeveloperCaches {
            targets.append(contentsOf: developerCacheTargets())
        }

        if config.includeBrowserCaches {
            targets.append(contentsOf: browserCacheTargets())
        }

        if config.includeLogsCaches {
            targets.append(contentsOf: logsCacheTargets())
        }

        for path in config.specificPaths {
            targets.append(CleanTarget(path: path, category: .custom))
        }

        return targets
    }

    private func systemCacheTargets() -> [CleanTarget] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            CleanTarget(path: "\(home)/Library/Caches", category: .systemCache),
            CleanTarget(path: "/Library/Caches", category: .systemCache)
        ]
    }

    private func developerCacheTargets() -> [CleanTarget] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            CleanTarget(path: "\(home)/Library/Developer/Xcode/DerivedData", category: .developerCache),
            CleanTarget(path: "\(home)/Library/Developer/Xcode/Archives", category: .developerCache),
            CleanTarget(path: "\(home)/.gradle/caches", category: .developerCache),
            CleanTarget(path: "\(home)/.npm/_cacache", category: .developerCache),
            CleanTarget(path: "\(home)/.cargo/registry/cache", category: .developerCache)
        ]
    }

    private func browserCacheTargets() -> [CleanTarget] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            CleanTarget(
                path: "\(home)/Library/Caches/com.apple.Safari",
                category: .browserCache
            ),
            CleanTarget(
                path: "\(home)/Library/Caches/Google/Chrome",
                category: .browserCache
            ),
            CleanTarget(
                path: "\(home)/Library/Caches/Firefox",
                category: .browserCache
            )
        ]
    }

    private func logsCacheTargets() -> [CleanTarget] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            CleanTarget(
                path: "\(home)/Library/Logs",
                category: .logs
            ),
            CleanTarget(
                path: "\(home)/Library/Logs/DiagnosticReports",
                category: .logs
            )
        ]
    }

    private func calculateSize(at path: String) throws -> UInt64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            if let size = attrs[.size] as? UInt64 {
                return size
            }
            if let size = attrs[.size] as? NSNumber {
                return size.uint64Value
            }
            if let size = attrs[.size] as? Int64 {
                return UInt64(size)
            }
            if let size = attrs[.size] as? Int {
                return UInt64(size)
            }
            return 0
        }

        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? UInt64 {
                totalSize += size
            }
        }

        return totalSize
    }

    // MARK: - Rust Core Failure Notification

    private func notifyRustCoreFailure(error: Error) async {
        // Only notify once per session
        guard !hasNotifiedRustFailure else { return }
        hasNotifiedRustFailure = true

        // Check if performance warnings are enabled
        let configService = ConfigurationService()
        guard let config = try? configService.load(),
              config.showPerformanceWarnings else {
            return
        }

        // Send notification
        let notificationService = NotificationService.shared
        await notificationService.sendRustCoreFailure(error: error)

        // Print CLI warning to stderr
        printRustCoreWarning(error: error)
    }

    private func printRustCoreWarning(error: Error) {
        let warning = """
        ⚠️  WARNING: Rust core unavailable - running in compatibility mode

        Performance Impact:
        - Cleanup operations may be 10-50x slower
        - Swift fallback still enforces path safety policy

        Reason: \(error.localizedDescription)

        To resolve:
        1. Ensure libosxcore.dylib is in the expected location
        2. Run 'osxcleaner diagnose' for detailed information
        3. Reinstall OSX Cleaner if the issue persists

        """
        if let data = warning.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}

/// Target for cleanup
struct CleanTarget {
    let path: String
    let category: Category

    enum Category {
        case systemCache
        case developerCache
        case browserCache
        case logs
        case custom
    }
}

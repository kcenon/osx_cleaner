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
public final class CleanerService {
    private let fileManager: FileManager
    private let rustBridge: RustBridge
    private var useRustCore: Bool = true

    public init(
        fileManager: FileManager = .default,
        rustBridge: RustBridge = .shared
    ) {
        self.fileManager = fileManager
        self.rustBridge = rustBridge

        // Try to initialize Rust core
        do {
            try rustBridge.initialize()
        } catch {
            AppLogger.shared.warning("Rust core unavailable, using Swift fallback: \(error)")
            useRustCore = false
        }
    }

    public func clean(with config: CleanerConfiguration) async throws -> CleanResult {
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
                    result = try await cleanTargetWithSwift(target, dryRun: config.dryRun)
                }
                totalFreed += result.freedBytes
                filesRemoved += result.filesRemoved
                directoriesRemoved += result.directoriesRemoved
                errors.append(contentsOf: result.errors)
            } catch {
                errors.append(CleanError(
                    path: target.path,
                    reason: error.localizedDescription
                ))
            }
        }

        AppLogger.shared.success("Cleanup completed: \(filesRemoved) files, \(directoriesRemoved) directories, \(totalFreed) bytes freed")

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

    private func cleanTargetWithSwift(_ target: CleanTarget, dryRun: Bool) async throws -> CleanResult {
        guard fileManager.fileExists(atPath: target.path) else {
            return CleanResult(freedBytes: 0, filesRemoved: 0)
        }

        let size = try calculateSize(at: target.path)

        if !dryRun {
            try fileManager.removeItem(atPath: target.path)
        }

        AppLogger.shared.info("Cleaned: \(target.path) (\(size) bytes)")

        return CleanResult(freedBytes: size, filesRemoved: 1)
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

    private func calculateSize(at path: String) throws -> UInt64 {
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
}

/// Target for cleanup
struct CleanTarget {
    let path: String
    let category: Category

    enum Category {
        case systemCache
        case developerCache
        case browserCache
        case custom
    }
}

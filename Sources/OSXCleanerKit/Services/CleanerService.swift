import Foundation

/// Result of a cleanup operation
public struct CleanResult {
    public let freedBytes: UInt64
    public let filesRemoved: Int
    public let errors: [CleanError]

    public var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(freedBytes), countStyle: .file)
    }

    public init(freedBytes: UInt64, filesRemoved: Int, errors: [CleanError] = []) {
        self.freedBytes = freedBytes
        self.filesRemoved = filesRemoved
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
public final class CleanerService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func clean(with config: CleanerConfiguration) async throws -> CleanResult {
        AppLogger.shared.operation("Starting cleanup with safety level \(config.safetyLevel)")

        var totalFreed: UInt64 = 0
        var filesRemoved = 0
        var errors: [CleanError] = []

        let targets = collectTargets(from: config)

        for target in targets {
            do {
                let result = try await cleanTarget(target, dryRun: config.dryRun)
                totalFreed += result.freedBytes
                filesRemoved += result.filesRemoved
            } catch {
                errors.append(CleanError(
                    path: target.path,
                    reason: error.localizedDescription
                ))
            }
        }

        AppLogger.shared.success("Cleanup completed: \(filesRemoved) files, \(totalFreed) bytes freed")

        return CleanResult(
            freedBytes: totalFreed,
            filesRemoved: filesRemoved,
            errors: errors
        )
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

    private func cleanTarget(_ target: CleanTarget, dryRun: Bool) async throws -> CleanResult {
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

import Foundation

/// Result of disk analysis
public struct AnalysisResult {
    public let totalSize: UInt64
    public let potentialSavings: UInt64
    public let categories: [AnalysisCategory]

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    public var formattedPotentialSavings: String {
        ByteCountFormatter.string(fromByteCount: Int64(potentialSavings), countStyle: .file)
    }

    public init(totalSize: UInt64, potentialSavings: UInt64, categories: [AnalysisCategory]) {
        self.totalSize = totalSize
        self.potentialSavings = potentialSavings
        self.categories = categories
    }
}

/// Category of analyzed items
public struct AnalysisCategory {
    public let name: String
    public let size: UInt64
    public let itemCount: Int
    public let topItems: [AnalysisItem]

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    public init(name: String, size: UInt64, itemCount: Int, topItems: [AnalysisItem]) {
        self.name = name
        self.size = size
        self.itemCount = itemCount
        self.topItems = topItems
    }
}

/// Individual analyzed item
public struct AnalysisItem {
    public let path: String
    public let size: UInt64
    public let lastAccessed: Date?

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    public init(path: String, size: UInt64, lastAccessed: Date? = nil) {
        self.path = path
        self.size = size
        self.lastAccessed = lastAccessed
    }
}

/// Service for analyzing disk usage
public final class AnalyzerService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func analyze(with config: AnalyzerConfiguration) async throws -> AnalysisResult {
        AppLogger.shared.operation("Starting analysis of \(config.targetPath)")

        var categories: [AnalysisCategory] = []
        var totalSize: UInt64 = 0
        var potentialSavings: UInt64 = 0

        // Analyze system caches
        let systemCaches = try await analyzeCategory(
            name: "System Caches",
            paths: systemCachePaths(),
            config: config
        )
        categories.append(systemCaches)
        totalSize += systemCaches.size
        potentialSavings += systemCaches.size

        // Analyze developer caches
        let developerCaches = try await analyzeCategory(
            name: "Developer Caches",
            paths: developerCachePaths(),
            config: config
        )
        categories.append(developerCaches)
        totalSize += developerCaches.size
        potentialSavings += developerCaches.size

        // Analyze browser caches
        let browserCaches = try await analyzeCategory(
            name: "Browser Caches",
            paths: browserCachePaths(),
            config: config
        )
        categories.append(browserCaches)
        totalSize += browserCaches.size
        potentialSavings += browserCaches.size

        // Analyze logs
        let logs = try await analyzeCategory(
            name: "Logs",
            paths: logPaths(),
            config: config
        )
        categories.append(logs)
        totalSize += logs.size
        potentialSavings += logs.size

        // Analyze downloads (informational only)
        let downloads = try await analyzeCategory(
            name: "Downloads",
            paths: downloadPaths(),
            config: config
        )
        categories.append(downloads)
        totalSize += downloads.size
        // Downloads not included in potential savings by default

        AppLogger.shared.success("Analysis completed: \(totalSize) bytes analyzed")

        return AnalysisResult(
            totalSize: totalSize,
            potentialSavings: potentialSavings,
            categories: categories.filter { $0.size > 0 }
        )
    }

    private func analyzeCategory(
        name: String,
        paths: [String],
        config: AnalyzerConfiguration
    ) async throws -> AnalysisCategory {
        var items: [AnalysisItem] = []
        var totalSize: UInt64 = 0

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }

            let size = try calculateSize(at: path)
            if let minSize = config.minSize, size < minSize {
                continue
            }

            items.append(AnalysisItem(path: path, size: size))
            totalSize += size
        }

        // Sort by size descending
        items.sort { $0.size > $1.size }

        return AnalysisCategory(
            name: name,
            size: totalSize,
            itemCount: items.count,
            topItems: items
        )
    }

    private func calculateSize(at path: String) throws -> UInt64 {
        var totalSize: UInt64 = 0
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if isDirectory.boolValue {
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
        } else {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64 {
                totalSize = size
            }
        }

        return totalSize
    }

    // MARK: - Path Definitions

    private func systemCachePaths() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches"
        ]
    }

    private func developerCachePaths() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/CoreSimulator/Devices",
            "\(home)/.gradle/caches",
            "\(home)/.npm/_cacache",
            "\(home)/.cargo/registry/cache",
            "\(home)/.pub-cache"
        ]
    }

    private func browserCachePaths() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Google/Chrome",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Application Support/Google/Chrome/Default/Cache"
        ]
    }

    private func logPaths() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Logs",
            "/Library/Logs",
            "/var/log"
        ]
    }

    private func downloadPaths() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Downloads"
        ]
    }
}

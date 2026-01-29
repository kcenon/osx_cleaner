// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Result of disk space analysis
///
/// Contains detailed statistics about analyzed files and directories,
/// including potential space savings and categorized items.
///
/// ## Topics
///
/// ### Properties
/// - ``totalSize``
/// - ``potentialSavings``
/// - ``fileCount``
/// - ``directoryCount``
/// - ``categories``
/// - ``largestItems``
/// - ``oldestItems``
///
/// ### Formatted Output
/// - ``formattedTotalSize``
/// - ``formattedPotentialSavings``
public struct AnalysisResult {
    /// Total size of all analyzed files and directories in bytes
    public let totalSize: UInt64

    /// Estimated space that could be recovered by cleanup operations
    public let potentialSavings: UInt64

    /// Total number of files analyzed
    public let fileCount: Int

    /// Total number of directories analyzed
    public let directoryCount: Int

    /// Items grouped by category (caches, logs, etc.)
    public let categories: [AnalysisCategory]

    /// Top items sorted by size (largest first)
    public let largestItems: [AnalysisItem]

    /// Items sorted by access time (oldest first)
    public let oldestItems: [AnalysisItem]

    /// Human-readable string representation of total size
    ///
    /// - Returns: Formatted string (e.g., "1.5 GB")
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    /// Human-readable string representation of potential savings
    ///
    /// - Returns: Formatted string (e.g., "500 MB")
    public var formattedPotentialSavings: String {
        ByteCountFormatter.string(fromByteCount: Int64(potentialSavings), countStyle: .file)
    }

    public init(
        totalSize: UInt64,
        potentialSavings: UInt64,
        fileCount: Int = 0,
        directoryCount: Int = 0,
        categories: [AnalysisCategory],
        largestItems: [AnalysisItem] = [],
        oldestItems: [AnalysisItem] = []
    ) {
        self.totalSize = totalSize
        self.potentialSavings = potentialSavings
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.categories = categories
        self.largestItems = largestItems
        self.oldestItems = oldestItems
    }
}

/// Category of analyzed items
///
/// Groups related items together (e.g., "System Caches", "Developer Caches")
/// and provides aggregate statistics for each category.
///
/// ## Topics
///
/// ### Properties
/// - ``name``
/// - ``size``
/// - ``itemCount``
/// - ``topItems``
///
/// ### Formatted Output
/// - ``formattedSize``
public struct AnalysisCategory {
    /// Category name (e.g., "System Caches", "Logs")
    public let name: String

    /// Total size of all items in this category (bytes)
    public let size: UInt64

    /// Number of items in this category
    public let itemCount: Int

    /// Top items in this category, sorted by size
    public let topItems: [AnalysisItem]

    /// Human-readable string representation of category size
    ///
    /// - Returns: Formatted string (e.g., "300 MB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    public init(name: String, size: UInt64, itemCount: Int, topItems: [AnalysisItem] = []) {
        self.name = name
        self.size = size
        self.itemCount = itemCount
        self.topItems = topItems
    }
}

/// Individual analyzed item
///
/// Represents a single file or directory discovered during analysis,
/// including its location, size, and access metadata.
///
/// ## Topics
///
/// ### Properties
/// - ``path``
/// - ``size``
/// - ``lastAccessed``
/// - ``category``
///
/// ### Formatted Output
/// - ``formattedSize``
public struct AnalysisItem {
    /// Full filesystem path to the item
    public let path: String

    /// Size of the item in bytes
    public let size: UInt64

    /// Last access/modification time of the item
    public let lastAccessed: Date?

    /// Category this item belongs to (if categorized)
    public let category: String?

    /// Human-readable string representation of item size
    ///
    /// - Returns: Formatted string (e.g., "45 KB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    public init(path: String, size: UInt64, lastAccessed: Date? = nil, category: String? = nil) {
        self.path = path
        self.size = size
        self.lastAccessed = lastAccessed
        self.category = category
    }
}

/// Service for analyzing disk usage
///
/// `AnalyzerService` provides high-performance disk space analysis by leveraging
/// the Rust core library for parallel directory scanning. When Rust core is unavailable,
/// it automatically falls back to a Swift implementation.
///
/// ## Overview
///
/// This service scans directories to identify:
/// - System caches
/// - Developer build artifacts
/// - Browser caches
/// - Log files
/// - Other cleanable items
///
/// ## Usage
///
/// ```swift
/// let analyzer = AnalyzerService()
/// let config = AnalyzerConfiguration(targetPath: "/Users/example/Library/Caches")
/// let result = try await analyzer.analyze(with: config)
///
/// print("Total size: \(result.formattedTotalSize)")
/// print("Potential savings: \(result.formattedPotentialSavings)")
/// print("Found \(result.categories.count) categories")
/// ```
///
/// ## Performance
///
/// - **Rust Core**: Parallel scanning with rayon (recommended)
/// - **Swift Fallback**: Sequential scanning (slower but always available)
///
/// The service automatically selects the best available implementation.
///
/// ## Safety
///
/// This service only analyzes paths and does not modify the filesystem.
/// Use ``CleanerService`` to perform cleanup operations based on analysis results.
///
/// ## Topics
///
/// ### Analyzing Paths
/// - ``analyze(with:)``
///
/// ### Related Types
/// - ``AnalysisResult``
/// - ``AnalysisCategory``
/// - ``AnalysisItem``
/// - ``AnalyzerConfiguration``
public final class AnalyzerService {
    private let fileManager: FileManager
    private let rustBridge: RustBridge
    private var useRustCore: Bool = true

    /// Creates a new analyzer service instance
    ///
    /// - Parameters:
    ///   - fileManager: File manager for filesystem operations
    ///   - rustBridge: Bridge to Rust core library
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

    /// Analyze a path for cleanup opportunities
    ///
    /// This method performs deep analysis of the specified path, identifying
    /// cached files, logs, and other cleanable content. It automatically uses
    /// the Rust core for performance when available.
    ///
    /// - Parameter config: Configuration specifying target path and options
    /// - Returns: Detailed analysis results
    /// - Throws: ``RustBridgeError`` if Rust analysis fails, or file system errors
    ///
    /// ## Example
    ///
    /// ```swift
    /// let analyzer = AnalyzerService()
    /// let config = AnalyzerConfiguration(
    ///     targetPath: "~/Library/Caches",
    ///     minSize: 1024 * 1024  // Only show items >= 1 MB
    /// )
    /// let result = try await analyzer.analyze(with: config)
    /// ```
    ///
    /// ## Performance Notes
    ///
    /// - Large directories may take several seconds to analyze
    /// - Rust core provides 3-5x faster analysis than Swift fallback
    /// - Analysis does not modify any files
    ///
    /// - Important: Requires read permissions on the target path
    public func analyze(with config: AnalyzerConfiguration) async throws -> AnalysisResult {
        AppLogger.shared.operation("Starting analysis of \(config.targetPath)")

        // Use Rust core for single path analysis
        if useRustCore && !config.targetPath.isEmpty && config.targetPath != "~" {
            return try await analyzeWithRust(config)
        }

        return try await analyzeWithSwift(config)
    }

    // MARK: - Rust Core Analysis

    private func analyzeWithRust(_ config: AnalyzerConfiguration) async throws -> AnalysisResult {
        let expandedPath = (config.targetPath as NSString).expandingTildeInPath

        let rustResult = try rustBridge.analyzePath(expandedPath)

        let categories = rustResult.categories.map { cat in
            AnalysisCategory(
                name: cat.category,
                size: cat.size,
                itemCount: cat.count
            )
        }

        let largestItems = rustResult.largestItems.map { item in
            AnalysisItem(
                path: item.path,
                size: item.size,
                lastAccessed: item.modified.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                category: item.category
            )
        }

        let oldestItems = rustResult.oldestItems.map { item in
            AnalysisItem(
                path: item.path,
                size: item.size,
                lastAccessed: item.modified.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                category: item.category
            )
        }

        AppLogger.shared.success("Rust analysis completed: \(rustResult.fileCount) files, \(rustResult.totalSize) bytes")

        return AnalysisResult(
            totalSize: rustResult.totalSize,
            potentialSavings: rustResult.totalSize,
            fileCount: rustResult.fileCount,
            directoryCount: rustResult.directoryCount,
            categories: categories,
            largestItems: largestItems,
            oldestItems: oldestItems
        )
    }

    // MARK: - Swift Fallback Analysis

    private func analyzeWithSwift(_ config: AnalyzerConfiguration) async throws -> AnalysisResult {
        AppLogger.shared.info("Using Swift fallback for analysis")

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

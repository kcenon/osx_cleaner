// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Application configuration
///
/// Global settings for OSX Cleaner application behavior, including
/// default cleanup levels, logging, and server connection settings.
///
/// ## Topics
///
/// ### Creating Configuration
/// - ``default``
/// - ``init(defaultSafetyLevel:autoBackup:logLevel:excludedPaths:showPerformanceWarnings:serverURL:serverTimeout:agentId:authToken:tokenExpiresAt:lastHeartbeat:)``
///
/// ### Cleanup Settings
/// - ``defaultSafetyLevel``
/// - ``autoBackup``
/// - ``excludedPaths``
///
/// ### Logging
/// - ``logLevel``
/// - ``showPerformanceWarnings``
///
/// ### Server Connection
/// - ``serverURL``
/// - ``serverTimeout``
/// - ``agentId``
/// - ``authToken``
/// - ``tokenExpiresAt``
/// - ``lastHeartbeat``
public struct AppConfiguration: Codable {
    public var defaultSafetyLevel: Int
    public var autoBackup: Bool
    public var logLevel: String
    public var excludedPaths: [String]
    public var showPerformanceWarnings: Bool

    // Server connection settings
    public var serverURL: String?
    public var serverTimeout: Int?
    public var agentId: UUID?
    public var authToken: String?
    public var tokenExpiresAt: Date?
    public var lastHeartbeat: Date?

    public static let `default` = AppConfiguration(
        defaultSafetyLevel: 2, // Normal cleanup level
        autoBackup: true,
        logLevel: "info",
        excludedPaths: [
            "~/Documents",
            "~/Desktop",
            "~/Pictures",
            "~/Music",
            "~/Movies"
        ],
        showPerformanceWarnings: true
    )

    public init(
        defaultSafetyLevel: Int = 3,
        autoBackup: Bool = true,
        logLevel: String = "info",
        excludedPaths: [String] = [],
        showPerformanceWarnings: Bool = true,
        serverURL: String? = nil,
        serverTimeout: Int? = nil,
        agentId: UUID? = nil,
        authToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        lastHeartbeat: Date? = nil
    ) {
        self.defaultSafetyLevel = defaultSafetyLevel
        self.autoBackup = autoBackup
        self.logLevel = logLevel
        self.excludedPaths = excludedPaths
        self.showPerformanceWarnings = showPerformanceWarnings
        self.serverURL = serverURL
        self.serverTimeout = serverTimeout
        self.agentId = agentId
        self.authToken = authToken
        self.tokenExpiresAt = tokenExpiresAt
        self.lastHeartbeat = lastHeartbeat
    }
}

/// Configuration for cleanup operations
public struct CleanerConfiguration {
    public let cleanupLevel: CleanupLevel
    public let dryRun: Bool
    public let includeSystemCaches: Bool
    public let includeDeveloperCaches: Bool
    public let includeBrowserCaches: Bool
    public let includeLogsCaches: Bool
    public let specificPaths: [String]

    public init(
        cleanupLevel: CleanupLevel = .normal,
        dryRun: Bool = false,
        includeSystemCaches: Bool = false,
        includeDeveloperCaches: Bool = false,
        includeBrowserCaches: Bool = false,
        includeLogsCaches: Bool = false,
        specificPaths: [String] = []
    ) {
        self.cleanupLevel = cleanupLevel
        self.dryRun = dryRun
        self.includeSystemCaches = includeSystemCaches
        self.includeDeveloperCaches = includeDeveloperCaches
        self.includeBrowserCaches = includeBrowserCaches
        self.includeLogsCaches = includeLogsCaches
        self.specificPaths = specificPaths
    }

    /// Create configuration from legacy safety level (deprecated)
    @available(*, deprecated, message: "Use cleanupLevel instead of safetyLevel")
    public init(
        safetyLevel: Int,
        dryRun: Bool = false,
        includeSystemCaches: Bool = false,
        includeDeveloperCaches: Bool = false,
        includeBrowserCaches: Bool = false,
        includeLogsCaches: Bool = false,
        specificPaths: [String] = []
    ) {
        self.cleanupLevel = CleanupLevel(rawValue: Int32(safetyLevel)) ?? .normal
        self.dryRun = dryRun
        self.includeSystemCaches = includeSystemCaches
        self.includeDeveloperCaches = includeDeveloperCaches
        self.includeBrowserCaches = includeBrowserCaches
        self.includeLogsCaches = includeLogsCaches
        self.specificPaths = specificPaths
    }
}

/// Configuration for analysis operations
///
/// Specifies parameters for disk space analysis operations.
///
/// ## Topics
///
/// ### Creating Configuration
/// - ``init(targetPath:minSize:verbose:includeHidden:)``
///
/// ### Properties
/// - ``targetPath``
/// - ``minSize``
/// - ``verbose``
/// - ``includeHidden``
public struct AnalyzerConfiguration {
    /// Path to analyze (supports tilde expansion)
    public let targetPath: String

    /// Minimum file size to include in results (bytes)
    public let minSize: UInt64?

    /// Enable verbose output during analysis
    public let verbose: Bool

    /// Include hidden files and directories in analysis
    public let includeHidden: Bool

    public init(
        targetPath: String,
        minSize: UInt64? = nil,
        verbose: Bool = false,
        includeHidden: Bool = false
    ) {
        self.targetPath = targetPath
        self.minSize = minSize
        self.verbose = verbose
        self.includeHidden = includeHidden
    }
}

/// Configuration service for loading and saving settings
public final class ConfigurationService {
    private let configURL: URL

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.configURL = appSupport
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("config.json")
    }

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    public func save(_ config: AppConfiguration) throws {
        let directory = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL)
    }

    public func set(key: String, value: String) throws {
        var config = try load()

        switch key.lowercased() {
        case "safetylevel", "safety-level", "default-safety-level", "cleanuplevel", "cleanup-level":
            guard let level = Int(value), (1...4).contains(level) else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            config.defaultSafetyLevel = level

        case "autobackup", "auto-backup":
            guard let enabled = Bool(value) else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            config.autoBackup = enabled

        case "loglevel", "log-level":
            let validLevels = ["debug", "info", "warning", "error"]
            guard validLevels.contains(value.lowercased()) else {
                throw ConfigurationError.invalidValue(key: key, value: value)
            }
            config.logLevel = value.lowercased()

        default:
            throw ConfigurationError.unknownKey(key)
        }

        try save(config)
    }

    public func reset() throws {
        try save(.default)
    }
}

public enum ConfigurationError: LocalizedError {
    case unknownKey(String)
    case invalidValue(key: String, value: String)

    public var errorDescription: String? {
        switch self {
        case .unknownKey(let key):
            return "Unknown configuration key: \(key)"
        case .invalidValue(let key, let value):
            return "Invalid value '\(value)' for key '\(key)'"
        }
    }
}

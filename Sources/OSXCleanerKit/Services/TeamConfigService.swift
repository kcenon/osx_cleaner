// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Yams

/// Service for managing team configurations
///
/// Handles loading, validating, applying, and syncing team configurations
/// from local files or remote URLs. Supports both YAML and JSON formats.
public final class TeamConfigService {

    // MARK: - Singleton

    public static let shared = TeamConfigService()

    // MARK: - Properties

    private let fileManager: FileManager
    private var currentConfig: TeamConfig?
    private var lastSyncTime: Date?
    private var syncTimer: Timer?

    /// Directory for team configuration storage
    private var teamConfigDirectory: URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("team")
    }

    /// Path to the active team configuration file
    private var activeConfigPath: URL {
        teamConfigDirectory.appendingPathComponent("active-config.yaml")
    }

    /// Path to the cached remote configuration
    private var cachedConfigPath: URL {
        teamConfigDirectory.appendingPathComponent("cached-remote.yaml")
    }

    // MARK: - Initialization

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - Public API

    /// Load team configuration from a URL (local file or remote)
    /// - Parameter url: The URL to load configuration from
    /// - Returns: Loaded and validated TeamConfig
    public func loadTeamConfig(from url: URL) async throws -> TeamConfig {
        let data: Data

        if url.isFileURL {
            data = try Data(contentsOf: url)
            AppLogger.shared.info("Loaded team config from local file: \(url.path)")
        } else {
            data = try await fetchRemoteConfig(from: url)
            AppLogger.shared.info("Loaded team config from remote URL: \(url.absoluteString)")
        }

        let config = try parseConfig(from: data, url: url)
        try config.validate()

        return config
    }

    /// Load team configuration from a file path string
    /// - Parameter path: The file path to load configuration from
    /// - Returns: Loaded and validated TeamConfig
    public func loadTeamConfig(fromPath path: String) async throws -> TeamConfig {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        return try await loadTeamConfig(from: url)
    }

    /// Validate a team configuration
    /// - Parameter config: The configuration to validate
    /// - Throws: TeamConfigError if validation fails
    public func validateConfig(_ config: TeamConfig) throws {
        try config.validate()
        AppLogger.shared.info("Team config validation passed for team: \(config.team)")
    }

    /// Apply team configuration as the active configuration
    /// - Parameter config: The configuration to apply
    public func applyConfig(_ config: TeamConfig) throws {
        try config.validate()

        // Ensure directory exists
        try fileManager.createDirectory(
            at: teamConfigDirectory,
            withIntermediateDirectories: true
        )

        // Save as active configuration
        let yamlString = try YAMLEncoder().encode(config)
        try yamlString.write(to: activeConfigPath, atomically: true, encoding: .utf8)

        currentConfig = config
        AppLogger.shared.info("Applied team config for team: \(config.team)")

        // Setup sync if configured
        if let syncConfig = config.sync, syncConfig.intervalSeconds > 0 {
            setupPeriodicSync(interval: TimeInterval(syncConfig.intervalSeconds))
        }
    }

    /// Get the currently active team configuration
    /// - Returns: The active TeamConfig or nil if none is active
    public func getActiveConfig() -> TeamConfig? {
        if let config = currentConfig {
            return config
        }

        // Try to load from disk
        guard fileManager.fileExists(atPath: activeConfigPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: activeConfigPath)
            let config = try parseConfig(from: data, url: activeConfigPath)
            currentConfig = config
            return config
        } catch {
            AppLogger.shared.warning("Failed to load active team config: \(error)")
            return nil
        }
    }

    /// Sync with remote configuration
    /// - Throws: TeamConfigError if sync fails
    public func syncWithRemote() async throws {
        guard let config = currentConfig ?? getActiveConfig(),
              let syncConfig = config.sync,
              let remoteURLString = syncConfig.remoteURL,
              let remoteURL = URL(string: remoteURLString) else {
            throw TeamConfigError.syncFailed("No remote URL configured")
        }

        do {
            let remoteConfig = try await loadTeamConfig(from: remoteURL)

            // Cache the remote config
            let yamlString = try YAMLEncoder().encode(remoteConfig)
            try yamlString.write(to: cachedConfigPath, atomically: true, encoding: .utf8)

            // Apply if newer or different
            try applyConfig(remoteConfig)
            lastSyncTime = Date()

            AppLogger.shared.info("Successfully synced team config from remote")
        } catch {
            AppLogger.shared.error("Failed to sync team config: \(error)")
            throw TeamConfigError.syncFailed(error.localizedDescription)
        }
    }

    /// Remove the active team configuration
    public func removeActiveConfig() throws {
        syncTimer?.invalidate()
        syncTimer = nil

        if fileManager.fileExists(atPath: activeConfigPath.path) {
            try fileManager.removeItem(at: activeConfigPath)
        }

        currentConfig = nil
        AppLogger.shared.info("Removed active team configuration")
    }

    /// Get team configuration status
    /// - Returns: TeamConfigStatus with current state information
    public func getStatus() -> TeamConfigStatus {
        let config = getActiveConfig()

        return TeamConfigStatus(
            isActive: config != nil,
            teamName: config?.team,
            version: config?.version,
            cleanupLevel: config?.policies.cleanupLevel,
            schedule: config?.policies.schedule,
            lastSyncTime: lastSyncTime,
            remoteURL: config?.sync?.remoteURL,
            exclusionsCount: config?.exclusions.count ?? 0
        )
    }

    // MARK: - Configuration Application

    /// Apply team exclusions to a list of paths
    /// - Parameters:
    ///   - paths: Original paths to clean
    ///   - config: Team configuration with exclusions
    /// - Returns: Filtered paths respecting team exclusions
    public func applyExclusions(to paths: [String], using config: TeamConfig) -> [String] {
        let exclusionPatterns = config.exclusions.map { pattern -> String in
            (pattern as NSString).expandingTildeInPath
        }

        return paths.filter { path in
            !exclusionPatterns.contains { pattern in
                matchesGlobPattern(path: path, pattern: pattern)
            }
        }
    }

    /// Create a CleanerConfiguration from team settings
    /// - Parameter config: Team configuration
    /// - Returns: CleanerConfiguration reflecting team policies
    public func createCleanerConfiguration(from config: TeamConfig) -> CleanerConfiguration {
        let level: CleanupLevel
        switch config.policies.cleanupLevel.lowercased() {
        case "light":
            level = .light
        case "deep", "aggressive":
            level = .deep
        case "system":
            level = .system
        default:
            level = .normal
        }

        return CleanerConfiguration(
            cleanupLevel: level,
            dryRun: config.policies.enforceDryRun,
            includeSystemCaches: config.targets.systemCaches?.enabled ?? false,
            includeDeveloperCaches: config.targets.xcode?.derivedData ?? false,
            includeBrowserCaches: config.targets.systemCaches?.browserCaches ?? false,
            includeLogsCaches: config.targets.systemCaches?.logs ?? false
        )
    }

    // MARK: - Private Methods

    private func fetchRemoteConfig(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeamConfigError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TeamConfigError.networkError(
                "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
            )
        }

        return data
    }

    private func parseConfig(from data: Data, url: URL) throws -> TeamConfig {
        let pathExtension = url.pathExtension.lowercased()

        do {
            if pathExtension == "json" {
                return try JSONDecoder().decode(TeamConfig.self, from: data)
            } else {
                // Default to YAML
                guard let yamlString = String(data: data, encoding: .utf8) else {
                    throw TeamConfigError.parseError("Invalid UTF-8 encoding")
                }
                return try YAMLDecoder().decode(TeamConfig.self, from: yamlString)
            }
        } catch let error as DecodingError {
            throw TeamConfigError.parseError(formatDecodingError(error))
        } catch {
            throw TeamConfigError.parseError(error.localizedDescription)
        }
    }

    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Missing value of type \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private func setupPeriodicSync(interval: TimeInterval) {
        syncTimer?.invalidate()

        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.syncWithRemote()
            }
        }
    }

    private func matchesGlobPattern(path: String, pattern: String) -> Bool {
        // Handle simple glob patterns with ** and *
        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*\\*", with: ".*")
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: "[^/]*")
        regexPattern = "^" + regexPattern + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern) else {
            return false
        }

        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}

// MARK: - Status

/// Status information for team configuration
public struct TeamConfigStatus: Sendable {
    public let isActive: Bool
    public let teamName: String?
    public let version: String?
    public let cleanupLevel: String?
    public let schedule: String?
    public let lastSyncTime: Date?
    public let remoteURL: String?
    public let exclusionsCount: Int

    public var formattedLastSync: String {
        guard let lastSyncTime = lastSyncTime else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSyncTime, relativeTo: Date())
    }
}

// MARK: - YAML Generation

extension TeamConfigService {
    /// Generate a sample YAML configuration string
    /// - Returns: Sample configuration in YAML format
    public func generateSampleYAML() throws -> String {
        try YAMLEncoder().encode(TeamConfig.sample)
    }

    /// Export current configuration to YAML
    /// - Returns: Current configuration in YAML format
    public func exportToYAML() throws -> String {
        guard let config = getActiveConfig() else {
            throw TeamConfigError.fileNotFound("No active configuration to export")
        }
        return try YAMLEncoder().encode(config)
    }
}

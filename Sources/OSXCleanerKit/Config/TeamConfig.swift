// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Team configuration for shared cleanup policies across development teams
///
/// Enables centralized management of cleanup policies, exclusions, and target configurations
/// that can be shared across team members through various distribution methods.
public struct TeamConfig: Codable, Sendable {
    /// Configuration schema version
    public let version: String

    /// Team identifier name
    public let team: String

    /// Cleanup policies
    public let policies: TeamPolicies

    /// Global exclusion patterns (glob patterns supported)
    public let exclusions: [String]

    /// Target-specific configurations
    public let targets: TeamTargetConfigs

    /// Notification settings
    public let notifications: TeamNotificationConfig

    /// Optional sync configuration
    public let sync: TeamSyncConfig?

    public init(
        version: String = "1.0",
        team: String,
        policies: TeamPolicies = .default,
        exclusions: [String] = [],
        targets: TeamTargetConfigs = .default,
        notifications: TeamNotificationConfig = .default,
        sync: TeamSyncConfig? = nil
    ) {
        self.version = version
        self.team = team
        self.policies = policies
        self.exclusions = exclusions
        self.targets = targets
        self.notifications = notifications
        self.sync = sync
    }
}

// MARK: - Team Policies

/// Cleanup policy settings for the team
public struct TeamPolicies: Codable, Sendable {
    /// Cleanup level: light, normal, aggressive, or deep
    public let cleanupLevel: String

    /// Schedule: daily, weekly, monthly, or manual
    public let schedule: String

    /// Whether to allow individual overrides
    public let allowOverride: Bool

    /// Maximum disk usage percentage before triggering cleanup
    public let maxDiskUsage: Int

    /// Whether dry-run is enforced (no actual deletion)
    public let enforceDryRun: Bool

    public static let `default` = TeamPolicies(
        cleanupLevel: "normal",
        schedule: "weekly",
        allowOverride: true,
        maxDiskUsage: 90,
        enforceDryRun: false
    )

    public init(
        cleanupLevel: String = "normal",
        schedule: String = "weekly",
        allowOverride: Bool = true,
        maxDiskUsage: Int = 90,
        enforceDryRun: Bool = false
    ) {
        self.cleanupLevel = cleanupLevel
        self.schedule = schedule
        self.allowOverride = allowOverride
        self.maxDiskUsage = maxDiskUsage
        self.enforceDryRun = enforceDryRun
    }

    private enum CodingKeys: String, CodingKey {
        case cleanupLevel = "cleanup_level"
        case schedule
        case allowOverride = "allow_override"
        case maxDiskUsage = "max_disk_usage"
        case enforceDryRun = "enforce_dry_run"
    }
}

// MARK: - Target Configurations

/// Target-specific cleanup configurations
public struct TeamTargetConfigs: Codable, Sendable {
    /// Xcode-related cleanup settings
    public let xcode: XcodeTargetConfig?

    /// Docker cleanup settings
    public let docker: DockerTargetConfig?

    /// Homebrew cleanup settings
    public let homebrew: HomebrewTargetConfig?

    /// Node.js/npm cleanup settings
    public let npm: NpmTargetConfig?

    /// System caches cleanup settings
    public let systemCaches: SystemCachesConfig?

    public static let `default` = TeamTargetConfigs(
        xcode: .default,
        docker: .default,
        homebrew: .default,
        npm: .default,
        systemCaches: .default
    )

    public init(
        xcode: XcodeTargetConfig? = nil,
        docker: DockerTargetConfig? = nil,
        homebrew: HomebrewTargetConfig? = nil,
        npm: NpmTargetConfig? = nil,
        systemCaches: SystemCachesConfig? = nil
    ) {
        self.xcode = xcode
        self.docker = docker
        self.homebrew = homebrew
        self.npm = npm
        self.systemCaches = systemCaches
    }

    private enum CodingKeys: String, CodingKey {
        case xcode
        case docker
        case homebrew
        case npm
        case systemCaches = "system_caches"
    }
}

/// Xcode target configuration
public struct XcodeTargetConfig: Codable, Sendable {
    /// Whether to clean DerivedData
    public let derivedData: Bool

    /// Whether to clean device support files
    public let deviceSupport: Bool

    /// Simulator cleanup mode: none, unavailable, all, or keep_latest
    public let simulators: String

    /// Whether to clean archives
    public let archives: Bool

    public static let `default` = XcodeTargetConfig(
        derivedData: true,
        deviceSupport: false,
        simulators: "unavailable",
        archives: false
    )

    public init(
        derivedData: Bool = true,
        deviceSupport: Bool = false,
        simulators: String = "unavailable",
        archives: Bool = false
    ) {
        self.derivedData = derivedData
        self.deviceSupport = deviceSupport
        self.simulators = simulators
        self.archives = archives
    }

    private enum CodingKeys: String, CodingKey {
        case derivedData = "derived_data"
        case deviceSupport = "device_support"
        case simulators
        case archives
    }
}

/// Docker target configuration
public struct DockerTargetConfig: Codable, Sendable {
    /// Whether Docker cleanup is enabled
    public let enabled: Bool

    /// Whether to keep running containers
    public let keepRunning: Bool

    /// Whether to prune unused images
    public let pruneImages: Bool

    /// Whether to prune build cache
    public let pruneBuildCache: Bool

    public static let `default` = DockerTargetConfig(
        enabled: true,
        keepRunning: true,
        pruneImages: true,
        pruneBuildCache: false
    )

    public init(
        enabled: Bool = true,
        keepRunning: Bool = true,
        pruneImages: Bool = true,
        pruneBuildCache: Bool = false
    ) {
        self.enabled = enabled
        self.keepRunning = keepRunning
        self.pruneImages = pruneImages
        self.pruneBuildCache = pruneBuildCache
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case keepRunning = "keep_running"
        case pruneImages = "prune_images"
        case pruneBuildCache = "prune_build_cache"
    }
}

/// Homebrew target configuration
public struct HomebrewTargetConfig: Codable, Sendable {
    /// Whether Homebrew cleanup is enabled
    public let enabled: Bool

    /// Whether to clean download cache
    public let cleanCache: Bool

    /// Whether to remove old versions
    public let removeOldVersions: Bool

    public static let `default` = HomebrewTargetConfig(
        enabled: true,
        cleanCache: true,
        removeOldVersions: true
    )

    public init(
        enabled: Bool = true,
        cleanCache: Bool = true,
        removeOldVersions: Bool = true
    ) {
        self.enabled = enabled
        self.cleanCache = cleanCache
        self.removeOldVersions = removeOldVersions
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case cleanCache = "clean_cache"
        case removeOldVersions = "remove_old_versions"
    }
}

/// npm target configuration
public struct NpmTargetConfig: Codable, Sendable {
    /// Whether npm cleanup is enabled
    public let enabled: Bool

    /// Whether to clean npm cache
    public let cleanCache: Bool

    /// Whether to find and report orphan node_modules
    public let findOrphanModules: Bool

    public static let `default` = NpmTargetConfig(
        enabled: true,
        cleanCache: true,
        findOrphanModules: true
    )

    public init(
        enabled: Bool = true,
        cleanCache: Bool = true,
        findOrphanModules: Bool = true
    ) {
        self.enabled = enabled
        self.cleanCache = cleanCache
        self.findOrphanModules = findOrphanModules
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case cleanCache = "clean_cache"
        case findOrphanModules = "find_orphan_modules"
    }
}

/// System caches configuration
public struct SystemCachesConfig: Codable, Sendable {
    /// Whether system caches cleanup is enabled
    public let enabled: Bool

    /// Whether to clean user caches
    public let userCaches: Bool

    /// Whether to clean browser caches
    public let browserCaches: Bool

    /// Whether to clean logs
    public let logs: Bool

    public static let `default` = SystemCachesConfig(
        enabled: true,
        userCaches: true,
        browserCaches: false,
        logs: true
    )

    public init(
        enabled: Bool = true,
        userCaches: Bool = true,
        browserCaches: Bool = false,
        logs: Bool = true
    ) {
        self.enabled = enabled
        self.userCaches = userCaches
        self.browserCaches = browserCaches
        self.logs = logs
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case userCaches = "user_caches"
        case browserCaches = "browser_caches"
        case logs
    }
}

// MARK: - Notification Configuration

/// Notification settings for the team
public struct TeamNotificationConfig: Codable, Sendable {
    /// Disk usage percentage threshold for warnings
    public let threshold: Int

    /// Whether to enable auto-cleanup when threshold is exceeded
    public let autoCleanup: Bool

    /// Whether notifications are enabled
    public let enabled: Bool

    public static let `default` = TeamNotificationConfig(
        threshold: 85,
        autoCleanup: false,
        enabled: true
    )

    public init(
        threshold: Int = 85,
        autoCleanup: Bool = false,
        enabled: Bool = true
    ) {
        self.threshold = threshold
        self.autoCleanup = autoCleanup
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case threshold
        case autoCleanup = "auto_cleanup"
        case enabled
    }
}

// MARK: - Sync Configuration

/// Configuration for syncing team settings
public struct TeamSyncConfig: Codable, Sendable {
    /// Source URL for remote configuration
    public let remoteURL: String?

    /// Sync interval in seconds (0 = manual only)
    public let intervalSeconds: Int

    /// Whether to sync on startup
    public let syncOnStartup: Bool

    public static let `default` = TeamSyncConfig(
        remoteURL: nil,
        intervalSeconds: 3600,
        syncOnStartup: true
    )

    public init(
        remoteURL: String? = nil,
        intervalSeconds: Int = 3600,
        syncOnStartup: Bool = true
    ) {
        self.remoteURL = remoteURL
        self.intervalSeconds = intervalSeconds
        self.syncOnStartup = syncOnStartup
    }

    private enum CodingKeys: String, CodingKey {
        case remoteURL = "remote_url"
        case intervalSeconds = "interval_seconds"
        case syncOnStartup = "sync_on_startup"
    }
}

// MARK: - Validation

extension TeamConfig {
    /// Validate the team configuration
    /// - Throws: TeamConfigError if validation fails
    public func validate() throws {
        // Version check
        guard version == "1.0" else {
            throw TeamConfigError.unsupportedVersion(version)
        }

        // Team name check
        guard !team.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TeamConfigError.invalidField("team", reason: "Team name cannot be empty")
        }

        // Cleanup level validation
        let validLevels = ["light", "normal", "aggressive", "deep"]
        guard validLevels.contains(policies.cleanupLevel.lowercased()) else {
            throw TeamConfigError.invalidField(
                "policies.cleanup_level",
                reason: "Must be one of: \(validLevels.joined(separator: ", "))"
            )
        }

        // Schedule validation
        let validSchedules = ["daily", "weekly", "monthly", "manual"]
        guard validSchedules.contains(policies.schedule.lowercased()) else {
            throw TeamConfigError.invalidField(
                "policies.schedule",
                reason: "Must be one of: \(validSchedules.joined(separator: ", "))"
            )
        }

        // Threshold validation
        guard (1...100).contains(notifications.threshold) else {
            throw TeamConfigError.invalidField(
                "notifications.threshold",
                reason: "Must be between 1 and 100"
            )
        }

        // Max disk usage validation
        guard (1...100).contains(policies.maxDiskUsage) else {
            throw TeamConfigError.invalidField(
                "policies.max_disk_usage",
                reason: "Must be between 1 and 100"
            )
        }

        // Simulator mode validation
        if let xcode = targets.xcode {
            let validModes = ["none", "unavailable", "all", "keep_latest"]
            guard validModes.contains(xcode.simulators.lowercased()) else {
                throw TeamConfigError.invalidField(
                    "targets.xcode.simulators",
                    reason: "Must be one of: \(validModes.joined(separator: ", "))"
                )
            }
        }
    }
}

// MARK: - Errors

/// Errors related to team configuration
public enum TeamConfigError: LocalizedError, Equatable {
    case fileNotFound(String)
    case parseError(String)
    case unsupportedVersion(String)
    case invalidField(String, reason: String)
    case networkError(String)
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Team configuration file not found: \(path)"
        case .parseError(let details):
            return "Failed to parse team configuration: \(details)"
        case .unsupportedVersion(let version):
            return "Unsupported team configuration version: \(version)"
        case .invalidField(let field, let reason):
            return "Invalid field '\(field)': \(reason)"
        case .networkError(let details):
            return "Network error while fetching team configuration: \(details)"
        case .syncFailed(let details):
            return "Failed to sync team configuration: \(details)"
        }
    }
}

// MARK: - Sample Configuration

extension TeamConfig {
    /// Sample team configuration for documentation and testing
    public static let sample = TeamConfig(
        version: "1.0",
        team: "iOS Development",
        policies: TeamPolicies(
            cleanupLevel: "normal",
            schedule: "weekly",
            allowOverride: true,
            maxDiskUsage: 90,
            enforceDryRun: false
        ),
        exclusions: [
            "~/Projects/**/build/",
            "~/Library/Developer/Xcode/Archives/"
        ],
        targets: TeamTargetConfigs(
            xcode: XcodeTargetConfig(
                derivedData: true,
                deviceSupport: false,
                simulators: "unavailable",
                archives: false
            ),
            docker: DockerTargetConfig(
                enabled: true,
                keepRunning: true,
                pruneImages: true,
                pruneBuildCache: false
            ),
            homebrew: HomebrewTargetConfig(
                enabled: true,
                cleanCache: true,
                removeOldVersions: true
            ),
            npm: NpmTargetConfig(
                enabled: true,
                cleanCache: true,
                findOrphanModules: true
            ),
            systemCaches: SystemCachesConfig(
                enabled: true,
                userCaches: true,
                browserCaches: false,
                logs: true
            )
        ),
        notifications: TeamNotificationConfig(
            threshold: 85,
            autoCleanup: false,
            enabled: true
        ),
        sync: TeamSyncConfig(
            remoteURL: "https://config.example.com/team/ios-dev/osxcleaner.yaml",
            intervalSeconds: 3600,
            syncOnStartup: true
        )
    )
}

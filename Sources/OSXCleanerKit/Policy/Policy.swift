// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Version of the policy schema
public struct PolicyVersion: Codable, Sendable, Equatable, Comparable {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init?(string: String) {
        let parts = string.split(separator: ".")
        guard parts.count == 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            return nil
        }
        self.major = major
        self.minor = minor
    }

    public var string: String {
        "\(major).\(minor)"
    }

    public static func < (lhs: PolicyVersion, rhs: PolicyVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }

    /// Current schema version
    public static let current = PolicyVersion(major: 1, minor: 0)
}

/// Cleanup target category for policy rules
public enum PolicyTarget: String, Codable, CaseIterable, Sendable {
    /// System caches (/Library/Caches, ~/Library/Caches)
    case systemCaches = "system-caches"

    /// Application caches
    case appCaches = "app-caches"

    /// Developer tool caches (Xcode, CocoaPods, Carthage, etc.)
    case developerCaches = "developer-caches"

    /// Package manager caches (npm, pip, brew, etc.)
    case packageCaches = "package-caches"

    /// Browser caches (Safari, Chrome, Firefox)
    case browserCaches = "browser-caches"

    /// System logs (/var/log, ~/Library/Logs)
    case systemLogs = "system-logs"

    /// Application logs
    case appLogs = "app-logs"

    /// Trash contents
    case trash = "trash"

    /// iOS device backups
    case iosBackups = "ios-backups"

    /// iOS software updates
    case iosSoftwareUpdates = "ios-software-updates"

    /// Mail downloads and attachments
    case mailDownloads = "mail-downloads"

    /// Temporary files
    case tempFiles = "temp-files"

    /// Downloads folder (with age filter)
    case downloads = "downloads"

    /// Localization files (unused languages)
    case localizations = "localizations"

    /// Duplicate files
    case duplicates = "duplicates"

    /// All targets
    case all = "all"
}

/// Action to perform when a rule matches
public enum PolicyAction: String, Codable, Sendable {
    /// Clean (delete) matching items
    case clean

    /// Report only (dry run)
    case report

    /// Move to quarantine folder
    case quarantine

    /// Archive to compressed file
    case archive
}

/// Schedule for policy execution
public enum PolicySchedule: String, Codable, Sendable {
    /// Run daily
    case daily

    /// Run weekly
    case weekly

    /// Run monthly
    case monthly

    /// Run only when manually triggered
    case manual

    /// Run on system startup
    case startup

    /// Run when disk space is low
    case lowDiskSpace = "low-disk-space"
}

/// Priority level for policies
public enum PolicyPriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 50
    case high = 100
    case critical = 200

    public static func < (lhs: PolicyPriority, rhs: PolicyPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Condition for rule execution
public struct PolicyCondition: Codable, Sendable, Equatable {
    /// Minimum age of files to match (e.g., "7d", "30d", "1y")
    public var olderThan: String?

    /// Minimum free disk space to trigger (e.g., "10GB", "50GB")
    public var minFreeSpace: String?

    /// Maximum free disk space - only run if below this (e.g., "100GB")
    public var maxFreeSpace: String?

    /// Minimum file size to match (e.g., "100MB", "1GB")
    public var minFileSize: String?

    /// Maximum file size to match (e.g., "5GB")
    public var maxFileSize: String?

    /// Only run on weekdays
    public var weekdaysOnly: Bool?

    /// Only run between specific hours (24h format)
    public var hourRange: HourRange?

    public init(
        olderThan: String? = nil,
        minFreeSpace: String? = nil,
        maxFreeSpace: String? = nil,
        minFileSize: String? = nil,
        maxFileSize: String? = nil,
        weekdaysOnly: Bool? = nil,
        hourRange: HourRange? = nil
    ) {
        self.olderThan = olderThan
        self.minFreeSpace = minFreeSpace
        self.maxFreeSpace = maxFreeSpace
        self.minFileSize = minFileSize
        self.maxFileSize = maxFileSize
        self.weekdaysOnly = weekdaysOnly
        self.hourRange = hourRange
    }
}

/// Hour range for conditions
public struct HourRange: Codable, Sendable, Equatable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public var isValid: Bool {
        start >= 0 && start <= 23 && end >= 0 && end <= 23
    }
}

/// A single cleanup rule within a policy
public struct PolicyRule: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier for the rule
    public let id: String

    /// Target category to clean
    public let target: PolicyTarget

    /// Action to perform
    public let action: PolicyAction

    /// Execution schedule
    public let schedule: PolicySchedule

    /// Conditions that must be met
    public let conditions: PolicyCondition?

    /// Whether the rule is enabled
    public var enabled: Bool

    /// Human-readable description
    public var description: String?

    public init(
        id: String,
        target: PolicyTarget,
        action: PolicyAction = .clean,
        schedule: PolicySchedule = .manual,
        conditions: PolicyCondition? = nil,
        enabled: Bool = true,
        description: String? = nil
    ) {
        self.id = id
        self.target = target
        self.action = action
        self.schedule = schedule
        self.conditions = conditions
        self.enabled = enabled
        self.description = description
    }
}

/// Policy execution result for a single rule
public struct PolicyRuleResult: Codable, Sendable {
    /// Rule that was executed
    public let ruleId: String

    /// Whether the rule was successful
    public let success: Bool

    /// Number of items processed
    public let itemsProcessed: Int

    /// Bytes freed (if applicable)
    public let bytesFreed: UInt64

    /// Error message if failed
    public let error: String?

    /// Duration of execution
    public let duration: TimeInterval

    /// Timestamp of execution
    public let timestamp: Date

    public init(
        ruleId: String,
        success: Bool,
        itemsProcessed: Int = 0,
        bytesFreed: UInt64 = 0,
        error: String? = nil,
        duration: TimeInterval = 0,
        timestamp: Date = Date()
    ) {
        self.ruleId = ruleId
        self.success = success
        self.itemsProcessed = itemsProcessed
        self.bytesFreed = bytesFreed
        self.error = error
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// Compliance status for a policy
public enum ComplianceStatus: String, Codable, Sendable {
    /// All rules pass
    case compliant

    /// Some rules fail
    case nonCompliant = "non-compliant"

    /// Policy has not been evaluated
    case pending

    /// Evaluation failed
    case error
}

/// A complete cleanup policy
public struct Policy: Codable, Sendable, Identifiable, Equatable {
    /// Schema version
    public let version: String

    /// Unique name/identifier for the policy
    public let name: String

    /// Human-readable display name
    public var displayName: String?

    /// Policy description
    public var description: String?

    /// Cleanup rules
    public var rules: [PolicyRule]

    /// Glob patterns for paths to exclude
    public var exclusions: [String]

    /// Whether to send notifications
    public var notifications: Bool

    /// Policy priority for ordering
    public var priority: PolicyPriority

    /// Whether the policy is enabled
    public var enabled: Bool

    /// Tags for categorization
    public var tags: [String]

    /// Policy metadata
    public var metadata: [String: String]

    /// Creation timestamp
    public let createdAt: Date

    /// Last modification timestamp
    public var updatedAt: Date

    /// Unique identifier (derived from name)
    public var id: String { name }

    public init(
        version: String = PolicyVersion.current.string,
        name: String,
        displayName: String? = nil,
        description: String? = nil,
        rules: [PolicyRule] = [],
        exclusions: [String] = [],
        notifications: Bool = true,
        priority: PolicyPriority = .normal,
        enabled: Bool = true,
        tags: [String] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.name = name
        self.displayName = displayName
        self.description = description
        self.rules = rules
        self.exclusions = exclusions
        self.notifications = notifications
        self.priority = priority
        self.enabled = enabled
        self.tags = tags
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Get enabled rules only
    public var enabledRules: [PolicyRule] {
        rules.filter { $0.enabled }
    }

    /// Get rules for a specific schedule
    public func rules(for schedule: PolicySchedule) -> [PolicyRule] {
        enabledRules.filter { $0.schedule == schedule }
    }
}

// MARK: - Policy Execution Results

/// Result of executing a complete policy
public struct PolicyExecutionResult: Codable, Sendable {
    /// Policy that was executed
    public let policyName: String

    /// Overall success status
    public let success: Bool

    /// Results for each rule
    public let ruleResults: [PolicyRuleResult]

    /// Total bytes freed
    public var totalBytesFreed: UInt64 {
        ruleResults.reduce(0) { $0 + $1.bytesFreed }
    }

    /// Total items processed
    public var totalItemsProcessed: Int {
        ruleResults.reduce(0) { $0 + $1.itemsProcessed }
    }

    /// Total duration
    public var totalDuration: TimeInterval {
        ruleResults.reduce(0) { $0 + $1.duration }
    }

    /// Number of successful rules
    public var successfulRules: Int {
        ruleResults.filter { $0.success }.count
    }

    /// Number of failed rules
    public var failedRules: Int {
        ruleResults.filter { !$0.success }.count
    }

    /// Execution timestamp
    public let executedAt: Date

    public init(
        policyName: String,
        success: Bool,
        ruleResults: [PolicyRuleResult],
        executedAt: Date = Date()
    ) {
        self.policyName = policyName
        self.success = success
        self.ruleResults = ruleResults
        self.executedAt = executedAt
    }

    /// Formatted total freed space
    public var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesFreed), countStyle: .file)
    }
}

// MARK: - Compliance Report

/// Compliance report for a policy
public struct PolicyComplianceReport: Codable, Sendable {
    /// Policy name
    public let policyName: String

    /// Overall compliance status
    public let status: ComplianceStatus

    /// Per-rule compliance status
    public let ruleStatus: [String: ComplianceStatus]

    /// Last check timestamp
    public let checkedAt: Date

    /// Issues found
    public let issues: [String]

    /// Recommendations
    public let recommendations: [String]

    public init(
        policyName: String,
        status: ComplianceStatus,
        ruleStatus: [String: ComplianceStatus] = [:],
        checkedAt: Date = Date(),
        issues: [String] = [],
        recommendations: [String] = []
    ) {
        self.policyName = policyName
        self.status = status
        self.ruleStatus = ruleStatus
        self.checkedAt = checkedAt
        self.issues = issues
        self.recommendations = recommendations
    }
}

// MARK: - Sample Policies

extension Policy {
    /// Default policy for personal use
    public static var personalDefault: Policy {
        Policy(
            name: "personal-default",
            displayName: "Personal Default",
            description: "Default cleanup policy for personal Mac",
            rules: [
                PolicyRule(
                    id: "cache-cleanup",
                    target: .systemCaches,
                    action: .clean,
                    schedule: .weekly,
                    conditions: PolicyCondition(olderThan: "7d"),
                    description: "Clean system caches older than 7 days"
                ),
                PolicyRule(
                    id: "trash-cleanup",
                    target: .trash,
                    action: .clean,
                    schedule: .weekly,
                    conditions: PolicyCondition(olderThan: "30d"),
                    description: "Empty trash items older than 30 days"
                ),
                PolicyRule(
                    id: "browser-cache",
                    target: .browserCaches,
                    action: .clean,
                    schedule: .weekly,
                    description: "Clean browser caches weekly"
                )
            ],
            exclusions: ["~/Documents/*", "~/Desktop/*"],
            notifications: true,
            priority: .normal
        )
    }

    /// Policy for developer machines
    public static var developerStandard: Policy {
        Policy(
            name: "developer-standard",
            displayName: "Developer Standard",
            description: "Cleanup policy for developer machines",
            rules: [
                PolicyRule(
                    id: "xcode-derived-data",
                    target: .developerCaches,
                    action: .clean,
                    schedule: .weekly,
                    conditions: PolicyCondition(olderThan: "14d", minFreeSpace: "50GB"),
                    description: "Clean Xcode DerivedData older than 14 days when disk is low"
                ),
                PolicyRule(
                    id: "package-caches",
                    target: .packageCaches,
                    action: .clean,
                    schedule: .weekly,
                    conditions: PolicyCondition(olderThan: "30d"),
                    description: "Clean npm, pip, brew caches older than 30 days"
                ),
                PolicyRule(
                    id: "ios-simulators",
                    target: .developerCaches,
                    action: .report,
                    schedule: .monthly,
                    description: "Report old iOS simulator data"
                )
            ],
            exclusions: ["~/Projects/*", "~/Developer/*"],
            notifications: true,
            priority: .normal,
            tags: ["developer", "xcode"]
        )
    }

    /// Aggressive cleanup policy for low disk space
    public static var aggressiveCleanup: Policy {
        Policy(
            name: "aggressive-cleanup",
            displayName: "Aggressive Cleanup",
            description: "Aggressive cleanup for critical disk space situations",
            rules: [
                PolicyRule(
                    id: "all-caches",
                    target: .all,
                    action: .clean,
                    schedule: .lowDiskSpace,
                    conditions: PolicyCondition(maxFreeSpace: "10GB"),
                    description: "Clean all caches when disk space is below 10GB"
                ),
                PolicyRule(
                    id: "old-downloads",
                    target: .downloads,
                    action: .quarantine,
                    schedule: .lowDiskSpace,
                    conditions: PolicyCondition(olderThan: "90d", maxFreeSpace: "10GB"),
                    description: "Quarantine downloads older than 90 days"
                )
            ],
            exclusions: [],
            notifications: true,
            priority: .critical,
            tags: ["emergency", "disk-space"]
        )
    }

    /// Enterprise compliance policy
    public static var enterpriseCompliance: Policy {
        Policy(
            name: "enterprise-compliance",
            displayName: "Enterprise Compliance",
            description: "Standard enterprise compliance policy",
            rules: [
                PolicyRule(
                    id: "log-retention",
                    target: .systemLogs,
                    action: .archive,
                    schedule: .monthly,
                    conditions: PolicyCondition(olderThan: "90d"),
                    description: "Archive logs older than 90 days for compliance"
                ),
                PolicyRule(
                    id: "temp-cleanup",
                    target: .tempFiles,
                    action: .clean,
                    schedule: .daily,
                    conditions: PolicyCondition(olderThan: "1d"),
                    description: "Clean temporary files daily"
                ),
                PolicyRule(
                    id: "cache-audit",
                    target: .systemCaches,
                    action: .report,
                    schedule: .weekly,
                    description: "Weekly cache audit report"
                )
            ],
            exclusions: [],
            notifications: true,
            priority: .high,
            tags: ["enterprise", "compliance", "audit"]
        )
    }
}

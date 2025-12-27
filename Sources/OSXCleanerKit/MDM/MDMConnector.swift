// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - MDM Provider

/// Supported MDM platforms
public enum MDMProvider: String, Codable, Sendable, CaseIterable {
    case jamf = "jamf"
    case mosyle = "mosyle"
    case kandji = "kandji"

    public var displayName: String {
        switch self {
        case .jamf: return "Jamf Pro"
        case .mosyle: return "Mosyle"
        case .kandji: return "Kandji"
        }
    }
}

// MARK: - MDM Errors

/// Errors that can occur during MDM operations
public enum MDMError: LocalizedError, Sendable {
    case notConnected
    case authenticationFailed(String)
    case connectionFailed(String)
    case requestFailed(String)
    case invalidConfiguration(String)
    case policyNotFound(String)
    case commandExecutionFailed(String)
    case providerNotSupported(MDMProvider)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to MDM server"
        case .authenticationFailed(let reason):
            return "MDM authentication failed: \(reason)"
        case .connectionFailed(let reason):
            return "MDM connection failed: \(reason)"
        case .requestFailed(let reason):
            return "MDM request failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid MDM configuration: \(reason)"
        case .policyNotFound(let name):
            return "MDM policy not found: \(name)"
        case .commandExecutionFailed(let reason):
            return "MDM command execution failed: \(reason)"
        case .providerNotSupported(let provider):
            return "MDM provider '\(provider.displayName)' is not supported"
        case .invalidResponse(let reason):
            return "Invalid MDM response: \(reason)"
        case .rateLimited(let retryAfter):
            return "MDM rate limited, retry after \(Int(retryAfter)) seconds"
        case .networkUnavailable:
            return "Network is unavailable for MDM communication"
        }
    }
}

// MARK: - MDM Connection State

/// Connection state for MDM
public enum MDMConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case authenticated
    case error
}

// MARK: - MDM Configuration

/// Base configuration for MDM connection
public struct MDMConfiguration: Codable, Sendable {
    /// MDM provider type
    public let provider: MDMProvider

    /// Server URL or base URL
    public let serverURL: URL

    /// Request timeout in seconds
    public let requestTimeout: TimeInterval

    /// Sync interval in seconds
    public let syncInterval: TimeInterval

    /// Whether to auto-sync policies
    public let autoSync: Bool

    /// Whether to report cleanup status automatically
    public let autoReportStatus: Bool

    public init(
        provider: MDMProvider,
        serverURL: URL,
        requestTimeout: TimeInterval = 30,
        syncInterval: TimeInterval = 300,
        autoSync: Bool = true,
        autoReportStatus: Bool = true
    ) {
        self.provider = provider
        self.serverURL = serverURL
        self.requestTimeout = requestTimeout
        self.syncInterval = syncInterval
        self.autoSync = autoSync
        self.autoReportStatus = autoReportStatus
    }
}

// MARK: - MDM Credentials

/// Credentials for MDM authentication
public struct MDMCredentials: Sendable {
    /// Authentication type
    public enum AuthType: String, Codable, Sendable {
        case apiToken
        case oauth2ClientCredentials
        case basicAuth
    }

    public let authType: AuthType

    /// API token (for apiToken auth)
    public let apiToken: String?

    /// Client ID (for OAuth2)
    public let clientId: String?

    /// Client secret (for OAuth2)
    public let clientSecret: String?

    /// Username (for basic auth)
    public let username: String?

    /// Password (for basic auth)
    public let password: String?

    public init(apiToken: String) {
        self.authType = .apiToken
        self.apiToken = apiToken
        self.clientId = nil
        self.clientSecret = nil
        self.username = nil
        self.password = nil
    }

    public init(clientId: String, clientSecret: String) {
        self.authType = .oauth2ClientCredentials
        self.apiToken = nil
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.username = nil
        self.password = nil
    }

    public init(username: String, password: String) {
        self.authType = .basicAuth
        self.apiToken = nil
        self.clientId = nil
        self.clientSecret = nil
        self.username = username
        self.password = password
    }
}

// MARK: - MDM Command

/// Remote command received from MDM
public struct MDMCommand: Codable, Sendable, Identifiable {
    public let id: String
    public let type: CommandType
    public let parameters: [String: String]
    public let priority: CommandPriority
    public let createdAt: Date
    public let expiresAt: Date?

    public enum CommandType: String, Codable, Sendable {
        case cleanup = "cleanup"
        case analyze = "analyze"
        case syncPolicy = "sync_policy"
        case reportStatus = "report_status"
        case reportCompliance = "report_compliance"
        case updateConfig = "update_config"
    }

    public enum CommandPriority: Int, Codable, Sendable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3

        public static func < (lhs: CommandPriority, rhs: CommandPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public init(
        id: String = UUID().uuidString,
        type: CommandType,
        parameters: [String: String] = [:],
        priority: CommandPriority = .normal,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.priority = priority
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - MDM Command Result

/// Result of executing an MDM command
public struct MDMCommandResult: Codable, Sendable {
    public let commandId: String
    public let success: Bool
    public let message: String?
    public let executedAt: Date
    public let duration: TimeInterval
    public let details: [String: String]

    public init(
        commandId: String,
        success: Bool,
        message: String? = nil,
        executedAt: Date = Date(),
        duration: TimeInterval = 0,
        details: [String: String] = [:]
    ) {
        self.commandId = commandId
        self.success = success
        self.message = message
        self.executedAt = executedAt
        self.duration = duration
        self.details = details
    }
}

// MARK: - MDM Cleanup Status

/// Cleanup status to report to MDM
public struct MDMCleanupStatus: Codable, Sendable {
    public let agentId: String
    public let lastCleanupAt: Date?
    public let lastCleanupResult: CleanupResult?
    public let nextScheduledCleanup: Date?
    public let diskFreeSpace: UInt64
    public let diskTotalSpace: UInt64

    public struct CleanupResult: Codable, Sendable {
        public let success: Bool
        public let bytesFreed: UInt64
        public let filesRemoved: Int
        public let duration: TimeInterval
        public let errors: [String]

        public init(
            success: Bool,
            bytesFreed: UInt64,
            filesRemoved: Int,
            duration: TimeInterval,
            errors: [String] = []
        ) {
            self.success = success
            self.bytesFreed = bytesFreed
            self.filesRemoved = filesRemoved
            self.duration = duration
            self.errors = errors
        }
    }

    public init(
        agentId: String,
        lastCleanupAt: Date? = nil,
        lastCleanupResult: CleanupResult? = nil,
        nextScheduledCleanup: Date? = nil,
        diskFreeSpace: UInt64 = 0,
        diskTotalSpace: UInt64 = 0
    ) {
        self.agentId = agentId
        self.lastCleanupAt = lastCleanupAt
        self.lastCleanupResult = lastCleanupResult
        self.nextScheduledCleanup = nextScheduledCleanup
        self.diskFreeSpace = diskFreeSpace
        self.diskTotalSpace = diskTotalSpace
    }
}

// MARK: - MDM Compliance Report

/// Compliance report to send to MDM
public struct MDMComplianceReport: Codable, Sendable {
    public let agentId: String
    public let reportedAt: Date
    public let overallStatus: ComplianceStatus
    public let policyReports: [PolicyComplianceInfo]

    public enum ComplianceStatus: String, Codable, Sendable {
        case compliant
        case nonCompliant
        case unknown
        case error
    }

    public struct PolicyComplianceInfo: Codable, Sendable {
        public let policyId: String
        public let policyName: String
        public let status: ComplianceStatus
        public let lastEvaluatedAt: Date
        public let issues: [String]
        public let recommendations: [String]

        public init(
            policyId: String,
            policyName: String,
            status: ComplianceStatus,
            lastEvaluatedAt: Date = Date(),
            issues: [String] = [],
            recommendations: [String] = []
        ) {
            self.policyId = policyId
            self.policyName = policyName
            self.status = status
            self.lastEvaluatedAt = lastEvaluatedAt
            self.issues = issues
            self.recommendations = recommendations
        }
    }

    public init(
        agentId: String,
        reportedAt: Date = Date(),
        overallStatus: ComplianceStatus,
        policyReports: [PolicyComplianceInfo]
    ) {
        self.agentId = agentId
        self.reportedAt = reportedAt
        self.overallStatus = overallStatus
        self.policyReports = policyReports
    }
}

// MARK: - MDM Policy

/// Cleanup policy from MDM
public struct MDMPolicy: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: Int
    public let enabled: Bool
    public let priority: Int
    public let targets: [String]
    public let schedule: String?
    public let exclusions: [String]
    public let conditions: [String: String]
    public let updatedAt: Date

    public init(
        id: String,
        name: String,
        version: Int = 1,
        enabled: Bool = true,
        priority: Int = 0,
        targets: [String] = [],
        schedule: String? = nil,
        exclusions: [String] = [],
        conditions: [String: String] = [:],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.enabled = enabled
        self.priority = priority
        self.targets = targets
        self.schedule = schedule
        self.exclusions = exclusions
        self.conditions = conditions
        self.updatedAt = updatedAt
    }
}

// MARK: - MDM Connector Protocol

/// Protocol for MDM integration connectors
public protocol MDMConnector: Actor {
    /// The MDM provider this connector supports
    var provider: MDMProvider { get }

    /// Current connection state
    var connectionState: MDMConnectionState { get }

    /// Whether currently connected and authenticated
    var isConnected: Bool { get }

    // MARK: - Connection

    /// Connect to the MDM server
    /// - Parameters:
    ///   - config: MDM configuration
    ///   - credentials: Authentication credentials
    func connect(config: MDMConfiguration, credentials: MDMCredentials) async throws

    /// Disconnect from the MDM server
    func disconnect() async throws

    // MARK: - Policy Management

    /// Sync cleanup policies from MDM
    /// - Returns: Array of MDM policies
    func syncPolicies() async throws -> [MDMPolicy]

    /// Get a specific policy by ID
    /// - Parameter policyId: Policy identifier
    /// - Returns: The requested MDM policy
    func getPolicy(id policyId: String) async throws -> MDMPolicy

    // MARK: - Status Reporting

    /// Report cleanup status to MDM
    /// - Parameter status: Current cleanup status
    func reportStatus(_ status: MDMCleanupStatus) async throws

    /// Report compliance status to MDM
    /// - Parameter report: Compliance report
    func reportCompliance(_ report: MDMComplianceReport) async throws

    // MARK: - Remote Commands

    /// Fetch pending remote commands
    /// - Returns: Array of pending commands
    func fetchCommands() async throws -> [MDMCommand]

    /// Report command execution result
    /// - Parameter result: Command execution result
    func reportCommandResult(_ result: MDMCommandResult) async throws
}

// MARK: - Default Implementation

extension MDMConnector {
    public var isConnected: Bool {
        connectionState == .authenticated || connectionState == .connected
    }
}

// MARK: - MDM Connection Status

/// Status information for MDM connection
public struct MDMConnectionStatus: Codable, Sendable {
    public let provider: MDMProvider?
    public let serverURL: String?
    public let connectionState: MDMConnectionState
    public let isConnected: Bool
    public let lastSyncAt: Date?
    public let policiesCount: Int
    public let pendingCommandsCount: Int

    public init(
        provider: MDMProvider? = nil,
        serverURL: String? = nil,
        connectionState: MDMConnectionState = .disconnected,
        isConnected: Bool = false,
        lastSyncAt: Date? = nil,
        policiesCount: Int = 0,
        pendingCommandsCount: Int = 0
    ) {
        self.provider = provider
        self.serverURL = serverURL
        self.connectionState = connectionState
        self.isConnected = isConnected
        self.lastSyncAt = lastSyncAt
        self.policiesCount = policiesCount
        self.pendingCommandsCount = pendingCommandsCount
    }
}

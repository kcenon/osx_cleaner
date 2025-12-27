// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Protocol version for server-agent communication
public struct ProtocolVersion: Codable, Sendable, Equatable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var string: String {
        "\(major).\(minor).\(patch)"
    }

    public static let current = ProtocolVersion(major: 1, minor: 0, patch: 0)

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Types of messages that can be sent between server and agent
public enum ServerMessageType: String, Codable, Sendable {
    // Agent → Server
    case register
    case heartbeat
    case statusReport
    case policyRequest
    case auditLogUpload

    // Server → Agent
    case registrationResult
    case heartbeatAck
    case policyPush
    case executeCommand
    case configUpdate
}

/// Base message structure for server-agent communication
public struct ServerMessage<Payload: Codable & Sendable>: Codable, Sendable {

    // MARK: - Properties

    /// Unique message identifier
    public let messageId: UUID

    /// Type of the message
    public let type: ServerMessageType

    /// Protocol version used
    public let protocolVersion: ProtocolVersion

    /// Agent ID (sender for agent→server, recipient for server→agent)
    public let agentId: UUID

    /// Message payload
    public let payload: Payload

    /// Timestamp when message was created
    public let timestamp: Date

    /// Optional correlation ID for request-response matching
    public let correlationId: UUID?

    // MARK: - Initialization

    public init(
        messageId: UUID = UUID(),
        type: ServerMessageType,
        agentId: UUID,
        payload: Payload,
        timestamp: Date = Date(),
        correlationId: UUID? = nil
    ) {
        self.messageId = messageId
        self.type = type
        self.protocolVersion = .current
        self.agentId = agentId
        self.payload = payload
        self.timestamp = timestamp
        self.correlationId = correlationId
    }
}

// MARK: - Registration Messages

/// Payload for agent registration request
public struct RegistrationRequest: Codable, Sendable {
    public let identity: AgentIdentity
    public let capabilities: [String]

    public init(identity: AgentIdentity, capabilities: [String] = []) {
        self.identity = identity
        self.capabilities = capabilities
    }

    /// Default capabilities for OSX Cleaner agent
    public static var defaultCapabilities: [String] {
        ["cleanup", "policy-execution", "audit-logging", "disk-monitoring"]
    }
}

/// Result of agent registration
public struct RegistrationResult: Codable, Sendable {
    public let success: Bool
    public let agentId: UUID?
    public let authToken: String?
    public let tokenExpiresAt: Date?
    public let message: String?
    public let serverVersion: String?
    public let heartbeatInterval: TimeInterval

    public init(
        success: Bool,
        agentId: UUID? = nil,
        authToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        message: String? = nil,
        serverVersion: String? = nil,
        heartbeatInterval: TimeInterval = 60
    ) {
        self.success = success
        self.agentId = agentId
        self.authToken = authToken
        self.tokenExpiresAt = tokenExpiresAt
        self.message = message
        self.serverVersion = serverVersion
        self.heartbeatInterval = heartbeatInterval
    }

    public static func success(
        agentId: UUID,
        authToken: String,
        expiresIn: TimeInterval = 86400,
        serverVersion: String
    ) -> RegistrationResult {
        RegistrationResult(
            success: true,
            agentId: agentId,
            authToken: authToken,
            tokenExpiresAt: Date().addingTimeInterval(expiresIn),
            serverVersion: serverVersion
        )
    }

    public static func failure(message: String) -> RegistrationResult {
        RegistrationResult(success: false, message: message)
    }
}

// MARK: - Heartbeat Messages

/// Payload for heartbeat request
public struct HeartbeatRequest: Codable, Sendable {
    public let status: AgentStatus

    public init(status: AgentStatus) {
        self.status = status
    }
}

/// Response to heartbeat request
public struct HeartbeatResponse: Codable, Sendable {
    public let acknowledged: Bool
    public let serverTime: Date
    public let pendingPolicies: Int
    public let pendingCommands: Int
    public let nextHeartbeat: TimeInterval

    public init(
        acknowledged: Bool = true,
        serverTime: Date = Date(),
        pendingPolicies: Int = 0,
        pendingCommands: Int = 0,
        nextHeartbeat: TimeInterval = 60
    ) {
        self.acknowledged = acknowledged
        self.serverTime = serverTime
        self.pendingPolicies = pendingPolicies
        self.pendingCommands = pendingCommands
        self.nextHeartbeat = nextHeartbeat
    }
}

// MARK: - Policy Messages

/// Payload for policy fetch request
public struct PolicyFetchRequest: Codable, Sendable {
    public let lastSyncVersion: Int?
    public let requestedPolicies: [String]?

    public init(lastSyncVersion: Int? = nil, requestedPolicies: [String]? = nil) {
        self.lastSyncVersion = lastSyncVersion
        self.requestedPolicies = requestedPolicies
    }
}

/// Response containing policies
public struct PolicyFetchResponse: Codable, Sendable {
    public let policies: [Policy]
    public let syncVersion: Int
    public let hasMore: Bool

    public init(policies: [Policy], syncVersion: Int, hasMore: Bool = false) {
        self.policies = policies
        self.syncVersion = syncVersion
        self.hasMore = hasMore
    }
}

// MARK: - Command Messages

/// Remote command types
public enum RemoteCommandType: String, Codable, Sendable {
    case runCleanup
    case applyPolicy
    case syncPolicies
    case uploadLogs
    case restart
    case updateConfig
}

/// Remote command to be executed by agent
public struct RemoteCommand: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: RemoteCommandType
    public let parameters: [String: String]
    public let issuedAt: Date
    public let expiresAt: Date?
    public let priority: Int

    public init(
        id: UUID = UUID(),
        type: RemoteCommandType,
        parameters: [String: String] = [:],
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        priority: Int = 0
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.priority = priority
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Result of command execution
public struct CommandResult: Codable, Sendable {
    public let commandId: UUID
    public let success: Bool
    public let message: String?
    public let executedAt: Date
    public let duration: TimeInterval

    public init(
        commandId: UUID,
        success: Bool,
        message: String? = nil,
        executedAt: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.commandId = commandId
        self.success = success
        self.message = message
        self.executedAt = executedAt
        self.duration = duration
    }
}

// MARK: - Generic Response

/// Generic server response wrapper
public struct ServerResponse<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let error: ServerError?
    public let correlationId: UUID?

    public init(success: Bool, data: T? = nil, error: ServerError? = nil, correlationId: UUID? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.correlationId = correlationId
    }

    public static func ok(_ data: T, correlationId: UUID? = nil) -> ServerResponse {
        ServerResponse(success: true, data: data, correlationId: correlationId)
    }

    public static func error(_ error: ServerError, correlationId: UUID? = nil) -> ServerResponse {
        ServerResponse(success: false, error: error, correlationId: correlationId)
    }
}

/// Server error information
public struct ServerError: Codable, Sendable {
    public let code: String
    public let message: String
    public let details: [String: String]?

    public init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }

    public static let unauthorized = ServerError(code: "UNAUTHORIZED", message: "Authentication required")
    public static let forbidden = ServerError(code: "FORBIDDEN", message: "Access denied")
    public static let notFound = ServerError(code: "NOT_FOUND", message: "Resource not found")
    public static let invalidRequest = ServerError(code: "INVALID_REQUEST", message: "Invalid request format")
    public static let serverError = ServerError(code: "SERVER_ERROR", message: "Internal server error")
}

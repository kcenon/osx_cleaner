// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during server communication
public enum ServerCommunicationError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case requestTimeout
    case invalidResponse
    case serverError(ServerError)
    case networkUnavailable
    case notRegistered
    case registrationPending
    case protocolVersionMismatch(server: ProtocolVersion, client: ProtocolVersion)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .requestTimeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let error):
            return "Server error [\(error.code)]: \(error.message)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .notRegistered:
            return "Agent is not registered with the server"
        case .registrationPending:
            return "Agent registration is pending approval"
        case .protocolVersionMismatch(let server, let client):
            return "Protocol version mismatch: server=\(server.string), client=\(client.string)"
        }
    }
}

/// Protocol for management server communication
public protocol ManagementServerProtocol: Sendable {

    /// Server URL
    var serverURL: URL { get }

    /// Current connection state
    var connectionState: AgentConnectionState { get async }

    /// Whether the agent is currently registered
    var isRegistered: Bool { get async }

    // MARK: - Registration

    /// Register the agent with the server
    /// - Parameter identity: Agent identity information
    /// - Returns: Registration result with auth token
    func register(identity: AgentIdentity) async throws -> RegistrationResult

    /// Unregister the agent from the server
    func unregister() async throws

    // MARK: - Heartbeat

    /// Send heartbeat to server
    /// - Parameter status: Current agent status
    /// - Returns: Heartbeat response with pending tasks
    func heartbeat(status: AgentStatus) async throws -> HeartbeatResponse

    // MARK: - Policies

    /// Fetch policies from server
    /// - Parameter lastSyncVersion: Last synced version for incremental updates
    /// - Returns: Policy fetch response
    func fetchPolicies(lastSyncVersion: Int?) async throws -> PolicyFetchResponse

    /// Report policy execution result
    /// - Parameters:
    ///   - policyId: ID of the executed policy
    ///   - result: Execution result
    func reportPolicyExecution(policyId: String, result: PolicyExecutionResult) async throws

    // MARK: - Commands

    /// Fetch pending commands from server
    /// - Returns: Array of pending commands
    func fetchPendingCommands() async throws -> [RemoteCommand]

    /// Report command execution result
    /// - Parameter result: Command execution result
    func reportCommandResult(_ result: CommandResult) async throws

    // MARK: - Audit Logs

    /// Upload audit events to server
    /// - Parameter events: Audit events to upload
    func uploadAuditEvents(_ events: [AuditEvent]) async throws

    // MARK: - Status

    /// Report current status to server
    /// - Parameter status: Current agent status
    func reportStatus(_ status: AgentStatus) async throws
}

// MARK: - Configuration

/// Configuration for server client
public struct ServerClientConfig: Sendable {
    /// Server URL
    public let serverURL: URL

    /// Request timeout in seconds
    public let requestTimeout: TimeInterval

    /// Heartbeat interval in seconds
    public let heartbeatInterval: TimeInterval

    /// Maximum retry attempts for failed requests
    public let maxRetryAttempts: Int

    /// Retry delay in seconds
    public let retryDelay: TimeInterval

    /// Whether to auto-reconnect on disconnection
    public let autoReconnect: Bool

    /// Certificate pinning enabled
    public let certificatePinning: Bool

    public init(
        serverURL: URL,
        requestTimeout: TimeInterval = 30,
        heartbeatInterval: TimeInterval = 60,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 5,
        autoReconnect: Bool = true,
        certificatePinning: Bool = false
    ) {
        self.serverURL = serverURL
        self.requestTimeout = requestTimeout
        self.heartbeatInterval = heartbeatInterval
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.autoReconnect = autoReconnect
        self.certificatePinning = certificatePinning
    }
}

// MARK: - Delegate Protocol

/// Delegate for receiving server events
public protocol ManagementServerDelegate: AnyObject, Sendable {
    /// Called when connection state changes
    func serverConnectionStateChanged(_ state: AgentConnectionState) async

    /// Called when a policy push is received
    func serverDidPushPolicy(_ policy: Policy) async

    /// Called when a remote command is received
    func serverDidSendCommand(_ command: RemoteCommand) async

    /// Called when an error occurs
    func serverDidEncounterError(_ error: ServerCommunicationError) async
}

// MARK: - Default Delegate Implementation

extension ManagementServerDelegate {
    public func serverConnectionStateChanged(_ state: AgentConnectionState) async {}
    public func serverDidPushPolicy(_ policy: Policy) async {}
    public func serverDidSendCommand(_ command: RemoteCommand) async {}
    public func serverDidEncounterError(_ error: ServerCommunicationError) async {}
}

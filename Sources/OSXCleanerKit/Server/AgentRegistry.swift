// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

/// Registered agent with authentication and status information
public struct RegisteredAgent: Codable, Sendable, Identifiable {

    // MARK: - Properties

    /// Agent identity information
    public let identity: AgentIdentity

    /// Authentication token
    public let authToken: String

    /// Token expiration time
    public let tokenExpiresAt: Date

    /// Agent's declared capabilities
    public let capabilities: [String]

    /// Current connection state
    public var connectionState: AgentConnectionState

    /// Latest reported status
    public var latestStatus: AgentStatus?

    /// Timestamp of last heartbeat
    public var lastHeartbeat: Date?

    /// Timestamp of registration
    public let registeredAt: Date

    /// Unique identifier (from identity)
    public var id: UUID { identity.id }

    // MARK: - Initialization

    public init(
        identity: AgentIdentity,
        authToken: String,
        tokenExpiresAt: Date,
        capabilities: [String],
        connectionState: AgentConnectionState = .pending,
        latestStatus: AgentStatus? = nil,
        lastHeartbeat: Date? = nil,
        registeredAt: Date = Date()
    ) {
        self.identity = identity
        self.authToken = authToken
        self.tokenExpiresAt = tokenExpiresAt
        self.capabilities = capabilities
        self.connectionState = connectionState
        self.latestStatus = latestStatus
        self.lastHeartbeat = lastHeartbeat
        self.registeredAt = registeredAt
    }

    // MARK: - Computed Properties

    /// Whether the auth token is expired
    public var isTokenExpired: Bool {
        Date() > tokenExpiresAt
    }

    /// Time since last heartbeat (nil if never received)
    public var timeSinceLastHeartbeat: TimeInterval? {
        guard let lastHeartbeat = lastHeartbeat else { return nil }
        return Date().timeIntervalSince(lastHeartbeat)
    }

    /// Whether the agent is considered online
    public var isOnline: Bool {
        connectionState == .active
    }
}

// MARK: - AgentRegistry

/// Central registry for tracking all connected agents
public actor AgentRegistry {

    // MARK: - Types

    /// Configuration for the registry
    public struct Configuration: Sendable {
        /// Token validity duration in seconds
        public let tokenValidityDuration: TimeInterval

        /// Maximum number of agents
        public let maxAgents: Int

        /// Whether to allow re-registration of existing agents
        public let allowReregistration: Bool

        public init(
            tokenValidityDuration: TimeInterval = 86400,  // 24 hours
            maxAgents: Int = 10000,
            allowReregistration: Bool = true
        ) {
            self.tokenValidityDuration = tokenValidityDuration
            self.maxAgents = maxAgents
            self.allowReregistration = allowReregistration
        }
    }

    /// Errors that can occur in the registry
    public enum RegistryError: LocalizedError {
        case agentNotFound(UUID)
        case agentAlreadyRegistered(UUID)
        case maxAgentsReached
        case invalidToken
        case tokenExpired

        public var errorDescription: String? {
            switch self {
            case .agentNotFound(let id):
                return "Agent not found: \(id)"
            case .agentAlreadyRegistered(let id):
                return "Agent already registered: \(id)"
            case .maxAgentsReached:
                return "Maximum number of agents reached"
            case .invalidToken:
                return "Invalid authentication token"
            case .tokenExpired:
                return "Authentication token has expired"
            }
        }
    }

    // MARK: - Properties

    private var agents: [UUID: RegisteredAgent] = [:]
    private let configuration: Configuration
    private let logger: Logger

    // MARK: - Statistics

    /// Total number of registered agents
    public var agentCount: Int {
        agents.count
    }

    /// Number of active (online) agents
    public var activeAgentCount: Int {
        agents.values.filter { $0.connectionState == .active }.count
    }

    /// Number of offline agents
    public var offlineAgentCount: Int {
        agents.values.filter { $0.connectionState == .offline }.count
    }

    /// Number of pending agents
    public var pendingAgentCount: Int {
        agents.values.filter { $0.connectionState == .pending }.count
    }

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.logger = Logger(label: "com.osxcleaner.agent-registry")
    }

    // MARK: - Registration

    /// Register a new agent
    /// - Parameters:
    ///   - identity: Agent identity
    ///   - capabilities: Agent's capabilities
    /// - Returns: Registration result with auth token
    public func register(
        identity: AgentIdentity,
        capabilities: [String]
    ) throws -> RegisteredAgent {
        // Check max agents
        if agents.count >= configuration.maxAgents {
            logger.warning("Maximum agent limit reached", metadata: [
                "maxAgents": "\(configuration.maxAgents)"
            ])
            throw RegistryError.maxAgentsReached
        }

        // Check for existing registration
        if let existing = agents[identity.id] {
            if configuration.allowReregistration {
                logger.info("Re-registering existing agent", metadata: [
                    "agentId": "\(identity.id)",
                    "hostname": "\(identity.hostname)"
                ])
                // Remove old registration
                agents.removeValue(forKey: identity.id)
            } else {
                throw RegistryError.agentAlreadyRegistered(existing.identity.id)
            }
        }

        // Generate auth token
        let authToken = generateAuthToken()
        let tokenExpiresAt = Date().addingTimeInterval(configuration.tokenValidityDuration)

        // Create registered agent
        let registeredAgent = RegisteredAgent(
            identity: identity,
            authToken: authToken,
            tokenExpiresAt: tokenExpiresAt,
            capabilities: capabilities,
            connectionState: .active,
            lastHeartbeat: Date(),
            registeredAt: Date()
        )

        // Store in registry
        agents[identity.id] = registeredAgent

        logger.info("Agent registered successfully", metadata: [
            "agentId": "\(identity.id)",
            "hostname": "\(identity.hostname)",
            "capabilities": "\(capabilities.joined(separator: ", "))"
        ])

        return registeredAgent
    }

    /// Unregister an agent
    /// - Parameter agentId: Agent ID to unregister
    public func unregister(agentId: UUID) throws {
        guard agents.removeValue(forKey: agentId) != nil else {
            throw RegistryError.agentNotFound(agentId)
        }

        logger.info("Agent unregistered", metadata: [
            "agentId": "\(agentId)"
        ])
    }

    // MARK: - Agent Lookup

    /// Get a registered agent by ID
    public func agent(byId id: UUID) -> RegisteredAgent? {
        agents[id]
    }

    /// Get a registered agent by auth token
    public func agent(byToken token: String) -> RegisteredAgent? {
        agents.values.first { $0.authToken == token }
    }

    /// Get all registered agents
    public func allAgents() -> [RegisteredAgent] {
        Array(agents.values)
    }

    /// Get agents with specific connection state
    public func agents(withState state: AgentConnectionState) -> [RegisteredAgent] {
        agents.values.filter { $0.connectionState == state }
    }

    /// Get agents with specific capability
    public func agents(withCapability capability: String) -> [RegisteredAgent] {
        agents.values.filter { $0.capabilities.contains(capability) }
    }

    /// Get agents matching tags
    public func agents(withTags tags: [String]) -> [RegisteredAgent] {
        agents.values.filter { agent in
            !Set(agent.identity.tags).isDisjoint(with: Set(tags))
        }
    }

    // MARK: - Status Updates

    /// Update agent status after heartbeat
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - status: New status
    public func updateStatus(agentId: UUID, status: AgentStatus) throws {
        guard var agent = agents[agentId] else {
            throw RegistryError.agentNotFound(agentId)
        }

        agent.latestStatus = status
        agent.lastHeartbeat = Date()
        agent.connectionState = .active

        agents[agentId] = agent

        logger.debug("Agent status updated", metadata: [
            "agentId": "\(agentId)",
            "healthStatus": "\(status.healthStatus.rawValue)"
        ])
    }

    /// Update agent connection state
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - state: New connection state
    public func updateConnectionState(agentId: UUID, state: AgentConnectionState) throws {
        guard var agent = agents[agentId] else {
            throw RegistryError.agentNotFound(agentId)
        }

        let previousState = agent.connectionState
        agent.connectionState = state
        agents[agentId] = agent

        logger.info("Agent connection state changed", metadata: [
            "agentId": "\(agentId)",
            "previousState": "\(previousState.rawValue)",
            "newState": "\(state.rawValue)"
        ])
    }

    /// Mark agent as offline
    public func markOffline(agentId: UUID) throws {
        try updateConnectionState(agentId: agentId, state: .offline)
    }

    /// Mark agent as active
    public func markActive(agentId: UUID) throws {
        try updateConnectionState(agentId: agentId, state: .active)
    }

    // MARK: - Token Validation

    /// Validate an auth token
    /// - Parameter token: Token to validate
    /// - Returns: Agent ID if valid
    public func validateToken(_ token: String) throws -> UUID {
        guard let agent = agent(byToken: token) else {
            throw RegistryError.invalidToken
        }

        if agent.isTokenExpired {
            throw RegistryError.tokenExpired
        }

        return agent.identity.id
    }

    /// Refresh an agent's auth token
    /// - Parameter agentId: Agent ID
    /// - Returns: New auth token
    public func refreshToken(agentId: UUID) throws -> String {
        guard var agent = agents[agentId] else {
            throw RegistryError.agentNotFound(agentId)
        }

        let newToken = generateAuthToken()
        let newExpiry = Date().addingTimeInterval(configuration.tokenValidityDuration)

        agent = RegisteredAgent(
            identity: agent.identity,
            authToken: newToken,
            tokenExpiresAt: newExpiry,
            capabilities: agent.capabilities,
            connectionState: agent.connectionState,
            latestStatus: agent.latestStatus,
            lastHeartbeat: agent.lastHeartbeat,
            registeredAt: agent.registeredAt
        )

        agents[agentId] = agent

        logger.info("Token refreshed for agent", metadata: [
            "agentId": "\(agentId)"
        ])

        return newToken
    }

    // MARK: - Cleanup

    /// Remove agents that haven't sent a heartbeat within the timeout
    /// - Parameter timeout: Heartbeat timeout in seconds
    /// - Returns: List of removed agent IDs
    @discardableResult
    public func removeStaleAgents(timeout: TimeInterval) -> [UUID] {
        let now = Date()
        var removedIds: [UUID] = []

        for (id, agent) in agents {
            if let lastHeartbeat = agent.lastHeartbeat {
                if now.timeIntervalSince(lastHeartbeat) > timeout {
                    agents.removeValue(forKey: id)
                    removedIds.append(id)
                }
            } else if now.timeIntervalSince(agent.registeredAt) > timeout {
                // Never received heartbeat
                agents.removeValue(forKey: id)
                removedIds.append(id)
            }
        }

        if !removedIds.isEmpty {
            logger.info("Removed stale agents", metadata: [
                "count": "\(removedIds.count)",
                "timeout": "\(timeout)"
            ])
        }

        return removedIds
    }

    /// Remove all agents
    public func removeAllAgents() {
        let count = agents.count
        agents.removeAll()

        logger.info("Removed all agents", metadata: [
            "count": "\(count)"
        ])
    }

    // MARK: - Private Helpers

    private func generateAuthToken() -> String {
        // Generate a cryptographically secure token
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
}

// MARK: - Registry Statistics

extension AgentRegistry {
    /// Get registry statistics
    public func statistics() -> RegistryStatistics {
        let allAgents = Array(agents.values)

        let healthCounts = Dictionary(
            grouping: allAgents.compactMap { $0.latestStatus?.healthStatus },
            by: { $0 }
        ).mapValues { $0.count }

        return RegistryStatistics(
            totalAgents: allAgents.count,
            activeAgents: allAgents.filter { $0.connectionState == .active }.count,
            offlineAgents: allAgents.filter { $0.connectionState == .offline }.count,
            pendingAgents: allAgents.filter { $0.connectionState == .pending }.count,
            healthyAgents: healthCounts[.healthy] ?? 0,
            warningAgents: healthCounts[.warning] ?? 0,
            criticalAgents: healthCounts[.critical] ?? 0,
            timestamp: Date()
        )
    }
}

/// Statistics for the agent registry
public struct RegistryStatistics: Codable, Sendable {
    public let totalAgents: Int
    public let activeAgents: Int
    public let offlineAgents: Int
    public let pendingAgents: Int
    public let healthyAgents: Int
    public let warningAgents: Int
    public let criticalAgents: Int
    public let timestamp: Date

    public init(
        totalAgents: Int,
        activeAgents: Int,
        offlineAgents: Int,
        pendingAgents: Int,
        healthyAgents: Int,
        warningAgents: Int,
        criticalAgents: Int,
        timestamp: Date
    ) {
        self.totalAgents = totalAgents
        self.activeAgents = activeAgents
        self.offlineAgents = offlineAgents
        self.pendingAgents = pendingAgents
        self.healthyAgents = healthyAgents
        self.warningAgents = warningAgents
        self.criticalAgents = criticalAgents
        self.timestamp = timestamp
    }
}

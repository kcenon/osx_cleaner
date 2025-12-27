// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

// MARK: - Distribution Target

/// Target specification for policy distribution
public enum DistributionTarget: Codable, Sendable, Equatable {
    /// Distribute to all registered agents
    case all

    /// Distribute to specific agents by ID
    case agents([UUID])

    /// Distribute to agents with specific tags
    case tags([String])

    /// Distribute to agents with specific capabilities
    case capabilities([String])

    /// Distribute to agents matching a custom filter
    case filter(DistributionFilter)

    /// Combine multiple targets (union)
    case combined([DistributionTarget])
}

/// Custom filter for agent selection
public struct DistributionFilter: Codable, Sendable, Equatable {
    /// Required tags (agent must have all)
    public var requiredTags: [String]?

    /// Required capabilities (agent must have all)
    public var requiredCapabilities: [String]?

    /// Excluded agent IDs
    public var excludedAgents: [UUID]?

    /// Only include agents with specific connection state
    public var connectionState: AgentConnectionState?

    /// Only include agents registered after this date
    public var registeredAfter: Date?

    /// Maximum number of agents to target
    public var maxAgents: Int?

    public init(
        requiredTags: [String]? = nil,
        requiredCapabilities: [String]? = nil,
        excludedAgents: [UUID]? = nil,
        connectionState: AgentConnectionState? = nil,
        registeredAfter: Date? = nil,
        maxAgents: Int? = nil
    ) {
        self.requiredTags = requiredTags
        self.requiredCapabilities = requiredCapabilities
        self.excludedAgents = excludedAgents
        self.connectionState = connectionState
        self.registeredAfter = registeredAfter
        self.maxAgents = maxAgents
    }
}

// MARK: - Distribution Status

/// Status of a policy distribution
public enum DistributionState: String, Codable, Sendable {
    /// Distribution is queued
    case pending

    /// Distribution is in progress
    case inProgress = "in-progress"

    /// Distribution completed successfully
    case completed

    /// Distribution partially completed (some agents failed)
    case partiallyCompleted = "partially-completed"

    /// Distribution failed
    case failed

    /// Distribution was cancelled
    case cancelled

    /// Distribution is being rolled back
    case rollingBack = "rolling-back"

    /// Rollback completed
    case rolledBack = "rolled-back"
}

/// Status of policy distribution to a single agent
public struct AgentDistributionStatus: Codable, Sendable, Identifiable {
    /// Agent ID
    public let agentId: UUID

    /// Current state
    public var state: DistributionState

    /// Policy version distributed
    public let policyVersion: Int

    /// Timestamp when distribution started
    public let startedAt: Date

    /// Timestamp when distribution completed (or failed)
    public var completedAt: Date?

    /// Number of retry attempts
    public var retryCount: Int

    /// Error message if failed
    public var errorMessage: String?

    /// Whether the agent acknowledged receipt
    public var acknowledged: Bool

    /// Timestamp of acknowledgement
    public var acknowledgedAt: Date?

    /// Unique identifier
    public var id: UUID { agentId }

    public init(
        agentId: UUID,
        state: DistributionState = .pending,
        policyVersion: Int,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        retryCount: Int = 0,
        errorMessage: String? = nil,
        acknowledged: Bool = false,
        acknowledgedAt: Date? = nil
    ) {
        self.agentId = agentId
        self.state = state
        self.policyVersion = policyVersion
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.retryCount = retryCount
        self.errorMessage = errorMessage
        self.acknowledged = acknowledged
        self.acknowledgedAt = acknowledgedAt
    }

    /// Duration of the distribution (nil if not completed)
    public var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
}

/// Overall status of a policy distribution operation
public struct DistributionStatus: Codable, Sendable, Identifiable {
    /// Unique distribution ID
    public let id: UUID

    /// Policy being distributed
    public let policyName: String

    /// Policy version
    public let policyVersion: Int

    /// Target specification
    public let target: DistributionTarget

    /// Overall state
    public var state: DistributionState

    /// Per-agent status
    public var agentStatuses: [UUID: AgentDistributionStatus]

    /// Timestamp when distribution was initiated
    public let initiatedAt: Date

    /// Timestamp when distribution started
    public var startedAt: Date?

    /// Timestamp when distribution completed
    public var completedAt: Date?

    /// User or system that initiated the distribution
    public let initiatedBy: String

    /// Optional message or notes
    public var message: String?

    public init(
        id: UUID = UUID(),
        policyName: String,
        policyVersion: Int,
        target: DistributionTarget,
        state: DistributionState = .pending,
        agentStatuses: [UUID: AgentDistributionStatus] = [:],
        initiatedAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        initiatedBy: String = "system",
        message: String? = nil
    ) {
        self.id = id
        self.policyName = policyName
        self.policyVersion = policyVersion
        self.target = target
        self.state = state
        self.agentStatuses = agentStatuses
        self.initiatedAt = initiatedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.initiatedBy = initiatedBy
        self.message = message
    }

    // MARK: - Computed Properties

    /// Total number of targeted agents
    public var totalAgents: Int {
        agentStatuses.count
    }

    /// Number of agents that completed successfully
    public var successfulAgents: Int {
        agentStatuses.values.filter { $0.state == .completed }.count
    }

    /// Number of agents that failed
    public var failedAgents: Int {
        agentStatuses.values.filter { $0.state == .failed }.count
    }

    /// Number of agents pending
    public var pendingAgents: Int {
        agentStatuses.values.filter { $0.state == .pending }.count
    }

    /// Number of agents in progress
    public var inProgressAgents: Int {
        agentStatuses.values.filter { $0.state == .inProgress }.count
    }

    /// Success rate as a percentage (0-100)
    public var successRate: Double {
        guard totalAgents > 0 else { return 0 }
        return Double(successfulAgents) / Double(totalAgents) * 100
    }

    /// Whether all agents completed successfully
    public var isFullySuccessful: Bool {
        totalAgents > 0 && successfulAgents == totalAgents
    }

    /// Total duration of the distribution
    public var duration: TimeInterval? {
        guard let completedAt = completedAt, let startedAt = startedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Distribution Errors

/// Errors that can occur during policy distribution
public enum PolicyDistributionError: LocalizedError {
    case policyNotFound(String)
    case noTargetAgents
    case distributionNotFound(UUID)
    case distributionAlreadyInProgress(UUID)
    case distributionFailed(String)
    case agentNotReachable(UUID)
    case rollbackFailed(String)
    case invalidTarget(String)
    case maxRetriesExceeded(UUID)

    public var errorDescription: String? {
        switch self {
        case .policyNotFound(let name):
            return "Policy not found: '\(name)'"
        case .noTargetAgents:
            return "No agents match the distribution target"
        case .distributionNotFound(let id):
            return "Distribution not found: \(id)"
        case .distributionAlreadyInProgress(let id):
            return "Distribution already in progress: \(id)"
        case .distributionFailed(let reason):
            return "Distribution failed: \(reason)"
        case .agentNotReachable(let id):
            return "Agent not reachable: \(id)"
        case .rollbackFailed(let reason):
            return "Rollback failed: \(reason)"
        case .invalidTarget(let reason):
            return "Invalid distribution target: \(reason)"
        case .maxRetriesExceeded(let agentId):
            return "Maximum retries exceeded for agent: \(agentId)"
        }
    }
}

// MARK: - Distribution Configuration

/// Configuration for the policy distributor
public struct PolicyDistributorConfig: Sendable {
    /// Maximum concurrent distributions per policy
    public let maxConcurrentDistributions: Int

    /// Maximum retry attempts for failed agent distributions
    public let maxRetryAttempts: Int

    /// Delay between retry attempts in seconds
    public let retryDelay: TimeInterval

    /// Timeout for agent acknowledgement in seconds
    public let acknowledgementTimeout: TimeInterval

    /// Whether to continue distribution if some agents fail
    public let continueOnFailure: Bool

    /// Minimum success rate to consider distribution successful (0-100)
    public let minimumSuccessRate: Double

    /// Whether to automatically rollback on failure
    public let autoRollbackOnFailure: Bool

    public init(
        maxConcurrentDistributions: Int = 10,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 5,
        acknowledgementTimeout: TimeInterval = 30,
        continueOnFailure: Bool = true,
        minimumSuccessRate: Double = 80,
        autoRollbackOnFailure: Bool = false
    ) {
        self.maxConcurrentDistributions = maxConcurrentDistributions
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.acknowledgementTimeout = acknowledgementTimeout
        self.continueOnFailure = continueOnFailure
        self.minimumSuccessRate = minimumSuccessRate
        self.autoRollbackOnFailure = autoRollbackOnFailure
    }
}

// MARK: - Policy Distributor Delegate

/// Delegate protocol for receiving distribution events
public protocol PolicyDistributorDelegate: AnyObject, Sendable {
    /// Called when distribution state changes
    func distributionStateChanged(_ status: DistributionStatus) async

    /// Called when an agent receives a policy
    func agentReceivedPolicy(agentId: UUID, policyName: String, version: Int) async

    /// Called when an agent fails to receive a policy
    func agentFailedToReceivePolicy(agentId: UUID, policyName: String, error: Error) async

    /// Called when distribution completes
    func distributionCompleted(_ status: DistributionStatus) async
}

/// Default implementation for optional delegate methods
extension PolicyDistributorDelegate {
    public func distributionStateChanged(_ status: DistributionStatus) async {}
    public func agentReceivedPolicy(agentId: UUID, policyName: String, version: Int) async {}
    public func agentFailedToReceivePolicy(agentId: UUID, policyName: String, error: Error) async {}
    public func distributionCompleted(_ status: DistributionStatus) async {}
}

// MARK: - Policy Distributor

/// Actor responsible for distributing policies to agents
public actor PolicyDistributor {

    // MARK: - Properties

    private let configuration: PolicyDistributorConfig
    private let registry: AgentRegistry
    private let logger: Logger

    /// Active distributions indexed by ID
    private var distributions: [UUID: DistributionStatus] = [:]

    /// Distribution history (completed/failed)
    private var distributionHistory: [DistributionStatus] = []

    /// Maximum history entries to keep
    private let maxHistoryEntries: Int = 1000

    /// Policy version tracking
    private var policyVersions: [String: Int] = [:]

    /// Weak reference to delegate
    private weak var delegate: (any PolicyDistributorDelegate)?

    // MARK: - Initialization

    public init(
        configuration: PolicyDistributorConfig = PolicyDistributorConfig(),
        registry: AgentRegistry
    ) {
        self.configuration = configuration
        self.registry = registry
        self.logger = Logger(label: "com.osxcleaner.policy-distributor")
    }

    // MARK: - Delegate

    /// Set the delegate for receiving distribution events
    public func setDelegate(_ delegate: (any PolicyDistributorDelegate)?) {
        self.delegate = delegate
    }

    // MARK: - Distribution Operations

    /// Distribute a policy to the specified target
    /// - Parameters:
    ///   - policy: Policy to distribute
    ///   - target: Target agents
    ///   - initiatedBy: User or system initiating the distribution
    /// - Returns: Distribution status
    @discardableResult
    public func distribute(
        policy: Policy,
        to target: DistributionTarget,
        initiatedBy: String = "system"
    ) async throws -> DistributionStatus {
        // Get policy version
        let version = incrementPolicyVersion(for: policy.name)

        logger.info("Starting policy distribution", metadata: [
            "policyName": "\(policy.name)",
            "version": "\(version)",
            "initiatedBy": "\(initiatedBy)"
        ])

        // Resolve target agents
        let targetAgents = try await resolveTargetAgents(target)

        guard !targetAgents.isEmpty else {
            throw PolicyDistributionError.noTargetAgents
        }

        // Create distribution status
        var status = DistributionStatus(
            policyName: policy.name,
            policyVersion: version,
            target: target,
            initiatedBy: initiatedBy
        )

        // Initialize agent statuses
        for agent in targetAgents {
            status.agentStatuses[agent.identity.id] = AgentDistributionStatus(
                agentId: agent.identity.id,
                policyVersion: version
            )
        }

        // Store distribution
        distributions[status.id] = status

        // Start distribution
        status.state = .inProgress
        status.startedAt = Date()
        distributions[status.id] = status

        await delegate?.distributionStateChanged(status)

        // Distribute to each agent
        await distributeToAgents(
            policy: policy,
            version: version,
            distributionId: status.id,
            agents: targetAgents
        )

        // Finalize distribution
        status = try await finalizeDistribution(distributionId: status.id)

        return status
    }

    /// Cancel an in-progress distribution
    public func cancel(distributionId: UUID) async throws {
        guard var status = distributions[distributionId] else {
            throw PolicyDistributionError.distributionNotFound(distributionId)
        }

        guard status.state == .inProgress || status.state == .pending else {
            logger.warning("Cannot cancel distribution in state: \(status.state.rawValue)")
            return
        }

        status.state = .cancelled
        status.completedAt = Date()

        // Mark pending agents as cancelled
        for (agentId, var agentStatus) in status.agentStatuses {
            if agentStatus.state == .pending || agentStatus.state == .inProgress {
                agentStatus.state = .cancelled
                agentStatus.completedAt = Date()
                status.agentStatuses[agentId] = agentStatus
            }
        }

        distributions[distributionId] = status
        archiveDistribution(status)

        logger.info("Distribution cancelled", metadata: [
            "distributionId": "\(distributionId)"
        ])

        await delegate?.distributionStateChanged(status)
    }

    /// Rollback a completed distribution
    public func rollback(distributionId: UUID) async throws {
        guard var status = distributions[distributionId] else {
            // Check history
            guard let historicalStatus = distributionHistory.first(where: { $0.id == distributionId }) else {
                throw PolicyDistributionError.distributionNotFound(distributionId)
            }
            // Cannot rollback from history for now
            throw PolicyDistributionError.rollbackFailed("Cannot rollback archived distribution")
        }

        guard status.state == .completed || status.state == .partiallyCompleted else {
            throw PolicyDistributionError.rollbackFailed("Can only rollback completed distributions")
        }

        status.state = .rollingBack
        distributions[distributionId] = status

        await delegate?.distributionStateChanged(status)

        logger.info("Starting rollback", metadata: [
            "distributionId": "\(distributionId)",
            "policyName": "\(status.policyName)"
        ])

        // Rollback logic would notify agents to revert to previous policy version
        // For now, we mark as rolled back
        status.state = .rolledBack
        status.completedAt = Date()
        distributions[distributionId] = status

        archiveDistribution(status)

        await delegate?.distributionStateChanged(status)
    }

    /// Retry failed agent distributions
    public func retryFailed(distributionId: UUID) async throws -> DistributionStatus {
        guard var status = distributions[distributionId] else {
            throw PolicyDistributionError.distributionNotFound(distributionId)
        }

        let failedAgentIds = status.agentStatuses.values
            .filter { $0.state == .failed }
            .map { $0.agentId }

        guard !failedAgentIds.isEmpty else {
            logger.info("No failed agents to retry")
            return status
        }

        logger.info("Retrying failed agents", metadata: [
            "distributionId": "\(distributionId)",
            "failedCount": "\(failedAgentIds.count)"
        ])

        // Reset failed agents to pending
        for agentId in failedAgentIds {
            if var agentStatus = status.agentStatuses[agentId] {
                agentStatus.state = .pending
                agentStatus.retryCount += 1
                agentStatus.errorMessage = nil
                status.agentStatuses[agentId] = agentStatus
            }
        }

        status.state = .inProgress
        distributions[distributionId] = status

        // Get agents from registry
        let agents = await failedAgentIds.asyncCompactMap { await registry.agent(byId: $0) }

        // Retry distribution
        // Note: We would need the original policy here
        // For now, this is a placeholder
        logger.warning("Retry implementation requires policy storage - using placeholder")

        return status
    }

    // MARK: - Query Methods

    /// Get a distribution by ID
    public func distribution(byId id: UUID) -> DistributionStatus? {
        distributions[id] ?? distributionHistory.first { $0.id == id }
    }

    /// Get all active distributions
    public func activeDistributions() -> [DistributionStatus] {
        Array(distributions.values.filter { $0.state == .inProgress || $0.state == .pending })
    }

    /// Get distributions for a specific policy
    public func distributions(forPolicy policyName: String) -> [DistributionStatus] {
        let active = distributions.values.filter { $0.policyName == policyName }
        let historical = distributionHistory.filter { $0.policyName == policyName }
        return Array(active) + historical
    }

    /// Get distribution history
    public func history(limit: Int = 100) -> [DistributionStatus] {
        Array(distributionHistory.prefix(limit))
    }

    /// Get the current version of a policy
    public func policyVersion(for policyName: String) -> Int {
        policyVersions[policyName] ?? 0
    }

    // MARK: - Acknowledgement

    /// Record that an agent acknowledged receipt of a policy
    public func acknowledge(
        agentId: UUID,
        distributionId: UUID
    ) async throws {
        guard var status = distributions[distributionId] else {
            throw PolicyDistributionError.distributionNotFound(distributionId)
        }

        guard var agentStatus = status.agentStatuses[agentId] else {
            logger.warning("Agent not found in distribution", metadata: [
                "agentId": "\(agentId)",
                "distributionId": "\(distributionId)"
            ])
            return
        }

        agentStatus.acknowledged = true
        agentStatus.acknowledgedAt = Date()
        agentStatus.state = .completed
        agentStatus.completedAt = Date()

        status.agentStatuses[agentId] = agentStatus
        distributions[distributionId] = status

        logger.debug("Agent acknowledged policy", metadata: [
            "agentId": "\(agentId)",
            "distributionId": "\(distributionId)"
        ])

        await delegate?.agentReceivedPolicy(
            agentId: agentId,
            policyName: status.policyName,
            version: status.policyVersion
        )

        // Check if distribution is complete
        await checkDistributionCompletion(distributionId: distributionId)
    }

    // MARK: - Private Methods

    private func incrementPolicyVersion(for policyName: String) -> Int {
        let currentVersion = policyVersions[policyName] ?? 0
        let newVersion = currentVersion + 1
        policyVersions[policyName] = newVersion
        return newVersion
    }

    private func resolveTargetAgents(_ target: DistributionTarget) async throws -> [RegisteredAgent] {
        switch target {
        case .all:
            return await registry.allAgents()

        case .agents(let ids):
            return await ids.asyncCompactMap { await registry.agent(byId: $0) }

        case .tags(let tags):
            return await registry.agents(withTags: tags)

        case .capabilities(let capabilities):
            var result: [RegisteredAgent] = []
            for capability in capabilities {
                let agents = await registry.agents(withCapability: capability)
                result.append(contentsOf: agents)
            }
            // Remove duplicates
            return Array(Set(result.map { $0.identity.id }))
                .compactMap { id in result.first { $0.identity.id == id } }

        case .filter(let filter):
            return try await applyFilter(filter)

        case .combined(let targets):
            var allAgents: [RegisteredAgent] = []
            for subTarget in targets {
                let agents = try await resolveTargetAgents(subTarget)
                allAgents.append(contentsOf: agents)
            }
            // Remove duplicates
            return Array(Set(allAgents.map { $0.identity.id }))
                .compactMap { id in allAgents.first { $0.identity.id == id } }
        }
    }

    private func applyFilter(_ filter: DistributionFilter) async throws -> [RegisteredAgent] {
        var agents = await registry.allAgents()

        // Apply connection state filter
        if let state = filter.connectionState {
            agents = agents.filter { $0.connectionState == state }
        }

        // Apply required tags filter
        if let requiredTags = filter.requiredTags, !requiredTags.isEmpty {
            agents = agents.filter { agent in
                Set(requiredTags).isSubset(of: Set(agent.identity.tags))
            }
        }

        // Apply required capabilities filter
        if let requiredCapabilities = filter.requiredCapabilities, !requiredCapabilities.isEmpty {
            agents = agents.filter { agent in
                Set(requiredCapabilities).isSubset(of: Set(agent.capabilities))
            }
        }

        // Apply exclusion filter
        if let excludedAgents = filter.excludedAgents, !excludedAgents.isEmpty {
            let excludedSet = Set(excludedAgents)
            agents = agents.filter { !excludedSet.contains($0.identity.id) }
        }

        // Apply registration date filter
        if let registeredAfter = filter.registeredAfter {
            agents = agents.filter { $0.registeredAt > registeredAfter }
        }

        // Apply max agents limit
        if let maxAgents = filter.maxAgents, agents.count > maxAgents {
            agents = Array(agents.prefix(maxAgents))
        }

        return agents
    }

    private func distributeToAgents(
        policy: Policy,
        version: Int,
        distributionId: UUID,
        agents: [RegisteredAgent]
    ) async {
        // Process agents in batches for concurrency control
        let batchSize = configuration.maxConcurrentDistributions

        for batch in agents.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for agent in batch {
                    group.addTask {
                        await self.distributeToAgent(
                            policy: policy,
                            version: version,
                            distributionId: distributionId,
                            agent: agent
                        )
                    }
                }
            }
        }
    }

    private func distributeToAgent(
        policy: Policy,
        version: Int,
        distributionId: UUID,
        agent: RegisteredAgent
    ) async {
        guard var status = distributions[distributionId],
              var agentStatus = status.agentStatuses[agent.identity.id] else {
            return
        }

        agentStatus.state = .inProgress
        status.agentStatuses[agent.identity.id] = agentStatus
        distributions[distributionId] = status

        // Simulate distribution (in real implementation, would send via network)
        do {
            // Check if agent is reachable
            guard agent.connectionState == .active else {
                throw PolicyDistributionError.agentNotReachable(agent.identity.id)
            }

            // In real implementation, would send policy to agent via heartbeat response
            // or direct push notification
            logger.debug("Distributing policy to agent", metadata: [
                "agentId": "\(agent.identity.id)",
                "policyName": "\(policy.name)",
                "version": "\(version)"
            ])

            // Mark as waiting for acknowledgement
            // Agent will call acknowledge() when it receives the policy
            agentStatus.state = .inProgress

        } catch {
            agentStatus.state = .failed
            agentStatus.errorMessage = error.localizedDescription
            agentStatus.completedAt = Date()

            logger.warning("Failed to distribute to agent", metadata: [
                "agentId": "\(agent.identity.id)",
                "error": "\(error.localizedDescription)"
            ])

            await delegate?.agentFailedToReceivePolicy(
                agentId: agent.identity.id,
                policyName: policy.name,
                error: error
            )
        }

        // Update status
        if var currentStatus = distributions[distributionId] {
            currentStatus.agentStatuses[agent.identity.id] = agentStatus
            distributions[distributionId] = currentStatus
        }
    }

    private func checkDistributionCompletion(distributionId: UUID) async {
        guard var status = distributions[distributionId] else { return }

        let pending = status.pendingAgents
        let inProgress = status.inProgressAgents

        // Distribution is complete when no agents are pending or in progress
        guard pending == 0 && inProgress == 0 else { return }

        // Determine final state
        if status.isFullySuccessful {
            status.state = .completed
        } else if status.successRate >= configuration.minimumSuccessRate {
            status.state = .partiallyCompleted
        } else {
            status.state = .failed
        }

        status.completedAt = Date()
        distributions[distributionId] = status

        logger.info("Distribution completed", metadata: [
            "distributionId": "\(distributionId)",
            "state": "\(status.state.rawValue)",
            "successRate": "\(String(format: "%.1f", status.successRate))%"
        ])

        archiveDistribution(status)
        await delegate?.distributionCompleted(status)
    }

    private func finalizeDistribution(distributionId: UUID) async throws -> DistributionStatus {
        guard let status = distributions[distributionId] else {
            throw PolicyDistributionError.distributionNotFound(distributionId)
        }

        // Wait for acknowledgement timeout for in-progress agents
        try await Task.sleep(nanoseconds: UInt64(configuration.acknowledgementTimeout * 1_000_000_000))

        // Mark any still in-progress agents as failed
        var updatedStatus = status
        for (agentId, var agentStatus) in updatedStatus.agentStatuses {
            if agentStatus.state == .inProgress {
                agentStatus.state = .failed
                agentStatus.errorMessage = "Acknowledgement timeout"
                agentStatus.completedAt = Date()
                updatedStatus.agentStatuses[agentId] = agentStatus
            }
        }

        // Update final state
        if updatedStatus.isFullySuccessful {
            updatedStatus.state = .completed
        } else if updatedStatus.successRate >= configuration.minimumSuccessRate {
            updatedStatus.state = .partiallyCompleted
        } else {
            updatedStatus.state = .failed
        }

        updatedStatus.completedAt = Date()
        distributions[distributionId] = updatedStatus

        archiveDistribution(updatedStatus)
        await delegate?.distributionCompleted(updatedStatus)

        return updatedStatus
    }

    private func archiveDistribution(_ status: DistributionStatus) {
        distributions.removeValue(forKey: status.id)
        distributionHistory.insert(status, at: 0)

        // Trim history
        if distributionHistory.count > maxHistoryEntries {
            distributionHistory = Array(distributionHistory.prefix(maxHistoryEntries))
        }
    }
}

// MARK: - Array Extension

extension Array {
    /// Split array into chunks of specified size
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Async Sequence Helpers

extension Sequence {
    /// Async map that preserves order
    fileprivate func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }

    /// Async compactMap that preserves order
    fileprivate func asyncCompactMap<T>(_ transform: (Element) async -> T?) async -> [T] {
        var results: [T] = []
        for element in self {
            if let result = await transform(element) {
                results.append(result)
            }
        }
        return results
    }
}

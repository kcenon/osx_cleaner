// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

/// Delegate for heartbeat monitor events
public protocol HeartbeatMonitorDelegate: AnyObject, Sendable {
    /// Called when an agent's heartbeat is received
    func heartbeatReceived(agentId: UUID, status: AgentStatus) async

    /// Called when an agent goes offline (missed heartbeats)
    func agentWentOffline(agentId: UUID, lastHeartbeat: Date?) async

    /// Called when an offline agent comes back online
    func agentCameOnline(agentId: UUID) async

    /// Called when an agent's health status changes
    func healthStatusChanged(agentId: UUID, from: AgentHealthStatus, to: AgentHealthStatus) async
}

// MARK: - Default Implementation

extension HeartbeatMonitorDelegate {
    public func heartbeatReceived(agentId: UUID, status: AgentStatus) async {}
    public func agentWentOffline(agentId: UUID, lastHeartbeat: Date?) async {}
    public func agentCameOnline(agentId: UUID) async {}
    public func healthStatusChanged(agentId: UUID, from: AgentHealthStatus, to: AgentHealthStatus) async {}
}

/// Service for monitoring agent heartbeats and detecting offline agents
public actor HeartbeatMonitor {

    // MARK: - Types

    /// Configuration for heartbeat monitoring
    public struct Configuration: Sendable {
        /// Expected heartbeat interval from agents
        public let expectedHeartbeatInterval: TimeInterval

        /// How many missed heartbeats before marking offline
        public let missedHeartbeatsThreshold: Int

        /// How often to check for offline agents
        public let checkInterval: TimeInterval

        /// Whether to automatically remove stale agents
        public let autoRemoveStaleAgents: Bool

        /// How long before an offline agent is removed (if autoRemove is true)
        public let staleAgentTimeout: TimeInterval

        /// Computed offline threshold
        public var offlineThreshold: TimeInterval {
            expectedHeartbeatInterval * Double(missedHeartbeatsThreshold)
        }

        public init(
            expectedHeartbeatInterval: TimeInterval = 60,
            missedHeartbeatsThreshold: Int = 3,
            checkInterval: TimeInterval = 30,
            autoRemoveStaleAgents: Bool = false,
            staleAgentTimeout: TimeInterval = 86400  // 24 hours
        ) {
            self.expectedHeartbeatInterval = expectedHeartbeatInterval
            self.missedHeartbeatsThreshold = missedHeartbeatsThreshold
            self.checkInterval = checkInterval
            self.autoRemoveStaleAgents = autoRemoveStaleAgents
            self.staleAgentTimeout = staleAgentTimeout
        }
    }

    /// Heartbeat statistics for an agent
    public struct AgentHeartbeatStats: Sendable {
        public let agentId: UUID
        public let totalHeartbeats: Int
        public let lastHeartbeat: Date?
        public let averageInterval: TimeInterval
        public let missedHeartbeats: Int

        public init(
            agentId: UUID,
            totalHeartbeats: Int,
            lastHeartbeat: Date?,
            averageInterval: TimeInterval,
            missedHeartbeats: Int
        ) {
            self.agentId = agentId
            self.totalHeartbeats = totalHeartbeats
            self.lastHeartbeat = lastHeartbeat
            self.averageInterval = averageInterval
            self.missedHeartbeats = missedHeartbeats
        }
    }

    // MARK: - Properties

    private let registry: AgentRegistry
    private let configuration: Configuration
    private let logger: Logger
    private weak var delegate: HeartbeatMonitorDelegate?

    /// Monitoring task
    private var monitoringTask: Task<Void, Never>?

    /// Whether monitoring is active
    private var _isMonitoring: Bool = false
    public var isMonitoring: Bool { _isMonitoring }

    /// Heartbeat history for statistics
    private var heartbeatHistory: [UUID: [Date]] = [:]
    private let maxHistorySize = 100

    /// Last known health status for change detection
    private var lastHealthStatus: [UUID: AgentHealthStatus] = [:]

    // MARK: - Initialization

    public init(
        registry: AgentRegistry,
        configuration: Configuration = Configuration(),
        delegate: HeartbeatMonitorDelegate? = nil
    ) {
        self.registry = registry
        self.configuration = configuration
        self.delegate = delegate
        self.logger = Logger(label: "com.osxcleaner.heartbeat-monitor")
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Heartbeat Processing

    /// Process a heartbeat from an agent
    /// - Parameters:
    ///   - agentId: Agent ID
    ///   - status: Agent status
    /// - Returns: Heartbeat response
    public func processHeartbeat(
        agentId: UUID,
        status: AgentStatus
    ) async throws -> HeartbeatResponse {
        // Validate agent exists
        guard let agent = await registry.agent(byId: agentId) else {
            throw AgentRegistry.RegistryError.agentNotFound(agentId)
        }

        let wasOffline = agent.connectionState == .offline
        let previousHealth = lastHealthStatus[agentId]

        // Update registry with new status
        try await registry.updateStatus(agentId: agentId, status: status)

        // Record heartbeat in history
        recordHeartbeat(agentId: agentId)

        // Check for health status change
        if let previousHealth = previousHealth, previousHealth != status.healthStatus {
            await delegate?.healthStatusChanged(
                agentId: agentId,
                from: previousHealth,
                to: status.healthStatus
            )
        }
        lastHealthStatus[agentId] = status.healthStatus

        // Notify delegate
        await delegate?.heartbeatReceived(agentId: agentId, status: status)

        // Check if agent was offline and is now back
        if wasOffline {
            logger.info("Agent came back online", metadata: [
                "agentId": "\(agentId)"
            ])
            await delegate?.agentCameOnline(agentId: agentId)
        }

        // Calculate pending items (would typically come from a queue/database)
        let response = HeartbeatResponse(
            acknowledged: true,
            serverTime: Date(),
            pendingPolicies: 0,
            pendingCommands: 0,
            nextHeartbeat: configuration.expectedHeartbeatInterval
        )

        return response
    }

    // MARK: - Monitoring Control

    /// Start background monitoring
    public func startMonitoring() {
        guard !_isMonitoring else {
            logger.debug("Monitoring already active")
            return
        }

        _isMonitoring = true

        monitoringTask = Task {
            await monitoringLoop()
        }

        logger.info("Heartbeat monitoring started", metadata: [
            "checkInterval": "\(configuration.checkInterval)",
            "offlineThreshold": "\(configuration.offlineThreshold)"
        ])
    }

    /// Stop background monitoring
    public func stopMonitoring() {
        guard _isMonitoring else { return }

        _isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil

        logger.info("Heartbeat monitoring stopped")
    }

    /// Run a single monitoring check
    public func checkNow() async {
        await performMonitoringCheck()
    }

    // MARK: - Statistics

    /// Get heartbeat statistics for an agent
    public func stats(for agentId: UUID) async -> AgentHeartbeatStats? {
        guard let agent = await registry.agent(byId: agentId) else {
            return nil
        }

        let history = heartbeatHistory[agentId] ?? []
        let averageInterval = calculateAverageInterval(history)
        let missedHeartbeats = calculateMissedHeartbeats(
            lastHeartbeat: agent.lastHeartbeat,
            expectedInterval: configuration.expectedHeartbeatInterval
        )

        return AgentHeartbeatStats(
            agentId: agentId,
            totalHeartbeats: history.count,
            lastHeartbeat: agent.lastHeartbeat,
            averageInterval: averageInterval,
            missedHeartbeats: missedHeartbeats
        )
    }

    /// Get statistics for all agents
    public func allStats() async -> [AgentHeartbeatStats] {
        let agents = await registry.allAgents()
        var stats: [AgentHeartbeatStats] = []

        for agent in agents {
            if let agentStats = await self.stats(for: agent.identity.id) {
                stats.append(agentStats)
            }
        }

        return stats
    }

    /// Get agents that are close to going offline
    public func agentsAtRisk() async -> [RegisteredAgent] {
        let agents = await registry.allAgents()
        let warningThreshold = configuration.expectedHeartbeatInterval * Double(configuration.missedHeartbeatsThreshold - 1)
        let now = Date()

        return agents.filter { agent in
            guard agent.connectionState == .active,
                  let lastHeartbeat = agent.lastHeartbeat else {
                return false
            }
            let elapsed = now.timeIntervalSince(lastHeartbeat)
            return elapsed > warningThreshold && elapsed < configuration.offlineThreshold
        }
    }

    // MARK: - Private Methods

    private func monitoringLoop() async {
        while _isMonitoring && !Task.isCancelled {
            await performMonitoringCheck()

            // Sleep for check interval
            do {
                try await Task.sleep(nanoseconds: UInt64(configuration.checkInterval * 1_000_000_000))
            } catch {
                // Task was cancelled
                break
            }
        }
    }

    private func performMonitoringCheck() async {
        let agents = await registry.allAgents()
        let now = Date()
        var offlineCount = 0
        var removedCount = 0

        for agent in agents where agent.connectionState == .active {
            guard let lastHeartbeat = agent.lastHeartbeat else {
                continue
            }

            let elapsed = now.timeIntervalSince(lastHeartbeat)

            // Check for offline
            if elapsed > configuration.offlineThreshold {
                do {
                    try await registry.markOffline(agentId: agent.identity.id)
                    offlineCount += 1

                    logger.warning("Agent marked offline due to missed heartbeats", metadata: [
                        "agentId": "\(agent.identity.id)",
                        "hostname": "\(agent.identity.hostname)",
                        "lastHeartbeat": "\(lastHeartbeat)",
                        "elapsed": "\(elapsed)"
                    ])

                    await delegate?.agentWentOffline(
                        agentId: agent.identity.id,
                        lastHeartbeat: lastHeartbeat
                    )
                } catch {
                    logger.error("Failed to mark agent offline", metadata: [
                        "agentId": "\(agent.identity.id)",
                        "error": "\(error.localizedDescription)"
                    ])
                }
            }
        }

        // Auto-remove stale agents if configured
        if configuration.autoRemoveStaleAgents {
            let removed = await registry.removeStaleAgents(timeout: configuration.staleAgentTimeout)
            removedCount = removed.count

            // Clean up local state for removed agents
            for agentId in removed {
                heartbeatHistory.removeValue(forKey: agentId)
                lastHealthStatus.removeValue(forKey: agentId)
            }
        }

        if offlineCount > 0 || removedCount > 0 {
            logger.info("Monitoring check completed", metadata: [
                "agentsChecked": "\(agents.count)",
                "markedOffline": "\(offlineCount)",
                "removed": "\(removedCount)"
            ])
        }
    }

    private func recordHeartbeat(agentId: UUID) {
        var history = heartbeatHistory[agentId] ?? []
        history.append(Date())

        // Trim history if too large
        if history.count > maxHistorySize {
            history = Array(history.suffix(maxHistorySize))
        }

        heartbeatHistory[agentId] = history
    }

    private func calculateAverageInterval(_ history: [Date]) -> TimeInterval {
        guard history.count >= 2 else { return 0 }

        var totalInterval: TimeInterval = 0
        for i in 1..<history.count {
            totalInterval += history[i].timeIntervalSince(history[i - 1])
        }

        return totalInterval / Double(history.count - 1)
    }

    private func calculateMissedHeartbeats(
        lastHeartbeat: Date?,
        expectedInterval: TimeInterval
    ) -> Int {
        guard let lastHeartbeat = lastHeartbeat else { return 0 }

        let elapsed = Date().timeIntervalSince(lastHeartbeat)
        let expectedCount = Int(elapsed / expectedInterval)

        return max(0, expectedCount - 1)
    }
}

// MARK: - Convenience Extensions

extension HeartbeatMonitor {
    /// Get summary of current monitoring state
    public func summary() async -> MonitoringSummary {
        let stats = await registry.statistics()
        let atRisk = await agentsAtRisk()

        return MonitoringSummary(
            isMonitoring: _isMonitoring,
            totalAgents: stats.totalAgents,
            activeAgents: stats.activeAgents,
            offlineAgents: stats.offlineAgents,
            atRiskAgents: atRisk.count,
            configuration: configuration
        )
    }
}

/// Summary of monitoring state
public struct MonitoringSummary: Sendable {
    public let isMonitoring: Bool
    public let totalAgents: Int
    public let activeAgents: Int
    public let offlineAgents: Int
    public let atRiskAgents: Int
    public let configuration: HeartbeatMonitor.Configuration

    public init(
        isMonitoring: Bool,
        totalAgents: Int,
        activeAgents: Int,
        offlineAgents: Int,
        atRiskAgents: Int,
        configuration: HeartbeatMonitor.Configuration
    ) {
        self.isMonitoring = isMonitoring
        self.totalAgents = totalAgents
        self.activeAgents = activeAgents
        self.offlineAgents = offlineAgents
        self.atRiskAgents = atRiskAgents
        self.configuration = configuration
    }
}

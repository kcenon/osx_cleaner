// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Connection state of an agent
public enum AgentConnectionState: String, Codable, Sendable, CaseIterable {
    /// Agent is pending registration approval
    case pending

    /// Agent is registered and active
    case active

    /// Agent is registered but currently offline
    case offline

    /// Agent has been disconnected by administrator
    case disconnected

    /// Agent registration was rejected
    case rejected
}

/// Health status of an agent
public enum AgentHealthStatus: String, Codable, Sendable, CaseIterable {
    /// Agent is healthy and operating normally
    case healthy

    /// Agent has warnings (e.g., low disk space)
    case warning

    /// Agent has critical issues
    case critical

    /// Health status unknown (no recent heartbeat)
    case unknown
}

/// Current status of a managed agent
public struct AgentStatus: Codable, Sendable {

    // MARK: - Properties

    /// Agent identifier
    public let agentId: UUID

    /// Current connection state
    public let connectionState: AgentConnectionState

    /// Current health status
    public let healthStatus: AgentHealthStatus

    /// Timestamp of last successful heartbeat
    public let lastHeartbeat: Date?

    /// Timestamp of last policy sync
    public let lastPolicySync: Date?

    /// Number of active policies on the agent
    public let activePolicyCount: Int

    /// Total disk space in bytes
    public let totalDiskSpace: UInt64

    /// Available disk space in bytes
    public let availableDiskSpace: UInt64

    /// Total bytes freed by cleanup operations
    public let totalFreedBytes: UInt64

    /// Number of cleanup operations performed
    public let cleanupCount: Int

    /// Current CPU usage percentage (0-100)
    public let cpuUsage: Double?

    /// Current memory usage percentage (0-100)
    public let memoryUsage: Double?

    /// Optional error message if agent has issues
    public let errorMessage: String?

    /// Timestamp when this status was captured
    public let capturedAt: Date

    // MARK: - Initialization

    public init(
        agentId: UUID,
        connectionState: AgentConnectionState = .pending,
        healthStatus: AgentHealthStatus = .unknown,
        lastHeartbeat: Date? = nil,
        lastPolicySync: Date? = nil,
        activePolicyCount: Int = 0,
        totalDiskSpace: UInt64 = 0,
        availableDiskSpace: UInt64 = 0,
        totalFreedBytes: UInt64 = 0,
        cleanupCount: Int = 0,
        cpuUsage: Double? = nil,
        memoryUsage: Double? = nil,
        errorMessage: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.agentId = agentId
        self.connectionState = connectionState
        self.healthStatus = healthStatus
        self.lastHeartbeat = lastHeartbeat
        self.lastPolicySync = lastPolicySync
        self.activePolicyCount = activePolicyCount
        self.totalDiskSpace = totalDiskSpace
        self.availableDiskSpace = availableDiskSpace
        self.totalFreedBytes = totalFreedBytes
        self.cleanupCount = cleanupCount
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.errorMessage = errorMessage
        self.capturedAt = capturedAt
    }

    // MARK: - Factory Methods

    /// Create status from current system state
    public static func current(
        agentId: UUID,
        connectionState: AgentConnectionState,
        activePolicyCount: Int = 0,
        totalFreedBytes: UInt64 = 0,
        cleanupCount: Int = 0
    ) -> AgentStatus {
        let diskInfo = getDiskInfo()
        let healthStatus = determineHealth(availableSpace: diskInfo.available, total: diskInfo.total)

        return AgentStatus(
            agentId: agentId,
            connectionState: connectionState,
            healthStatus: healthStatus,
            lastHeartbeat: Date(),
            activePolicyCount: activePolicyCount,
            totalDiskSpace: diskInfo.total,
            availableDiskSpace: diskInfo.available,
            totalFreedBytes: totalFreedBytes,
            cleanupCount: cleanupCount
        )
    }

    // MARK: - Computed Properties

    /// Disk usage percentage (0-100)
    public var diskUsagePercent: Double {
        guard totalDiskSpace > 0 else { return 0 }
        let used = totalDiskSpace - availableDiskSpace
        return Double(used) / Double(totalDiskSpace) * 100
    }

    /// Formatted available disk space
    public var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableDiskSpace), countStyle: .file)
    }

    /// Formatted total freed bytes
    public var formattedFreedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalFreedBytes), countStyle: .file)
    }

    /// Whether the agent is considered online
    public var isOnline: Bool {
        connectionState == .active
    }

    /// Time since last heartbeat
    public var timeSinceLastHeartbeat: TimeInterval? {
        guard let lastHeartbeat = lastHeartbeat else { return nil }
        return Date().timeIntervalSince(lastHeartbeat)
    }

    // MARK: - Private Helpers

    private static func getDiskInfo() -> (total: UInt64, available: UInt64) {
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            return (total, available)
        } catch {
            return (0, 0)
        }
    }

    private static func determineHealth(availableSpace: UInt64, total: UInt64) -> AgentHealthStatus {
        guard total > 0 else { return .unknown }

        let availablePercent = Double(availableSpace) / Double(total) * 100

        if availablePercent < 5 {
            return .critical
        } else if availablePercent < 15 {
            return .warning
        } else {
            return .healthy
        }
    }
}

// MARK: - Equatable

extension AgentStatus: Equatable {
    public static func == (lhs: AgentStatus, rhs: AgentStatus) -> Bool {
        lhs.agentId == rhs.agentId && lhs.capturedAt == rhs.capturedAt
    }
}

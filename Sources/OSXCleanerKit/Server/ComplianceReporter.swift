// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

// MARK: - Compliance Score

/// Compliance score for an agent
public struct ComplianceScore: Codable, Sendable {

    // MARK: - Properties

    /// Agent identifier
    public let agentId: UUID

    /// Overall compliance score (0-100)
    public let overallScore: Double

    /// Policy compliance score (0-100)
    public let policyScore: Double

    /// Health compliance score (0-100)
    public let healthScore: Double

    /// Connectivity compliance score (0-100)
    public let connectivityScore: Double

    /// Number of active policies
    public let activePolicies: Int

    /// Number of policies with issues
    public let policiesWithIssues: Int

    /// Time since last heartbeat in seconds
    public let timeSinceLastHeartbeat: TimeInterval?

    /// Timestamp when score was calculated
    public let calculatedAt: Date

    // MARK: - Initialization

    public init(
        agentId: UUID,
        overallScore: Double,
        policyScore: Double,
        healthScore: Double,
        connectivityScore: Double,
        activePolicies: Int = 0,
        policiesWithIssues: Int = 0,
        timeSinceLastHeartbeat: TimeInterval? = nil,
        calculatedAt: Date = Date()
    ) {
        self.agentId = agentId
        self.overallScore = max(0, min(100, overallScore))
        self.policyScore = max(0, min(100, policyScore))
        self.healthScore = max(0, min(100, healthScore))
        self.connectivityScore = max(0, min(100, connectivityScore))
        self.activePolicies = activePolicies
        self.policiesWithIssues = policiesWithIssues
        self.timeSinceLastHeartbeat = timeSinceLastHeartbeat
        self.calculatedAt = calculatedAt
    }

    // MARK: - Computed Properties

    /// Compliance level based on overall score
    public var complianceLevel: ComplianceLevel {
        ComplianceLevel.from(score: overallScore)
    }

    /// Whether the agent is fully compliant
    public var isCompliant: Bool {
        overallScore >= 80
    }
}

// MARK: - Compliance Level

/// Compliance level categories
public enum ComplianceLevel: String, Codable, Sendable, CaseIterable {
    /// Fully compliant (90-100)
    case compliant

    /// Mostly compliant with minor issues (70-89)
    case partiallyCompliant = "partially-compliant"

    /// Non-compliant with significant issues (50-69)
    case nonCompliant = "non-compliant"

    /// Critical non-compliance (0-49)
    case critical

    /// Determine compliance level from score
    public static func from(score: Double) -> ComplianceLevel {
        switch score {
        case 90...100:
            return .compliant
        case 70..<90:
            return .partiallyCompliant
        case 50..<70:
            return .nonCompliant
        default:
            return .critical
        }
    }
}

// MARK: - Report Types

/// Type of compliance report
public enum ReportType: String, Codable, Sendable, CaseIterable {
    /// Fleet-wide overview report
    case fleetOverview = "fleet-overview"

    /// Individual agent compliance report
    case agentCompliance = "agent-compliance"

    /// Policy execution report
    case policyExecution = "policy-execution"

    /// Audit log summary report
    case auditLogSummary = "audit-log-summary"
}

/// Export format for reports
public enum ReportExportFormat: String, Codable, Sendable {
    case json
    case csv
}

// MARK: - Fleet Overview Report

/// Fleet-wide compliance overview
public struct FleetOverviewReport: Codable, Sendable {

    // MARK: - Properties

    /// Report identifier
    public let id: UUID

    /// Report type
    public let reportType: ReportType = .fleetOverview

    /// Total number of agents
    public let totalAgents: Int

    /// Number of active agents
    public let activeAgents: Int

    /// Number of offline agents
    public let offlineAgents: Int

    /// Average compliance score across fleet
    public let averageComplianceScore: Double

    /// Number of compliant agents
    public let compliantAgents: Int

    /// Number of non-compliant agents
    public let nonCompliantAgents: Int

    /// Number of critical agents
    public let criticalAgents: Int

    /// Total policies deployed
    public let totalPoliciesDeployed: Int

    /// Successful policy deployments
    public let successfulDeployments: Int

    /// Failed policy deployments
    public let failedDeployments: Int

    /// Total bytes freed by cleanup operations
    public let totalBytesFreed: UInt64

    /// Total cleanup operations performed
    public let totalCleanupOperations: Int

    /// Breakdown by compliance level
    public let complianceLevelBreakdown: [ComplianceLevel: Int]

    /// Report generation timestamp
    public let generatedAt: Date

    /// Time period covered (start)
    public let periodStart: Date?

    /// Time period covered (end)
    public let periodEnd: Date?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        totalAgents: Int,
        activeAgents: Int,
        offlineAgents: Int,
        averageComplianceScore: Double,
        compliantAgents: Int,
        nonCompliantAgents: Int,
        criticalAgents: Int,
        totalPoliciesDeployed: Int,
        successfulDeployments: Int,
        failedDeployments: Int,
        totalBytesFreed: UInt64,
        totalCleanupOperations: Int,
        complianceLevelBreakdown: [ComplianceLevel: Int],
        generatedAt: Date = Date(),
        periodStart: Date? = nil,
        periodEnd: Date? = nil
    ) {
        self.id = id
        self.totalAgents = totalAgents
        self.activeAgents = activeAgents
        self.offlineAgents = offlineAgents
        self.averageComplianceScore = averageComplianceScore
        self.compliantAgents = compliantAgents
        self.nonCompliantAgents = nonCompliantAgents
        self.criticalAgents = criticalAgents
        self.totalPoliciesDeployed = totalPoliciesDeployed
        self.successfulDeployments = successfulDeployments
        self.failedDeployments = failedDeployments
        self.totalBytesFreed = totalBytesFreed
        self.totalCleanupOperations = totalCleanupOperations
        self.complianceLevelBreakdown = complianceLevelBreakdown
        self.generatedAt = generatedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    // MARK: - Computed Properties

    /// Fleet compliance rate percentage
    public var complianceRate: Double {
        guard totalAgents > 0 else { return 0 }
        return Double(compliantAgents) / Double(totalAgents) * 100
    }

    /// Policy deployment success rate percentage
    public var deploymentSuccessRate: Double {
        guard totalPoliciesDeployed > 0 else { return 0 }
        return Double(successfulDeployments) / Double(totalPoliciesDeployed) * 100
    }

    /// Formatted total bytes freed
    public var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesFreed), countStyle: .file)
    }
}

// MARK: - Agent Compliance Report

/// Detailed compliance report for a single agent
public struct AgentComplianceReport: Codable, Sendable {

    // MARK: - Properties

    /// Report identifier
    public let id: UUID

    /// Report type
    public let reportType: ReportType = .agentCompliance

    /// Agent identifier
    public let agentId: UUID

    /// Agent hostname
    public let hostname: String

    /// Agent tags
    public let tags: [String]

    /// Current compliance score
    public let complianceScore: ComplianceScore

    /// Current connection state
    public let connectionState: AgentConnectionState

    /// Current health status
    public let healthStatus: AgentHealthStatus

    /// Active policies on this agent
    public let activePolicies: [String]

    /// Policy execution history
    public let policyHistory: [PolicyExecutionRecord]

    /// Cleanup statistics
    public let cleanupStats: AgentCleanupStats

    /// Report generation timestamp
    public let generatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        agentId: UUID,
        hostname: String,
        tags: [String] = [],
        complianceScore: ComplianceScore,
        connectionState: AgentConnectionState,
        healthStatus: AgentHealthStatus,
        activePolicies: [String] = [],
        policyHistory: [PolicyExecutionRecord] = [],
        cleanupStats: AgentCleanupStats,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.hostname = hostname
        self.tags = tags
        self.complianceScore = complianceScore
        self.connectionState = connectionState
        self.healthStatus = healthStatus
        self.activePolicies = activePolicies
        self.policyHistory = policyHistory
        self.cleanupStats = cleanupStats
        self.generatedAt = generatedAt
    }
}

/// Record of a policy execution
public struct PolicyExecutionRecord: Codable, Sendable {
    /// Policy name
    public let policyName: String

    /// Policy version
    public let version: Int

    /// Execution status
    public let status: PolicyExecutionStatus

    /// Execution timestamp
    public let executedAt: Date

    /// Error message if failed
    public let errorMessage: String?

    public init(
        policyName: String,
        version: Int,
        status: PolicyExecutionStatus,
        executedAt: Date,
        errorMessage: String? = nil
    ) {
        self.policyName = policyName
        self.version = version
        self.status = status
        self.executedAt = executedAt
        self.errorMessage = errorMessage
    }
}

/// Status of policy execution
public enum PolicyExecutionStatus: String, Codable, Sendable {
    case pending
    case executing
    case completed
    case failed
    case skipped
}

/// Agent cleanup operation statistics for compliance reporting
public struct AgentCleanupStats: Codable, Sendable {
    /// Total bytes freed
    public let totalBytesFreed: UInt64

    /// Number of cleanup operations
    public let operationCount: Int

    /// Last cleanup timestamp
    public let lastCleanupAt: Date?

    /// Average bytes freed per operation
    public var averageBytesPerOperation: UInt64 {
        guard operationCount > 0 else { return 0 }
        return totalBytesFreed / UInt64(operationCount)
    }

    public init(
        totalBytesFreed: UInt64 = 0,
        operationCount: Int = 0,
        lastCleanupAt: Date? = nil
    ) {
        self.totalBytesFreed = totalBytesFreed
        self.operationCount = operationCount
        self.lastCleanupAt = lastCleanupAt
    }
}

// MARK: - Policy Execution Report

/// Report on policy execution across the fleet
public struct PolicyExecutionReport: Codable, Sendable {

    // MARK: - Properties

    /// Report identifier
    public let id: UUID

    /// Report type
    public let reportType: ReportType = .policyExecution

    /// Policy name
    public let policyName: String

    /// Policy version
    public let version: Int

    /// Total agents targeted
    public let totalTargetedAgents: Int

    /// Successful executions
    public let successfulExecutions: Int

    /// Failed executions
    public let failedExecutions: Int

    /// Pending executions
    public let pendingExecutions: Int

    /// Per-agent execution status
    public let agentStatuses: [AgentPolicyStatus]

    /// Distribution started at
    public let distributionStartedAt: Date

    /// Distribution completed at
    public let distributionCompletedAt: Date?

    /// Report generation timestamp
    public let generatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        policyName: String,
        version: Int,
        totalTargetedAgents: Int,
        successfulExecutions: Int,
        failedExecutions: Int,
        pendingExecutions: Int,
        agentStatuses: [AgentPolicyStatus] = [],
        distributionStartedAt: Date,
        distributionCompletedAt: Date? = nil,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.policyName = policyName
        self.version = version
        self.totalTargetedAgents = totalTargetedAgents
        self.successfulExecutions = successfulExecutions
        self.failedExecutions = failedExecutions
        self.pendingExecutions = pendingExecutions
        self.agentStatuses = agentStatuses
        self.distributionStartedAt = distributionStartedAt
        self.distributionCompletedAt = distributionCompletedAt
        self.generatedAt = generatedAt
    }

    // MARK: - Computed Properties

    /// Execution success rate percentage
    public var successRate: Double {
        guard totalTargetedAgents > 0 else { return 0 }
        return Double(successfulExecutions) / Double(totalTargetedAgents) * 100
    }

    /// Distribution duration
    public var distributionDuration: TimeInterval? {
        guard let completed = distributionCompletedAt else { return nil }
        return completed.timeIntervalSince(distributionStartedAt)
    }
}

/// Policy status for a single agent
public struct AgentPolicyStatus: Codable, Sendable {
    /// Agent identifier
    public let agentId: UUID

    /// Agent hostname
    public let hostname: String

    /// Execution status
    public let status: PolicyExecutionStatus

    /// Error message if failed
    public let errorMessage: String?

    /// Execution timestamp
    public let executedAt: Date?

    public init(
        agentId: UUID,
        hostname: String,
        status: PolicyExecutionStatus,
        errorMessage: String? = nil,
        executedAt: Date? = nil
    ) {
        self.agentId = agentId
        self.hostname = hostname
        self.status = status
        self.errorMessage = errorMessage
        self.executedAt = executedAt
    }
}

// MARK: - Audit Log Summary

/// Summary of audit logs
public struct AuditLogSummary: Codable, Sendable {

    // MARK: - Properties

    /// Report identifier
    public let id: UUID

    /// Report type
    public let reportType: ReportType = .auditLogSummary

    /// Total log entries
    public let totalEntries: Int

    /// Entries by severity
    public let entriesBySeverity: [AuditSeverity: Int]

    /// Entries by category
    public let entriesByCategory: [String: Int]

    /// Top agents by log volume
    public let topAgentsByVolume: [AgentLogVolume]

    /// Recent critical entries
    public let recentCriticalEntries: [AuditLogEntry]

    /// Time period start
    public let periodStart: Date

    /// Time period end
    public let periodEnd: Date

    /// Report generation timestamp
    public let generatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        totalEntries: Int,
        entriesBySeverity: [AuditSeverity: Int],
        entriesByCategory: [String: Int],
        topAgentsByVolume: [AgentLogVolume] = [],
        recentCriticalEntries: [AuditLogEntry] = [],
        periodStart: Date,
        periodEnd: Date,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.totalEntries = totalEntries
        self.entriesBySeverity = entriesBySeverity
        self.entriesByCategory = entriesByCategory
        self.topAgentsByVolume = topAgentsByVolume
        self.recentCriticalEntries = recentCriticalEntries
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
    }
}

/// Audit log severity levels
public enum AuditSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error
    case critical
}

/// Agent log volume entry
public struct AgentLogVolume: Codable, Sendable {
    /// Agent identifier
    public let agentId: UUID

    /// Agent hostname
    public let hostname: String

    /// Number of log entries
    public let entryCount: Int

    public init(agentId: UUID, hostname: String, entryCount: Int) {
        self.agentId = agentId
        self.hostname = hostname
        self.entryCount = entryCount
    }
}

/// Audit log entry
public struct AuditLogEntry: Codable, Sendable {
    /// Entry identifier
    public let id: UUID

    /// Agent identifier
    public let agentId: UUID

    /// Severity level
    public let severity: AuditSeverity

    /// Category
    public let category: String

    /// Message
    public let message: String

    /// Timestamp
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        agentId: UUID,
        severity: AuditSeverity,
        category: String,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.severity = severity
        self.category = category
        self.message = message
        self.timestamp = timestamp
    }
}

// MARK: - Compliance Reporter Errors

/// Errors that can occur during report generation
public enum ComplianceReportError: LocalizedError {
    case noAgentsFound
    case agentNotFound(UUID)
    case policyNotFound(String)
    case distributionNotFound(UUID)
    case invalidDateRange
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noAgentsFound:
            return "No agents found for report generation"
        case .agentNotFound(let id):
            return "Agent not found: \(id)"
        case .policyNotFound(let name):
            return "Policy not found: \(name)"
        case .distributionNotFound(let id):
            return "Distribution not found: \(id)"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}

// MARK: - Compliance Reporter Configuration

/// Configuration for the compliance reporter
public struct ComplianceReporterConfig: Sendable {
    /// Score weight for policy compliance
    public let policyWeight: Double

    /// Score weight for health compliance
    public let healthWeight: Double

    /// Score weight for connectivity compliance
    public let connectivityWeight: Double

    /// Heartbeat timeout for connectivity score calculation (seconds)
    public let heartbeatTimeout: TimeInterval

    /// Maximum audit log entries to include in summary
    public let maxAuditLogEntries: Int

    public init(
        policyWeight: Double = 0.4,
        healthWeight: Double = 0.3,
        connectivityWeight: Double = 0.3,
        heartbeatTimeout: TimeInterval = 300,
        maxAuditLogEntries: Int = 100
    ) {
        self.policyWeight = policyWeight
        self.healthWeight = healthWeight
        self.connectivityWeight = connectivityWeight
        self.heartbeatTimeout = heartbeatTimeout
        self.maxAuditLogEntries = maxAuditLogEntries
    }
}

// MARK: - Compliance Reporter

/// Actor responsible for generating compliance reports
public actor ComplianceReporter {

    // MARK: - Properties

    private let configuration: ComplianceReporterConfig
    private let registry: AgentRegistry
    private let distributor: PolicyDistributor
    private let logger: Logger

    /// Cached compliance scores
    private var complianceScores: [UUID: ComplianceScore] = [:]

    /// Audit log entries (in production, would be stored in database)
    private var auditLogs: [AuditLogEntry] = []

    /// Maximum audit log entries to store in memory
    private let maxStoredAuditLogs: Int = 10000

    // MARK: - Initialization

    public init(
        configuration: ComplianceReporterConfig = ComplianceReporterConfig(),
        registry: AgentRegistry,
        distributor: PolicyDistributor
    ) {
        self.configuration = configuration
        self.registry = registry
        self.distributor = distributor
        self.logger = Logger(label: "com.osxcleaner.compliance-reporter")
    }

    // MARK: - Score Calculation

    /// Calculate compliance score for an agent
    public func calculateScore(for agentId: UUID) async throws -> ComplianceScore {
        guard let agent = await registry.agent(byId: agentId) else {
            throw ComplianceReportError.agentNotFound(agentId)
        }

        let policyScore = calculatePolicyScore(for: agent)
        let healthScore = calculateHealthScore(for: agent)
        let connectivityScore = calculateConnectivityScore(for: agent)

        let overallScore = (
            policyScore * configuration.policyWeight +
            healthScore * configuration.healthWeight +
            connectivityScore * configuration.connectivityWeight
        )

        let score = ComplianceScore(
            agentId: agentId,
            overallScore: overallScore,
            policyScore: policyScore,
            healthScore: healthScore,
            connectivityScore: connectivityScore,
            activePolicies: agent.latestStatus?.activePolicyCount ?? 0,
            policiesWithIssues: 0,
            timeSinceLastHeartbeat: agent.timeSinceLastHeartbeat
        )

        complianceScores[agentId] = score

        logger.debug("Calculated compliance score", metadata: [
            "agentId": "\(agentId)",
            "overallScore": "\(String(format: "%.1f", overallScore))"
        ])

        return score
    }

    /// Calculate compliance scores for all agents
    public func calculateAllScores() async throws -> [ComplianceScore] {
        let agents = await registry.allAgents()

        guard !agents.isEmpty else {
            throw ComplianceReportError.noAgentsFound
        }

        var scores: [ComplianceScore] = []
        for agent in agents {
            let score = try await calculateScore(for: agent.identity.id)
            scores.append(score)
        }

        logger.info("Calculated compliance scores for fleet", metadata: [
            "agentCount": "\(scores.count)",
            "averageScore": "\(String(format: "%.1f", scores.map(\.overallScore).reduce(0, +) / Double(scores.count)))"
        ])

        return scores
    }

    /// Get cached compliance score for an agent
    public func cachedScore(for agentId: UUID) -> ComplianceScore? {
        complianceScores[agentId]
    }

    // MARK: - Report Generation

    /// Generate a fleet overview report
    public func generateFleetOverview(
        periodStart: Date? = nil,
        periodEnd: Date? = nil
    ) async throws -> FleetOverviewReport {
        let scores = try await calculateAllScores()
        let agents = await registry.allAgents()

        var complianceLevelBreakdown: [ComplianceLevel: Int] = [:]
        for level in ComplianceLevel.allCases {
            complianceLevelBreakdown[level] = 0
        }
        for score in scores {
            complianceLevelBreakdown[score.complianceLevel, default: 0] += 1
        }

        let compliantCount = scores.filter { $0.overallScore >= 90 }.count
        let nonCompliantCount = scores.filter { $0.overallScore >= 50 && $0.overallScore < 70 }.count
        let criticalCount = scores.filter { $0.overallScore < 50 }.count

        let averageScore = scores.isEmpty ? 0.0 : scores.map(\.overallScore).reduce(0, +) / Double(scores.count)

        let totalBytesFreed = agents.compactMap { $0.latestStatus?.totalFreedBytes }.reduce(0, +)
        let totalCleanups = agents.compactMap { $0.latestStatus?.cleanupCount }.reduce(0, +)

        let distributions = await distributor.history(limit: 100)
        let successfulDeployments = distributions.filter { $0.state == .completed }.count

        let report = FleetOverviewReport(
            totalAgents: agents.count,
            activeAgents: await registry.activeAgentCount,
            offlineAgents: await registry.offlineAgentCount,
            averageComplianceScore: averageScore,
            compliantAgents: compliantCount,
            nonCompliantAgents: nonCompliantCount,
            criticalAgents: criticalCount,
            totalPoliciesDeployed: distributions.count,
            successfulDeployments: successfulDeployments,
            failedDeployments: distributions.filter { $0.state == .failed }.count,
            totalBytesFreed: totalBytesFreed,
            totalCleanupOperations: totalCleanups,
            complianceLevelBreakdown: complianceLevelBreakdown,
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        logger.info("Generated fleet overview report", metadata: [
            "totalAgents": "\(report.totalAgents)",
            "averageScore": "\(String(format: "%.1f", report.averageComplianceScore))",
            "complianceRate": "\(String(format: "%.1f", report.complianceRate))%"
        ])

        return report
    }

    /// Generate a compliance report for a specific agent
    public func generateAgentReport(for agentId: UUID) async throws -> AgentComplianceReport {
        guard let agent = await registry.agent(byId: agentId) else {
            throw ComplianceReportError.agentNotFound(agentId)
        }

        let score = try await calculateScore(for: agentId)

        let cleanupStats = AgentCleanupStats(
            totalBytesFreed: agent.latestStatus?.totalFreedBytes ?? 0,
            operationCount: agent.latestStatus?.cleanupCount ?? 0,
            lastCleanupAt: nil
        )

        let report = AgentComplianceReport(
            agentId: agentId,
            hostname: agent.identity.hostname,
            tags: agent.identity.tags,
            complianceScore: score,
            connectionState: agent.connectionState,
            healthStatus: agent.latestStatus?.healthStatus ?? .unknown,
            activePolicies: [],
            policyHistory: [],
            cleanupStats: cleanupStats
        )

        logger.info("Generated agent compliance report", metadata: [
            "agentId": "\(agentId)",
            "hostname": "\(agent.identity.hostname)",
            "overallScore": "\(String(format: "%.1f", score.overallScore))"
        ])

        return report
    }

    /// Generate a policy execution report
    public func generatePolicyExecutionReport(
        distributionId: UUID
    ) async throws -> PolicyExecutionReport {
        guard let distribution = await distributor.distribution(byId: distributionId) else {
            throw ComplianceReportError.distributionNotFound(distributionId)
        }

        let agents = await registry.allAgents()
        let agentLookup = Dictionary(uniqueKeysWithValues: agents.map { ($0.identity.id, $0) })

        var agentStatuses: [AgentPolicyStatus] = []
        for (agentId, status) in distribution.agentStatuses {
            let hostname = agentLookup[agentId]?.identity.hostname ?? "unknown"
            let executionStatus: PolicyExecutionStatus = switch status.state {
            case .pending: .pending
            case .inProgress: .executing
            case .completed: .completed
            case .failed: .failed
            case .cancelled, .rollingBack, .rolledBack, .partiallyCompleted: .skipped
            }

            agentStatuses.append(AgentPolicyStatus(
                agentId: agentId,
                hostname: hostname,
                status: executionStatus,
                errorMessage: status.errorMessage,
                executedAt: status.completedAt
            ))
        }

        let report = PolicyExecutionReport(
            policyName: distribution.policyName,
            version: distribution.policyVersion,
            totalTargetedAgents: distribution.totalAgents,
            successfulExecutions: distribution.successfulAgents,
            failedExecutions: distribution.failedAgents,
            pendingExecutions: distribution.pendingAgents,
            agentStatuses: agentStatuses,
            distributionStartedAt: distribution.startedAt ?? distribution.initiatedAt,
            distributionCompletedAt: distribution.completedAt
        )

        logger.info("Generated policy execution report", metadata: [
            "policyName": "\(distribution.policyName)",
            "version": "\(distribution.policyVersion)",
            "successRate": "\(String(format: "%.1f", report.successRate))%"
        ])

        return report
    }

    /// Generate an audit log summary
    public func generateAuditLogSummary(
        periodStart: Date,
        periodEnd: Date
    ) async throws -> AuditLogSummary {
        guard periodStart < periodEnd else {
            throw ComplianceReportError.invalidDateRange
        }

        let filteredLogs = auditLogs.filter {
            $0.timestamp >= periodStart && $0.timestamp <= periodEnd
        }

        var entriesBySeverity: [AuditSeverity: Int] = [:]
        var entriesByCategory: [String: Int] = [:]
        var agentVolumes: [UUID: (hostname: String, count: Int)] = [:]

        let agents = await registry.allAgents()
        let agentLookup = Dictionary(uniqueKeysWithValues: agents.map { ($0.identity.id, $0) })

        for entry in filteredLogs {
            entriesBySeverity[entry.severity, default: 0] += 1
            entriesByCategory[entry.category, default: 0] += 1

            let hostname = agentLookup[entry.agentId]?.identity.hostname ?? "unknown"
            if let existing = agentVolumes[entry.agentId] {
                agentVolumes[entry.agentId] = (existing.hostname, existing.count + 1)
            } else {
                agentVolumes[entry.agentId] = (hostname, 1)
            }
        }

        let topAgentsByVolume = agentVolumes
            .map { AgentLogVolume(agentId: $0.key, hostname: $0.value.hostname, entryCount: $0.value.count) }
            .sorted { $0.entryCount > $1.entryCount }
            .prefix(10)

        let recentCritical = filteredLogs
            .filter { $0.severity == .critical }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(configuration.maxAuditLogEntries)

        let summary = AuditLogSummary(
            totalEntries: filteredLogs.count,
            entriesBySeverity: entriesBySeverity,
            entriesByCategory: entriesByCategory,
            topAgentsByVolume: Array(topAgentsByVolume),
            recentCriticalEntries: Array(recentCritical),
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        logger.info("Generated audit log summary", metadata: [
            "totalEntries": "\(summary.totalEntries)",
            "periodStart": "\(periodStart)",
            "periodEnd": "\(periodEnd)"
        ])

        return summary
    }

    // MARK: - Export

    /// Export a fleet overview report to the specified format
    public func exportFleetOverview(
        _ report: FleetOverviewReport,
        format: ReportExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try exportToJSON(report)
        case .csv:
            return try exportFleetOverviewToCSV(report)
        }
    }

    /// Export an agent compliance report to the specified format
    public func exportAgentReport(
        _ report: AgentComplianceReport,
        format: ReportExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try exportToJSON(report)
        case .csv:
            return try exportAgentReportToCSV(report)
        }
    }

    /// Export a policy execution report to the specified format
    public func exportPolicyExecutionReport(
        _ report: PolicyExecutionReport,
        format: ReportExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try exportToJSON(report)
        case .csv:
            return try exportPolicyExecutionToCSV(report)
        }
    }

    // MARK: - Audit Logging

    /// Record an audit log entry
    public func recordAuditLog(
        agentId: UUID,
        severity: AuditSeverity,
        category: String,
        message: String
    ) {
        let entry = AuditLogEntry(
            agentId: agentId,
            severity: severity,
            category: category,
            message: message
        )

        auditLogs.insert(entry, at: 0)

        if auditLogs.count > maxStoredAuditLogs {
            auditLogs = Array(auditLogs.prefix(maxStoredAuditLogs))
        }

        logger.debug("Recorded audit log", metadata: [
            "agentId": "\(agentId)",
            "severity": "\(severity.rawValue)",
            "category": "\(category)"
        ])
    }

    /// Get recent audit logs
    public func recentAuditLogs(limit: Int = 100) -> [AuditLogEntry] {
        Array(auditLogs.prefix(limit))
    }

    // MARK: - Private Methods

    private func calculatePolicyScore(for agent: RegisteredAgent) -> Double {
        guard let status = agent.latestStatus else { return 50 }

        let policyCount = status.activePolicyCount
        if policyCount == 0 {
            return 100
        }

        return 100
    }

    private func calculateHealthScore(for agent: RegisteredAgent) -> Double {
        guard let status = agent.latestStatus else { return 50 }

        switch status.healthStatus {
        case .healthy:
            return 100
        case .warning:
            return 70
        case .critical:
            return 30
        case .unknown:
            return 50
        }
    }

    private func calculateConnectivityScore(for agent: RegisteredAgent) -> Double {
        guard agent.connectionState == .active else {
            return agent.connectionState == .offline ? 30 : 0
        }

        guard let timeSince = agent.timeSinceLastHeartbeat else {
            return 80
        }

        if timeSince < 60 {
            return 100
        } else if timeSince < 300 {
            return 80
        } else if timeSince < configuration.heartbeatTimeout {
            return 60
        } else {
            return 30
        }
    }

    private func exportToJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(value)
        } catch {
            throw ComplianceReportError.exportFailed(error.localizedDescription)
        }
    }

    private func exportFleetOverviewToCSV(_ report: FleetOverviewReport) throws -> Data {
        var csv = "Metric,Value\n"
        csv += "Report ID,\(report.id)\n"
        csv += "Generated At,\(ISO8601DateFormatter().string(from: report.generatedAt))\n"
        csv += "Total Agents,\(report.totalAgents)\n"
        csv += "Active Agents,\(report.activeAgents)\n"
        csv += "Offline Agents,\(report.offlineAgents)\n"
        csv += "Average Compliance Score,\(String(format: "%.2f", report.averageComplianceScore))\n"
        csv += "Compliant Agents,\(report.compliantAgents)\n"
        csv += "Non-Compliant Agents,\(report.nonCompliantAgents)\n"
        csv += "Critical Agents,\(report.criticalAgents)\n"
        csv += "Compliance Rate,\(String(format: "%.2f", report.complianceRate))%\n"
        csv += "Total Policies Deployed,\(report.totalPoliciesDeployed)\n"
        csv += "Successful Deployments,\(report.successfulDeployments)\n"
        csv += "Failed Deployments,\(report.failedDeployments)\n"
        csv += "Deployment Success Rate,\(String(format: "%.2f", report.deploymentSuccessRate))%\n"
        csv += "Total Bytes Freed,\(report.totalBytesFreed)\n"
        csv += "Total Cleanup Operations,\(report.totalCleanupOperations)\n"

        guard let data = csv.data(using: .utf8) else {
            throw ComplianceReportError.exportFailed("Failed to encode CSV")
        }
        return data
    }

    private func exportAgentReportToCSV(_ report: AgentComplianceReport) throws -> Data {
        var csv = "Metric,Value\n"
        csv += "Report ID,\(report.id)\n"
        csv += "Agent ID,\(report.agentId)\n"
        csv += "Hostname,\(report.hostname)\n"
        csv += "Tags,\"\(report.tags.joined(separator: ", "))\"\n"
        csv += "Overall Score,\(String(format: "%.2f", report.complianceScore.overallScore))\n"
        csv += "Policy Score,\(String(format: "%.2f", report.complianceScore.policyScore))\n"
        csv += "Health Score,\(String(format: "%.2f", report.complianceScore.healthScore))\n"
        csv += "Connectivity Score,\(String(format: "%.2f", report.complianceScore.connectivityScore))\n"
        csv += "Compliance Level,\(report.complianceScore.complianceLevel.rawValue)\n"
        csv += "Connection State,\(report.connectionState.rawValue)\n"
        csv += "Health Status,\(report.healthStatus.rawValue)\n"
        csv += "Total Bytes Freed,\(report.cleanupStats.totalBytesFreed)\n"
        csv += "Cleanup Operations,\(report.cleanupStats.operationCount)\n"
        csv += "Generated At,\(ISO8601DateFormatter().string(from: report.generatedAt))\n"

        guard let data = csv.data(using: .utf8) else {
            throw ComplianceReportError.exportFailed("Failed to encode CSV")
        }
        return data
    }

    private func exportPolicyExecutionToCSV(_ report: PolicyExecutionReport) throws -> Data {
        var csv = "Agent ID,Hostname,Status,Error,Executed At\n"

        for status in report.agentStatuses {
            let errorField = status.errorMessage?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let executedAt = status.executedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            csv += "\(status.agentId),\(status.hostname),\(status.status.rawValue),\"\(errorField)\",\(executedAt)\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ComplianceReportError.exportFailed("Failed to encode CSV")
        }
        return data
    }
}

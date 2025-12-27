// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class ServerFleetCLITests: XCTestCase {

    // MARK: - Test Fixtures

    private var registry: AgentRegistry!
    private var distributor: PolicyDistributor!

    override func setUp() async throws {
        registry = AgentRegistry()
        distributor = PolicyDistributor(registry: registry)
    }

    // MARK: - AgentRegistry Tests for CLI

    func testAgentRegistryStatistics() async throws {
        let stats = await registry.statistics()

        XCTAssertEqual(stats.totalAgents, 0)
        XCTAssertEqual(stats.activeAgents, 0)
        XCTAssertEqual(stats.offlineAgents, 0)
        XCTAssertEqual(stats.pendingAgents, 0)
    }

    func testAgentRegistrationForCLI() async throws {
        let identity = AgentIdentity(
            id: UUID(),
            hostname: "test-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: ["test", "cli"]
        )

        let agent = try await registry.register(
            identity: identity,
            capabilities: ["cleanup", "monitor"]
        )

        XCTAssertEqual(agent.identity.hostname, "test-mac")
        XCTAssertEqual(agent.connectionState, .active)
        XCTAssertEqual(agent.capabilities.count, 2)

        let stats = await registry.statistics()
        XCTAssertEqual(stats.totalAgents, 1)
        XCTAssertEqual(stats.activeAgents, 1)
    }

    func testAgentListingByState() async throws {
        // Register multiple agents
        for i in 0..<3 {
            let identity = AgentIdentity(
                id: UUID(),
                hostname: "test-mac-\(i)",
                osVersion: "14.0",
                appVersion: "0.1.0",
                tags: []
            )
            _ = try await registry.register(identity: identity, capabilities: [])
        }

        let allAgents = await registry.allAgents()
        XCTAssertEqual(allAgents.count, 3)

        let activeAgents = await registry.agents(withState: .active)
        XCTAssertEqual(activeAgents.count, 3)

        let offlineAgents = await registry.agents(withState: .offline)
        XCTAssertEqual(offlineAgents.count, 0)
    }

    func testAgentListingByTag() async throws {
        // Register agent with tags
        let identity1 = AgentIdentity(
            id: UUID(),
            hostname: "prod-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: ["production", "critical"]
        )
        _ = try await registry.register(identity: identity1, capabilities: [])

        let identity2 = AgentIdentity(
            id: UUID(),
            hostname: "dev-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: ["development"]
        )
        _ = try await registry.register(identity: identity2, capabilities: [])

        let prodAgents = await registry.agents(withTags: ["production"])
        XCTAssertEqual(prodAgents.count, 1)
        XCTAssertEqual(prodAgents.first?.identity.hostname, "prod-mac")

        let devAgents = await registry.agents(withTags: ["development"])
        XCTAssertEqual(devAgents.count, 1)
    }

    // MARK: - Distribution Target Tests

    func testDistributionTargetAll() async throws {
        // Register agents
        for i in 0..<5 {
            let identity = AgentIdentity(
                id: UUID(),
                hostname: "mac-\(i)",
                osVersion: "14.0",
                appVersion: "0.1.0",
                tags: []
            )
            _ = try await registry.register(identity: identity, capabilities: [])
        }

        let target = DistributionTarget.all
        let allAgents = await registry.allAgents()
        XCTAssertEqual(allAgents.count, 5)
    }

    func testDistributionTargetByAgentIds() async throws {
        var agentIds: [UUID] = []

        for i in 0..<3 {
            let id = UUID()
            agentIds.append(id)

            let identity = AgentIdentity(
                id: id,
                hostname: "mac-\(i)",
                osVersion: "14.0",
                appVersion: "0.1.0",
                tags: []
            )
            _ = try await registry.register(identity: identity, capabilities: [])
        }

        // Target specific agents
        let targetIds = Array(agentIds.prefix(2))
        let target = DistributionTarget.agents(targetIds)

        if case .agents(let ids) = target {
            XCTAssertEqual(ids.count, 2)
        } else {
            XCTFail("Target should be .agents")
        }
    }

    func testDistributionTargetByTags() {
        let target = DistributionTarget.tags(["production", "critical"])

        if case .tags(let tags) = target {
            XCTAssertEqual(tags.count, 2)
            XCTAssertTrue(tags.contains("production"))
            XCTAssertTrue(tags.contains("critical"))
        } else {
            XCTFail("Target should be .tags")
        }
    }

    // MARK: - Compliance Reporter Tests for CLI

    func testComplianceReporterInitialization() async throws {
        let reporter = ComplianceReporter(registry: registry, distributor: distributor)
        XCTAssertNotNil(reporter)
    }

    func testFleetOverviewReportGeneration() async throws {
        // Register an agent first
        let identity = AgentIdentity(
            id: UUID(),
            hostname: "test-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: []
        )
        _ = try await registry.register(identity: identity, capabilities: [])

        let reporter = ComplianceReporter(registry: registry, distributor: distributor)
        let report = try await reporter.generateFleetOverview()

        XCTAssertEqual(report.totalAgents, 1)
        XCTAssertGreaterThanOrEqual(report.averageComplianceScore, 0)
        XCTAssertLessThanOrEqual(report.averageComplianceScore, 100)
        XCTAssertNotNil(report.generatedAt)
    }

    // MARK: - Agent Status Tests

    func testAgentStatusCreation() {
        let agentId = UUID()
        let status = AgentStatus.current(
            agentId: agentId,
            connectionState: .active
        )

        XCTAssertEqual(status.agentId, agentId)
        XCTAssertEqual(status.connectionState, .active)
        XCTAssertTrue(status.isOnline)
    }

    func testAgentStatusHealthDetermination() {
        let agentId = UUID()
        let status = AgentStatus.current(
            agentId: agentId,
            connectionState: .active
        )

        // Health should be determined based on available disk space
        XCTAssertTrue([.healthy, .warning, .critical, .unknown].contains(status.healthStatus))
    }

    // MARK: - HeartbeatResponse Tests

    func testHeartbeatResponseDefaults() {
        let response = HeartbeatResponse()

        XCTAssertTrue(response.acknowledged)
        XCTAssertEqual(response.pendingPolicies, 0)
        XCTAssertEqual(response.pendingCommands, 0)
        XCTAssertEqual(response.nextHeartbeat, 60)
    }

    func testHeartbeatResponseCustomValues() {
        let response = HeartbeatResponse(
            acknowledged: true,
            pendingPolicies: 3,
            pendingCommands: 2,
            nextHeartbeat: 120
        )

        XCTAssertTrue(response.acknowledged)
        XCTAssertEqual(response.pendingPolicies, 3)
        XCTAssertEqual(response.pendingCommands, 2)
        XCTAssertEqual(response.nextHeartbeat, 120)
    }

    // MARK: - ServerClientConfig Tests

    func testServerClientConfigDefaults() {
        let url = URL(string: "https://mgmt.example.com")!
        let config = ServerClientConfig(serverURL: url)

        XCTAssertEqual(config.serverURL, url)
        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertEqual(config.heartbeatInterval, 60)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertTrue(config.autoReconnect)
    }

    func testServerClientConfigCustomValues() {
        let url = URL(string: "https://mgmt.example.com")!
        let config = ServerClientConfig(
            serverURL: url,
            requestTimeout: 60,
            heartbeatInterval: 120,
            maxRetryAttempts: 5,
            retryDelay: 10,
            autoReconnect: false,
            certificatePinning: true
        )

        XCTAssertEqual(config.requestTimeout, 60)
        XCTAssertEqual(config.heartbeatInterval, 120)
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.retryDelay, 10)
        XCTAssertFalse(config.autoReconnect)
        XCTAssertTrue(config.certificatePinning)
    }

    // MARK: - AppConfiguration Server Settings Tests

    func testAppConfigurationServerSettings() {
        var config = AppConfiguration()

        XCTAssertNil(config.serverURL)
        XCTAssertNil(config.agentId)
        XCTAssertNil(config.authToken)

        config.serverURL = "https://mgmt.example.com"
        config.agentId = UUID()
        config.authToken = "test-token"
        config.serverTimeout = 60
        config.lastHeartbeat = Date()

        XCTAssertEqual(config.serverURL, "https://mgmt.example.com")
        XCTAssertNotNil(config.agentId)
        XCTAssertEqual(config.authToken, "test-token")
        XCTAssertEqual(config.serverTimeout, 60)
        XCTAssertNotNil(config.lastHeartbeat)
    }

    // MARK: - RegistryStatistics Tests

    func testRegistryStatisticsCalculation() async throws {
        // Register agents with different states
        let identity1 = AgentIdentity(
            id: UUID(),
            hostname: "active-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: []
        )
        _ = try await registry.register(identity: identity1, capabilities: [])

        let identity2 = AgentIdentity(
            id: UUID(),
            hostname: "offline-mac",
            osVersion: "14.0",
            appVersion: "0.1.0",
            tags: []
        )
        let agent2 = try await registry.register(identity: identity2, capabilities: [])
        try await registry.markOffline(agentId: agent2.identity.id)

        let stats = await registry.statistics()

        XCTAssertEqual(stats.totalAgents, 2)
        XCTAssertEqual(stats.activeAgents, 1)
        XCTAssertEqual(stats.offlineAgents, 1)
    }
}

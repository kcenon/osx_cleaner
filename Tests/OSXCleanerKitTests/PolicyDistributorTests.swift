import XCTest
@testable import OSXCleanerKit

final class PolicyDistributorTests: XCTestCase {

    // MARK: - Test Fixtures

    private var registry: AgentRegistry!
    private var distributor: PolicyDistributor!

    override func setUp() async throws {
        registry = AgentRegistry()
        // Use short timeouts for testing
        let testConfig = PolicyDistributorConfig(
            maxConcurrentDistributions: 10,
            maxRetryAttempts: 3,
            retryDelay: 0.1,
            acknowledgementTimeout: 0.1,  // Short timeout for tests
            continueOnFailure: true,
            minimumSuccessRate: 80,
            autoRollbackOnFailure: false
        )
        distributor = PolicyDistributor(configuration: testConfig, registry: registry)
    }

    // MARK: - DistributionTarget Tests

    func testDistributionTargetAll() async throws {
        // Register test agents
        let agent1 = try await registerTestAgent(name: "Agent1")
        let agent2 = try await registerTestAgent(name: "Agent2")

        let policy = createTestPolicy(name: "test-policy")
        let status = try await distributor.distribute(policy: policy, to: .all)

        XCTAssertEqual(status.totalAgents, 2)
        XCTAssertTrue(status.agentStatuses.keys.contains(agent1.identity.id))
        XCTAssertTrue(status.agentStatuses.keys.contains(agent2.identity.id))
    }

    func testDistributionTargetSpecificAgents() async throws {
        let agent1 = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")

        let policy = createTestPolicy(name: "test-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .agents([agent1.identity.id])
        )

        XCTAssertEqual(status.totalAgents, 1)
        XCTAssertTrue(status.agentStatuses.keys.contains(agent1.identity.id))
    }

    func testDistributionTargetByTags() async throws {
        _ = try await registerTestAgent(name: "Dev1", tags: ["developer"])
        _ = try await registerTestAgent(name: "Dev2", tags: ["developer"])
        _ = try await registerTestAgent(name: "Prod1", tags: ["production"])

        let policy = createTestPolicy(name: "dev-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .tags(["developer"])
        )

        XCTAssertEqual(status.totalAgents, 2)
    }

    func testDistributionTargetByCapabilities() async throws {
        _ = try await registerTestAgent(name: "Monitor1", capabilities: ["monitoring"])
        _ = try await registerTestAgent(name: "Cleanup1", capabilities: ["cleanup"])
        _ = try await registerTestAgent(name: "Both", capabilities: ["monitoring", "cleanup"])

        let policy = createTestPolicy(name: "monitor-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .capabilities(["monitoring"])
        )

        XCTAssertEqual(status.totalAgents, 2)
    }

    func testDistributionTargetCombined() async throws {
        let agent1 = try await registerTestAgent(name: "Agent1", tags: ["team-a"])
        let agent2 = try await registerTestAgent(name: "Agent2", tags: ["team-b"])
        _ = try await registerTestAgent(name: "Agent3", tags: ["team-c"])

        let policy = createTestPolicy(name: "combined-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .combined([.tags(["team-a"]), .tags(["team-b"])])
        )

        XCTAssertEqual(status.totalAgents, 2)
        XCTAssertTrue(status.agentStatuses.keys.contains(agent1.identity.id))
        XCTAssertTrue(status.agentStatuses.keys.contains(agent2.identity.id))
    }

    // MARK: - DistributionFilter Tests

    func testDistributionFilterWithRequiredTags() async throws {
        _ = try await registerTestAgent(name: "Full", tags: ["production", "critical"])
        _ = try await registerTestAgent(name: "Partial", tags: ["production"])
        _ = try await registerTestAgent(name: "None", tags: ["development"])

        let filter = DistributionFilter(requiredTags: ["production", "critical"])
        let policy = createTestPolicy(name: "critical-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .filter(filter)
        )

        XCTAssertEqual(status.totalAgents, 1)
    }

    func testDistributionFilterWithExcludedAgents() async throws {
        let agent1 = try await registerTestAgent(name: "Agent1")
        let agent2 = try await registerTestAgent(name: "Agent2")
        let agent3 = try await registerTestAgent(name: "Agent3")

        let filter = DistributionFilter(excludedAgents: [agent2.identity.id])
        let policy = createTestPolicy(name: "filtered-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .filter(filter)
        )

        XCTAssertEqual(status.totalAgents, 2)
        XCTAssertTrue(status.agentStatuses.keys.contains(agent1.identity.id))
        XCTAssertFalse(status.agentStatuses.keys.contains(agent2.identity.id))
        XCTAssertTrue(status.agentStatuses.keys.contains(agent3.identity.id))
    }

    func testDistributionFilterWithMaxAgents() async throws {
        _ = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")
        _ = try await registerTestAgent(name: "Agent3")

        let filter = DistributionFilter(maxAgents: 2)
        let policy = createTestPolicy(name: "limited-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .filter(filter)
        )

        XCTAssertEqual(status.totalAgents, 2)
    }

    func testDistributionFilterWithConnectionState() async throws {
        let agent1 = try await registerTestAgent(name: "Active")
        let agent2 = try await registerTestAgent(name: "Offline")
        try await registry.markOffline(agentId: agent2.identity.id)

        let filter = DistributionFilter(connectionState: .active)
        let policy = createTestPolicy(name: "active-only-policy")
        let status = try await distributor.distribute(
            policy: policy,
            to: .filter(filter)
        )

        XCTAssertEqual(status.totalAgents, 1)
        XCTAssertTrue(status.agentStatuses.keys.contains(agent1.identity.id))
    }

    // MARK: - Distribution Status Tests

    func testDistributionStatusProperties() async throws {
        _ = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")
        _ = try await registerTestAgent(name: "Agent3")

        let policy = createTestPolicy(name: "status-test")
        let status = try await distributor.distribute(policy: policy, to: .all)

        XCTAssertEqual(status.totalAgents, 3)
        XCTAssertEqual(status.policyName, "status-test")
        XCTAssertEqual(status.policyVersion, 1)
        XCTAssertNotNil(status.initiatedAt)
        XCTAssertNotNil(status.startedAt)
    }

    func testDistributionVersionIncrement() async throws {
        _ = try await registerTestAgent(name: "Agent1")

        let policy = createTestPolicy(name: "version-test")

        let status1 = try await distributor.distribute(policy: policy, to: .all)
        XCTAssertEqual(status1.policyVersion, 1)

        let status2 = try await distributor.distribute(policy: policy, to: .all)
        XCTAssertEqual(status2.policyVersion, 2)

        let currentVersion = await distributor.policyVersion(for: "version-test")
        XCTAssertEqual(currentVersion, 2)
    }

    func testDistributionHistory() async throws {
        _ = try await registerTestAgent(name: "Agent1")

        let policy1 = createTestPolicy(name: "history-test-1")
        let policy2 = createTestPolicy(name: "history-test-2")

        _ = try await distributor.distribute(policy: policy1, to: .all)
        _ = try await distributor.distribute(policy: policy2, to: .all)

        let history = await distributor.history(limit: 10)
        XCTAssertEqual(history.count, 2)
    }

    // MARK: - Error Cases Tests

    func testDistributionNoTargetAgents() async throws {
        let policy = createTestPolicy(name: "empty-target")

        do {
            _ = try await distributor.distribute(policy: policy, to: .all)
            XCTFail("Should have thrown noTargetAgents error")
        } catch let error as PolicyDistributionError {
            if case .noTargetAgents = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testDistributionNotFound() async throws {
        let randomId = UUID()

        let status = await distributor.distribution(byId: randomId)
        XCTAssertNil(status)
    }

    func testCancelNonexistentDistribution() async throws {
        let randomId = UUID()

        do {
            try await distributor.cancel(distributionId: randomId)
            XCTFail("Should have thrown distributionNotFound error")
        } catch let error as PolicyDistributionError {
            if case .distributionNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Acknowledgement Tests

    func testAgentAcknowledgement() async throws {
        // This test verifies the acknowledgement logic by checking
        // that distribution completes and status is tracked
        let agent = try await registerTestAgent(name: "AckAgent")
        let policy = createTestPolicy(name: "ack-test")

        let status = try await distributor.distribute(policy: policy, to: .all)

        // Distribution should complete (may be in history due to fast timeout)
        let finalStatus = await distributor.distribution(byId: status.id)

        XCTAssertNotNil(finalStatus)
        XCTAssertEqual(finalStatus?.policyName, "ack-test")
        XCTAssertEqual(finalStatus?.totalAgents, 1)

        // Verify agent status exists
        let agentStatus = finalStatus?.agentStatuses[agent.identity.id]
        XCTAssertNotNil(agentStatus)
    }

    // MARK: - Query Tests

    func testActiveDistributions() async throws {
        let activeDistributions = await distributor.activeDistributions()
        XCTAssertTrue(activeDistributions.isEmpty)
    }

    func testDistributionsForPolicy() async throws {
        _ = try await registerTestAgent(name: "Agent1")

        let policy = createTestPolicy(name: "query-test")
        _ = try await distributor.distribute(policy: policy, to: .all)

        let distributions = await distributor.distributions(forPolicy: "query-test")
        XCTAssertEqual(distributions.count, 1)
    }

    // MARK: - AgentDistributionStatus Tests

    func testAgentDistributionStatusProperties() {
        let agentId = UUID()
        let status = AgentDistributionStatus(
            agentId: agentId,
            state: .pending,
            policyVersion: 1
        )

        XCTAssertEqual(status.id, agentId)
        XCTAssertEqual(status.state, .pending)
        XCTAssertEqual(status.retryCount, 0)
        XCTAssertFalse(status.acknowledged)
        XCTAssertNil(status.duration)
    }

    func testAgentDistributionStatusDuration() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(5.0)

        var status = AgentDistributionStatus(
            agentId: UUID(),
            policyVersion: 1,
            startedAt: startDate
        )
        status.completedAt = endDate

        XCTAssertNotNil(status.duration)
        XCTAssertEqual(status.duration!, 5.0, accuracy: 0.1)
    }

    // MARK: - DistributionStatus Computed Properties Tests

    func testDistributionStatusSuccessRate() {
        var status = DistributionStatus(
            policyName: "test",
            policyVersion: 1,
            target: .all
        )

        // Add 10 agents: 8 successful, 2 failed
        for i in 0..<10 {
            let agentId = UUID()
            var agentStatus = AgentDistributionStatus(
                agentId: agentId,
                policyVersion: 1
            )
            agentStatus.state = i < 8 ? .completed : .failed
            status.agentStatuses[agentId] = agentStatus
        }

        XCTAssertEqual(status.successRate, 80.0, accuracy: 0.1)
        XCTAssertEqual(status.successfulAgents, 8)
        XCTAssertEqual(status.failedAgents, 2)
        XCTAssertFalse(status.isFullySuccessful)
    }

    func testDistributionStatusFullSuccess() {
        var status = DistributionStatus(
            policyName: "test",
            policyVersion: 1,
            target: .all
        )

        // Add 5 successful agents
        for _ in 0..<5 {
            let agentId = UUID()
            var agentStatus = AgentDistributionStatus(
                agentId: agentId,
                policyVersion: 1
            )
            agentStatus.state = .completed
            status.agentStatuses[agentId] = agentStatus
        }

        XCTAssertEqual(status.successRate, 100.0, accuracy: 0.1)
        XCTAssertTrue(status.isFullySuccessful)
    }

    // MARK: - DistributionFilter Tests

    func testDistributionFilterEquality() {
        let filter1 = DistributionFilter(
            requiredTags: ["production"],
            maxAgents: 10
        )
        let filter2 = DistributionFilter(
            requiredTags: ["production"],
            maxAgents: 10
        )
        let filter3 = DistributionFilter(
            requiredTags: ["staging"],
            maxAgents: 10
        )

        XCTAssertEqual(filter1, filter2)
        XCTAssertNotEqual(filter1, filter3)
    }

    // MARK: - Configuration Tests

    func testDistributorConfiguration() async {
        let config = PolicyDistributorConfig(
            maxConcurrentDistributions: 5,
            maxRetryAttempts: 5,
            retryDelay: 10,
            acknowledgementTimeout: 60,
            continueOnFailure: false,
            minimumSuccessRate: 90,
            autoRollbackOnFailure: true
        )

        let customDistributor = PolicyDistributor(
            configuration: config,
            registry: registry
        )

        // Verify distributor was created with custom config
        // (internal config is not directly accessible, but we can verify behavior)
        XCTAssertNotNil(customDistributor)
    }

    // MARK: - Helper Methods

    @discardableResult
    private func registerTestAgent(
        name: String,
        tags: [String] = [],
        capabilities: [String] = ["cleanup"]
    ) async throws -> RegisteredAgent {
        let identity = AgentIdentity(
            name: name,
            appVersion: "1.0.0",
            tags: tags
        )
        return try await registry.register(
            identity: identity,
            capabilities: capabilities
        )
    }

    private func createTestPolicy(name: String) -> Policy {
        Policy(
            name: name,
            displayName: "Test Policy: \(name)",
            description: "A test policy",
            rules: [
                PolicyRule(
                    id: "\(name)-rule",
                    target: .systemCaches,
                    action: .report,
                    schedule: .manual
                )
            ]
        )
    }
}

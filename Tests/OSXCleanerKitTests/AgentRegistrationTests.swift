import XCTest
@testable import OSXCleanerKit

final class AgentRegistrationTests: XCTestCase {

    // MARK: - AgentRegistry Tests

    func testRegistryInitialization() async {
        let registry = AgentRegistry()

        let count = await registry.agentCount
        XCTAssertEqual(count, 0)
    }

    func testRegistryConfiguration() async {
        let config = AgentRegistry.Configuration(
            tokenValidityDuration: 3600,
            maxAgents: 100,
            allowReregistration: false
        )

        let registry = AgentRegistry(configuration: config)
        let count = await registry.agentCount
        XCTAssertEqual(count, 0)
    }

    func testAgentRegistration() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(
            name: "TestAgent",
            appVersion: "1.0.0",
            tags: ["test"]
        )

        let agent = try await registry.register(
            identity: identity,
            capabilities: ["cleanup", "monitoring"]
        )

        XCTAssertEqual(agent.identity.id, identity.id)
        XCTAssertEqual(agent.connectionState, .active)
        XCTAssertFalse(agent.authToken.isEmpty)
        XCTAssertFalse(agent.isTokenExpired)

        let count = await registry.agentCount
        XCTAssertEqual(count, 1)
    }

    func testAgentLookupById() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        let registered = try await registry.register(
            identity: identity,
            capabilities: ["cleanup"]
        )

        let found = await registry.agent(byId: identity.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.identity.id, registered.identity.id)
    }

    func testAgentLookupByToken() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        let registered = try await registry.register(
            identity: identity,
            capabilities: ["cleanup"]
        )

        let found = await registry.agent(byToken: registered.authToken)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.identity.id, identity.id)
    }

    func testAgentUnregistration() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        _ = try await registry.register(
            identity: identity,
            capabilities: ["cleanup"]
        )

        var count = await registry.agentCount
        XCTAssertEqual(count, 1)

        try await registry.unregister(agentId: identity.id)

        count = await registry.agentCount
        XCTAssertEqual(count, 0)
    }

    func testUnregisterNonexistentAgent() async {
        let registry = AgentRegistry()
        let randomId = UUID()

        do {
            try await registry.unregister(agentId: randomId)
            XCTFail("Should have thrown agentNotFound error")
        } catch let error as AgentRegistry.RegistryError {
            if case .agentNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testMaxAgentsLimit() async throws {
        let config = AgentRegistry.Configuration(maxAgents: 2)
        let registry = AgentRegistry(configuration: config)

        _ = try await registry.register(
            identity: AgentIdentity(appVersion: "1.0.0"),
            capabilities: []
        )
        _ = try await registry.register(
            identity: AgentIdentity(appVersion: "1.0.0"),
            capabilities: []
        )

        do {
            _ = try await registry.register(
                identity: AgentIdentity(appVersion: "1.0.0"),
                capabilities: []
            )
            XCTFail("Should have thrown maxAgentsReached error")
        } catch let error as AgentRegistry.RegistryError {
            if case .maxAgentsReached = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testReregistrationAllowed() async throws {
        let config = AgentRegistry.Configuration(allowReregistration: true)
        let registry = AgentRegistry(configuration: config)
        let identity = AgentIdentity(appVersion: "1.0.0")

        let first = try await registry.register(
            identity: identity,
            capabilities: ["v1"]
        )

        let second = try await registry.register(
            identity: identity,
            capabilities: ["v2"]
        )

        XCTAssertNotEqual(first.authToken, second.authToken)

        let count = await registry.agentCount
        XCTAssertEqual(count, 1)
    }

    func testReregistrationDisallowed() async throws {
        let config = AgentRegistry.Configuration(allowReregistration: false)
        let registry = AgentRegistry(configuration: config)
        let identity = AgentIdentity(appVersion: "1.0.0")

        _ = try await registry.register(
            identity: identity,
            capabilities: []
        )

        do {
            _ = try await registry.register(
                identity: identity,
                capabilities: []
            )
            XCTFail("Should have thrown agentAlreadyRegistered error")
        } catch let error as AgentRegistry.RegistryError {
            if case .agentAlreadyRegistered = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testStatusUpdate() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        _ = try await registry.register(
            identity: identity,
            capabilities: ["cleanup"]
        )

        let status = AgentStatus(
            agentId: identity.id,
            connectionState: .active,
            healthStatus: .healthy,
            totalDiskSpace: 500_000_000_000,
            availableDiskSpace: 100_000_000_000
        )

        try await registry.updateStatus(agentId: identity.id, status: status)

        let agent = await registry.agent(byId: identity.id)
        XCTAssertEqual(agent?.latestStatus?.healthStatus, .healthy)
        XCTAssertNotNil(agent?.lastHeartbeat)
    }

    func testConnectionStateUpdate() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        _ = try await registry.register(
            identity: identity,
            capabilities: []
        )

        try await registry.markOffline(agentId: identity.id)
        var agent = await registry.agent(byId: identity.id)
        XCTAssertEqual(agent?.connectionState, .offline)

        try await registry.markActive(agentId: identity.id)
        agent = await registry.agent(byId: identity.id)
        XCTAssertEqual(agent?.connectionState, .active)
    }

    func testTokenValidation() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        let agent = try await registry.register(
            identity: identity,
            capabilities: []
        )

        let validatedId = try await registry.validateToken(agent.authToken)
        XCTAssertEqual(validatedId, identity.id)
    }

    func testInvalidTokenValidation() async throws {
        let registry = AgentRegistry()

        do {
            _ = try await registry.validateToken("invalid-token")
            XCTFail("Should have thrown invalidToken error")
        } catch let error as AgentRegistry.RegistryError {
            if case .invalidToken = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testTokenRefresh() async throws {
        let registry = AgentRegistry()
        let identity = AgentIdentity(appVersion: "1.0.0")

        let agent = try await registry.register(
            identity: identity,
            capabilities: []
        )

        let originalToken = agent.authToken
        let newToken = try await registry.refreshToken(agentId: identity.id)

        XCTAssertNotEqual(originalToken, newToken)
    }

    func testAgentFiltering() async throws {
        let registry = AgentRegistry()

        _ = try await registry.register(
            identity: AgentIdentity(appVersion: "1.0.0", tags: ["dev"]),
            capabilities: ["cleanup", "monitoring"]
        )
        _ = try await registry.register(
            identity: AgentIdentity(appVersion: "1.0.0", tags: ["prod"]),
            capabilities: ["cleanup"]
        )

        let withMonitoring = await registry.agents(withCapability: "monitoring")
        XCTAssertEqual(withMonitoring.count, 1)

        let devAgents = await registry.agents(withTags: ["dev"])
        XCTAssertEqual(devAgents.count, 1)
    }

    func testRegistryStatistics() async throws {
        let registry = AgentRegistry()

        for i in 0..<5 {
            let identity = AgentIdentity(
                name: "Agent\(i)",
                appVersion: "1.0.0"
            )
            _ = try await registry.register(
                identity: identity,
                capabilities: []
            )
        }

        let stats = await registry.statistics()
        XCTAssertEqual(stats.totalAgents, 5)
        XCTAssertEqual(stats.activeAgents, 5)
        XCTAssertEqual(stats.offlineAgents, 0)
    }

    // MARK: - RegistrationService Tests

    func testRegistrationServiceAutoApprove() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(policy: .autoApprove)
        let service = RegistrationService(registry: registry, configuration: config)

        let identity = AgentIdentity(appVersion: "1.0.0")
        let request = RegistrationRequest(identity: identity, capabilities: ["cleanup"])

        let outcome = try await service.processRegistration(request: request)

        XCTAssertTrue(outcome.result.success)
        XCTAssertNotNil(outcome.result.authToken)
        XCTAssertNotNil(outcome.agent)
    }

    func testRegistrationServiceManualApprove() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(policy: .manualApprove)
        let service = RegistrationService(registry: registry, configuration: config)

        let identity = AgentIdentity(appVersion: "1.0.0")
        let request = RegistrationRequest(identity: identity, capabilities: [])

        let outcome = try await service.processRegistration(request: request)

        XCTAssertFalse(outcome.result.success)
        XCTAssertNil(outcome.result.authToken)

        let pending = await service.isRegistrationPending(agentId: identity.id)
        XCTAssertTrue(pending)
    }

    func testRegistrationServiceManualApproval() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(policy: .manualApprove)
        let service = RegistrationService(registry: registry, configuration: config)

        let identity = AgentIdentity(appVersion: "1.0.0")
        let request = RegistrationRequest(identity: identity, capabilities: [])

        _ = try await service.processRegistration(request: request)

        // Now approve manually
        let approved = try await service.approveManualRegistration(agentId: identity.id)

        XCTAssertTrue(approved.result.success)
        XCTAssertNotNil(approved.agent)

        let pending = await service.isRegistrationPending(agentId: identity.id)
        XCTAssertFalse(pending)
    }

    func testRegistrationServiceWhitelist() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(
            policy: .whitelistOnly,
            whitelistedSerialHashes: ["allowed-hash"]
        )
        let service = RegistrationService(registry: registry, configuration: config)

        // Whitelisted agent
        let allowedIdentity = AgentIdentity(
            appVersion: "1.0.0",
            serialNumberHash: "allowed-hash"
        )
        let allowedRequest = RegistrationRequest(identity: allowedIdentity)
        let allowedOutcome = try await service.processRegistration(request: allowedRequest)
        XCTAssertTrue(allowedOutcome.result.success)

        // Non-whitelisted agent
        let deniedIdentity = AgentIdentity(
            appVersion: "1.0.0",
            serialNumberHash: "denied-hash"
        )
        let deniedRequest = RegistrationRequest(identity: deniedIdentity)
        let deniedOutcome = try await service.processRegistration(request: deniedRequest)
        XCTAssertFalse(deniedOutcome.result.success)
    }

    func testRegistrationServiceHostnamePattern() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(
            policy: .hostnamePattern,
            hostnamePatterns: ["^office-.*$", "^dev-.*$"]
        )
        let service = RegistrationService(registry: registry, configuration: config)

        // Matching hostname
        let matchingIdentity = AgentIdentity(
            hostname: "office-mac-001",
            appVersion: "1.0.0"
        )
        let matchingRequest = RegistrationRequest(identity: matchingIdentity)
        let matchingOutcome = try await service.processRegistration(request: matchingRequest)
        XCTAssertTrue(matchingOutcome.result.success)

        // Non-matching hostname
        let nonMatchingIdentity = AgentIdentity(
            hostname: "home-mac",
            appVersion: "1.0.0"
        )
        let nonMatchingRequest = RegistrationRequest(identity: nonMatchingIdentity)
        let nonMatchingOutcome = try await service.processRegistration(request: nonMatchingRequest)
        XCTAssertFalse(nonMatchingOutcome.result.success)
    }

    func testRegistrationServiceMinimumVersion() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(
            minimumAppVersion: "2.0.0"
        )
        let service = RegistrationService(registry: registry, configuration: config)

        // Old version
        let oldIdentity = AgentIdentity(appVersion: "1.9.9")
        let oldRequest = RegistrationRequest(identity: oldIdentity)

        do {
            _ = try await service.processRegistration(request: oldRequest)
            XCTFail("Should have thrown versionTooOld error")
        } catch let error as RegistrationService.RegistrationError {
            if case .versionTooOld(let required, let actual) = error {
                XCTAssertEqual(required, "2.0.0")
                XCTAssertEqual(actual, "1.9.9")
            } else {
                XCTFail("Wrong error type")
            }
        }

        // New version
        let newIdentity = AgentIdentity(appVersion: "2.1.0")
        let newRequest = RegistrationRequest(identity: newIdentity)
        let newOutcome = try await service.processRegistration(request: newRequest)
        XCTAssertTrue(newOutcome.result.success)
    }

    func testRegistrationServiceRequiredCapabilities() async throws {
        let registry = AgentRegistry()
        let config = RegistrationService.Configuration(
            requiredCapabilities: ["cleanup", "audit-logging"]
        )
        let service = RegistrationService(registry: registry, configuration: config)

        // Missing capabilities
        let missingRequest = RegistrationRequest(
            identity: AgentIdentity(appVersion: "1.0.0"),
            capabilities: ["cleanup"]
        )

        do {
            _ = try await service.processRegistration(request: missingRequest)
            XCTFail("Should have thrown missingCapabilities error")
        } catch let error as RegistrationService.RegistrationError {
            if case .missingCapabilities(let missing) = error {
                XCTAssertTrue(missing.contains("audit-logging"))
            } else {
                XCTFail("Wrong error type")
            }
        }

        // All capabilities present
        let completeRequest = RegistrationRequest(
            identity: AgentIdentity(appVersion: "1.0.0"),
            capabilities: ["cleanup", "audit-logging", "monitoring"]
        )
        let completeOutcome = try await service.processRegistration(request: completeRequest)
        XCTAssertTrue(completeOutcome.result.success)
    }

    // MARK: - HeartbeatMonitor Tests

    func testHeartbeatMonitorInitialization() async {
        let registry = AgentRegistry()
        let monitor = HeartbeatMonitor(registry: registry)

        let isMonitoring = await monitor.isMonitoring
        XCTAssertFalse(isMonitoring)
    }

    func testHeartbeatMonitorStartStop() async {
        let registry = AgentRegistry()
        let monitor = HeartbeatMonitor(registry: registry)

        await monitor.startMonitoring()
        var isMonitoring = await monitor.isMonitoring
        XCTAssertTrue(isMonitoring)

        await monitor.stopMonitoring()
        isMonitoring = await monitor.isMonitoring
        XCTAssertFalse(isMonitoring)
    }

    func testHeartbeatProcessing() async throws {
        let registry = AgentRegistry()
        let monitor = HeartbeatMonitor(registry: registry)

        let identity = AgentIdentity(appVersion: "1.0.0")
        _ = try await registry.register(
            identity: identity,
            capabilities: []
        )

        let status = AgentStatus(
            agentId: identity.id,
            connectionState: .active,
            healthStatus: .healthy
        )

        let response = try await monitor.processHeartbeat(
            agentId: identity.id,
            status: status
        )

        XCTAssertTrue(response.acknowledged)
        XCTAssertGreaterThan(response.nextHeartbeat, 0)
    }

    func testHeartbeatStatsTracking() async throws {
        let registry = AgentRegistry()
        let monitor = HeartbeatMonitor(registry: registry)

        let identity = AgentIdentity(appVersion: "1.0.0")
        _ = try await registry.register(
            identity: identity,
            capabilities: []
        )

        // Send multiple heartbeats
        for _ in 0..<3 {
            let status = AgentStatus(
                agentId: identity.id,
                connectionState: .active,
                healthStatus: .healthy
            )
            _ = try await monitor.processHeartbeat(agentId: identity.id, status: status)
        }

        let stats = await monitor.stats(for: identity.id)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalHeartbeats, 3)
    }

    func testHeartbeatMonitoringSummary() async throws {
        let registry = AgentRegistry()
        let monitor = HeartbeatMonitor(registry: registry)

        _ = try await registry.register(
            identity: AgentIdentity(appVersion: "1.0.0"),
            capabilities: []
        )

        let summary = await monitor.summary()
        XCTAssertEqual(summary.totalAgents, 1)
        XCTAssertEqual(summary.activeAgents, 1)
    }

    // MARK: - RegisteredAgent Tests

    func testRegisteredAgentProperties() {
        let identity = AgentIdentity(appVersion: "1.0.0")
        let agent = RegisteredAgent(
            identity: identity,
            authToken: "test-token",
            tokenExpiresAt: Date().addingTimeInterval(3600),
            capabilities: ["cleanup"],
            connectionState: .active,
            lastHeartbeat: Date(),
            registeredAt: Date()
        )

        XCTAssertEqual(agent.id, identity.id)
        XCTAssertFalse(agent.isTokenExpired)
        XCTAssertTrue(agent.isOnline)
        XCTAssertNotNil(agent.timeSinceLastHeartbeat)
    }

    func testRegisteredAgentCodable() throws {
        let identity = AgentIdentity(
            name: "Test",
            hostname: "test-host",
            appVersion: "1.0.0"
        )
        let agent = RegisteredAgent(
            identity: identity,
            authToken: "test-token",
            tokenExpiresAt: Date().addingTimeInterval(3600),
            capabilities: ["cleanup"],
            connectionState: .active,
            registeredAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(agent)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RegisteredAgent.self, from: data)

        XCTAssertEqual(agent.identity.id, decoded.identity.id)
        XCTAssertEqual(agent.authToken, decoded.authToken)
        XCTAssertEqual(agent.connectionState, decoded.connectionState)
    }

    // MARK: - RegistryStatistics Tests

    func testRegistryStatisticsCodable() throws {
        let stats = RegistryStatistics(
            totalAgents: 10,
            activeAgents: 8,
            offlineAgents: 2,
            pendingAgents: 0,
            healthyAgents: 7,
            warningAgents: 1,
            criticalAgents: 0,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stats)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RegistryStatistics.self, from: data)

        XCTAssertEqual(stats.totalAgents, decoded.totalAgents)
        XCTAssertEqual(stats.activeAgents, decoded.activeAgents)
    }
}

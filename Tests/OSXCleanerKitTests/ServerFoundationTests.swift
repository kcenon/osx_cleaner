import XCTest
@testable import OSXCleanerKit

final class ServerFoundationTests: XCTestCase {

    // MARK: - AgentIdentity Tests

    func testAgentIdentityInitialization() {
        let identity = AgentIdentity(
            appVersion: "1.0.0",
            tags: ["test", "development"]
        )

        XCTAssertNotNil(identity.id)
        XCTAssertFalse(identity.hostname.isEmpty)
        XCTAssertFalse(identity.osVersion.isEmpty)
        XCTAssertEqual(identity.appVersion, "1.0.0")
        XCTAssertFalse(identity.hardwareModel.isEmpty)
        XCTAssertFalse(identity.serialNumberHash.isEmpty)
        XCTAssertFalse(identity.username.isEmpty)
        XCTAssertEqual(identity.tags.count, 2)
    }

    func testAgentIdentityCurrent() {
        let identity = AgentIdentity.current(appVersion: "2.0.0", tags: ["production"])

        XCTAssertEqual(identity.appVersion, "2.0.0")
        XCTAssertEqual(identity.tags, ["production"])
    }

    func testAgentIdentityCodable() throws {
        let identity = AgentIdentity(
            id: UUID(),
            name: "TestAgent",
            hostname: "test-host",
            osVersion: "14.0",
            appVersion: "1.0.0",
            hardwareModel: "MacBookPro18,1",
            serialNumberHash: "abc123",
            username: "testuser",
            registeredAt: Date(),
            tags: ["tag1"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(identity)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentIdentity.self, from: data)

        XCTAssertEqual(identity.id, decoded.id)
        XCTAssertEqual(identity.name, decoded.name)
        XCTAssertEqual(identity.hostname, decoded.hostname)
        XCTAssertEqual(identity.appVersion, decoded.appVersion)
    }

    func testAgentIdentityHashable() {
        let id = UUID()
        let date = Date()
        let identity1 = AgentIdentity(
            id: id,
            name: "Test",
            hostname: "host",
            osVersion: "14.0",
            appVersion: "1.0",
            hardwareModel: "Mac",
            serialNumberHash: "hash",
            username: "user",
            registeredAt: date,
            tags: []
        )
        let identity2 = AgentIdentity(
            id: id,
            name: "Test",
            hostname: "host",
            osVersion: "14.0",
            appVersion: "1.0",
            hardwareModel: "Mac",
            serialNumberHash: "hash",
            username: "user",
            registeredAt: date,
            tags: []
        )

        XCTAssertEqual(identity1, identity2)
        XCTAssertEqual(identity1.hashValue, identity2.hashValue)
    }

    func testAgentIdentityComparable() {
        let identity1 = AgentIdentity(name: "Alpha", appVersion: "1.0")
        let identity2 = AgentIdentity(name: "Beta", appVersion: "1.0")

        XCTAssertTrue(identity1 < identity2)
    }

    // MARK: - AgentStatus Tests

    func testAgentConnectionStateAllCases() {
        let states = AgentConnectionState.allCases
        XCTAssertEqual(states.count, 5)
        XCTAssertTrue(states.contains(.pending))
        XCTAssertTrue(states.contains(.active))
        XCTAssertTrue(states.contains(.offline))
        XCTAssertTrue(states.contains(.disconnected))
        XCTAssertTrue(states.contains(.rejected))
    }

    func testAgentHealthStatusAllCases() {
        let statuses = AgentHealthStatus.allCases
        XCTAssertEqual(statuses.count, 4)
        XCTAssertTrue(statuses.contains(.healthy))
        XCTAssertTrue(statuses.contains(.warning))
        XCTAssertTrue(statuses.contains(.critical))
        XCTAssertTrue(statuses.contains(.unknown))
    }

    func testAgentStatusInitialization() {
        let agentId = UUID()
        let status = AgentStatus(
            agentId: agentId,
            connectionState: .active,
            healthStatus: .healthy,
            lastHeartbeat: Date(),
            activePolicyCount: 3,
            totalDiskSpace: 500_000_000_000,
            availableDiskSpace: 100_000_000_000,
            totalFreedBytes: 50_000_000_000,
            cleanupCount: 10
        )

        XCTAssertEqual(status.agentId, agentId)
        XCTAssertEqual(status.connectionState, .active)
        XCTAssertEqual(status.healthStatus, .healthy)
        XCTAssertEqual(status.activePolicyCount, 3)
        XCTAssertTrue(status.isOnline)
    }

    func testAgentStatusDiskUsagePercent() {
        let status = AgentStatus(
            agentId: UUID(),
            totalDiskSpace: 100,
            availableDiskSpace: 25
        )

        XCTAssertEqual(status.diskUsagePercent, 75.0, accuracy: 0.01)
    }

    func testAgentStatusFormattedSpace() {
        let status = AgentStatus(
            agentId: UUID(),
            totalDiskSpace: 500_000_000_000,
            availableDiskSpace: 100_000_000_000,
            totalFreedBytes: 50_000_000_000
        )

        XCTAssertFalse(status.formattedAvailableSpace.isEmpty)
        XCTAssertFalse(status.formattedFreedBytes.isEmpty)
    }

    func testAgentStatusCurrent() {
        let agentId = UUID()
        let status = AgentStatus.current(
            agentId: agentId,
            connectionState: .active,
            activePolicyCount: 5
        )

        XCTAssertEqual(status.agentId, agentId)
        XCTAssertEqual(status.connectionState, .active)
        XCTAssertNotNil(status.lastHeartbeat)
    }

    func testAgentStatusCodable() throws {
        let status = AgentStatus(
            agentId: UUID(),
            connectionState: .active,
            healthStatus: .healthy
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AgentStatus.self, from: data)

        XCTAssertEqual(status.agentId, decoded.agentId)
        XCTAssertEqual(status.connectionState, decoded.connectionState)
        XCTAssertEqual(status.healthStatus, decoded.healthStatus)
    }

    // MARK: - ProtocolVersion Tests

    func testProtocolVersionInitialization() {
        let version = ProtocolVersion(major: 1, minor: 2, patch: 3)
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 2)
        XCTAssertEqual(version.patch, 3)
        XCTAssertEqual(version.string, "1.2.3")
    }

    func testProtocolVersionCurrent() {
        let current = ProtocolVersion.current
        XCTAssertEqual(current.major, 1)
        XCTAssertEqual(current.minor, 0)
        XCTAssertEqual(current.patch, 0)
    }

    func testProtocolVersionComparison() {
        let v100 = ProtocolVersion(major: 1, minor: 0, patch: 0)
        let v101 = ProtocolVersion(major: 1, minor: 0, patch: 1)
        let v110 = ProtocolVersion(major: 1, minor: 1, patch: 0)
        let v200 = ProtocolVersion(major: 2, minor: 0, patch: 0)

        XCTAssertTrue(v100 < v101)
        XCTAssertTrue(v101 < v110)
        XCTAssertTrue(v110 < v200)
        XCTAssertFalse(v200 < v100)
    }

    // MARK: - ServerMessageType Tests

    func testServerMessageTypeRawValues() {
        XCTAssertEqual(ServerMessageType.register.rawValue, "register")
        XCTAssertEqual(ServerMessageType.heartbeat.rawValue, "heartbeat")
        XCTAssertEqual(ServerMessageType.policyPush.rawValue, "policyPush")
    }

    // MARK: - RegistrationRequest Tests

    func testRegistrationRequestDefaultCapabilities() {
        let capabilities = RegistrationRequest.defaultCapabilities
        XCTAssertTrue(capabilities.contains("cleanup"))
        XCTAssertTrue(capabilities.contains("policy-execution"))
        XCTAssertTrue(capabilities.contains("audit-logging"))
    }

    func testRegistrationRequestCodable() throws {
        let identity = AgentIdentity(appVersion: "1.0.0")
        let request = RegistrationRequest(
            identity: identity,
            capabilities: ["cleanup", "monitoring"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RegistrationRequest.self, from: data)

        XCTAssertEqual(request.identity.id, decoded.identity.id)
        XCTAssertEqual(request.capabilities, decoded.capabilities)
    }

    // MARK: - RegistrationResult Tests

    func testRegistrationResultSuccess() {
        let agentId = UUID()
        let result = RegistrationResult.success(
            agentId: agentId,
            authToken: "test-token",
            serverVersion: "1.0.0"
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.agentId, agentId)
        XCTAssertEqual(result.authToken, "test-token")
        XCTAssertNotNil(result.tokenExpiresAt)
    }

    func testRegistrationResultFailure() {
        let result = RegistrationResult.failure(message: "Invalid credentials")

        XCTAssertFalse(result.success)
        XCTAssertNil(result.agentId)
        XCTAssertNil(result.authToken)
        XCTAssertEqual(result.message, "Invalid credentials")
    }

    // MARK: - HeartbeatRequest/Response Tests

    func testHeartbeatRequestCodable() throws {
        let status = AgentStatus(agentId: UUID(), connectionState: .active)
        let request = HeartbeatRequest(status: status)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HeartbeatRequest.self, from: data)

        XCTAssertEqual(request.status.agentId, decoded.status.agentId)
    }

    func testHeartbeatResponseDefaults() {
        let response = HeartbeatResponse()

        XCTAssertTrue(response.acknowledged)
        XCTAssertEqual(response.pendingPolicies, 0)
        XCTAssertEqual(response.pendingCommands, 0)
        XCTAssertEqual(response.nextHeartbeat, 60)
    }

    // MARK: - RemoteCommand Tests

    func testRemoteCommandInitialization() {
        let command = RemoteCommand(
            type: .runCleanup,
            parameters: ["level": "standard"],
            priority: 1
        )

        XCTAssertNotNil(command.id)
        XCTAssertEqual(command.type, .runCleanup)
        XCTAssertEqual(command.parameters["level"], "standard")
        XCTAssertEqual(command.priority, 1)
        XCTAssertFalse(command.isExpired)
    }

    func testRemoteCommandExpiration() {
        let expiredCommand = RemoteCommand(
            type: .runCleanup,
            expiresAt: Date().addingTimeInterval(-60)
        )
        XCTAssertTrue(expiredCommand.isExpired)

        let validCommand = RemoteCommand(
            type: .runCleanup,
            expiresAt: Date().addingTimeInterval(60)
        )
        XCTAssertFalse(validCommand.isExpired)

        let noExpirationCommand = RemoteCommand(type: .runCleanup)
        XCTAssertFalse(noExpirationCommand.isExpired)
    }

    // MARK: - CommandResult Tests

    func testCommandResultCodable() throws {
        let commandId = UUID()
        let result = CommandResult(
            commandId: commandId,
            success: true,
            message: "Cleanup completed",
            duration: 5.5
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CommandResult.self, from: data)

        XCTAssertEqual(result.commandId, decoded.commandId)
        XCTAssertEqual(result.success, decoded.success)
        XCTAssertEqual(result.message, decoded.message)
    }

    // MARK: - ServerResponse Tests

    func testServerResponseOk() {
        let data = "test data"
        let response = ServerResponse.ok(data, correlationId: UUID())

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data, data)
        XCTAssertNil(response.error)
    }

    func testServerResponseError() {
        let response: ServerResponse<String> = ServerResponse.error(.unauthorized)

        XCTAssertFalse(response.success)
        XCTAssertNil(response.data)
        XCTAssertEqual(response.error?.code, "UNAUTHORIZED")
    }

    // MARK: - ServerError Tests

    func testServerErrorPredefined() {
        XCTAssertEqual(ServerError.unauthorized.code, "UNAUTHORIZED")
        XCTAssertEqual(ServerError.forbidden.code, "FORBIDDEN")
        XCTAssertEqual(ServerError.notFound.code, "NOT_FOUND")
        XCTAssertEqual(ServerError.invalidRequest.code, "INVALID_REQUEST")
        XCTAssertEqual(ServerError.serverError.code, "SERVER_ERROR")
    }

    // MARK: - ServerCommunicationError Tests

    func testServerCommunicationErrorDescriptions() {
        let connectionError = ServerCommunicationError.connectionFailed("timeout")
        XCTAssertTrue(connectionError.errorDescription?.contains("timeout") ?? false)

        let authError = ServerCommunicationError.authenticationFailed("invalid token")
        XCTAssertTrue(authError.errorDescription?.contains("invalid token") ?? false)

        let versionError = ServerCommunicationError.protocolVersionMismatch(
            server: ProtocolVersion(major: 2, minor: 0),
            client: ProtocolVersion(major: 1, minor: 0)
        )
        XCTAssertTrue(versionError.errorDescription?.contains("2.0.0") ?? false)
        XCTAssertTrue(versionError.errorDescription?.contains("1.0.0") ?? false)
    }

    // MARK: - ServerClientConfig Tests

    func testServerClientConfigDefaults() {
        let config = ServerClientConfig(
            serverURL: URL(string: "https://example.com")!
        )

        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertEqual(config.heartbeatInterval, 60)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.retryDelay, 5)
        XCTAssertTrue(config.autoReconnect)
        XCTAssertFalse(config.certificatePinning)
    }

    func testServerClientConfigCustom() {
        let config = ServerClientConfig(
            serverURL: URL(string: "https://example.com")!,
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
}

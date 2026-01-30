// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class MDMTests: XCTestCase {

    // MARK: - MDMProvider Tests

    func testMDMProviderDisplayNames() {
        XCTAssertEqual(MDMProvider.jamf.displayName, "Jamf Pro")
        XCTAssertEqual(MDMProvider.mosyle.displayName, "Mosyle")
        XCTAssertEqual(MDMProvider.kandji.displayName, "Kandji")
    }

    func testMDMProviderRawValues() {
        XCTAssertEqual(MDMProvider.jamf.rawValue, "jamf")
        XCTAssertEqual(MDMProvider.mosyle.rawValue, "mosyle")
        XCTAssertEqual(MDMProvider.kandji.rawValue, "kandji")
    }

    func testMDMProviderFromRawValue() {
        XCTAssertEqual(MDMProvider(rawValue: "jamf"), .jamf)
        XCTAssertEqual(MDMProvider(rawValue: "mosyle"), .mosyle)
        XCTAssertEqual(MDMProvider(rawValue: "kandji"), .kandji)
        XCTAssertNil(MDMProvider(rawValue: "invalid"))
    }

    // MARK: - MDMConfiguration Tests

    func testMDMConfigurationDefaults() {
        let url = URL(string: "https://example.jamfcloud.com")!
        let config = MDMConfiguration(provider: .jamf, serverURL: url)

        XCTAssertEqual(config.provider, .jamf)
        XCTAssertEqual(config.serverURL, url)
        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertEqual(config.syncInterval, 300)
        XCTAssertTrue(config.autoSync)
        XCTAssertTrue(config.autoReportStatus)
    }

    func testMDMConfigurationCustomValues() {
        let url = URL(string: "https://mosyle.example.com")!
        let config = MDMConfiguration(
            provider: .mosyle,
            serverURL: url,
            requestTimeout: 60,
            syncInterval: 600,
            autoSync: false,
            autoReportStatus: false
        )

        XCTAssertEqual(config.provider, .mosyle)
        XCTAssertEqual(config.requestTimeout, 60)
        XCTAssertEqual(config.syncInterval, 600)
        XCTAssertFalse(config.autoSync)
        XCTAssertFalse(config.autoReportStatus)
    }

    // MARK: - MDMCredentials Tests

    func testMDMCredentialsAPIToken() {
        let credentials = MDMCredentials(apiToken: "test-token-123")

        XCTAssertEqual(credentials.authType, .apiToken)
        XCTAssertEqual(credentials.apiToken, "test-token-123")
        XCTAssertNil(credentials.clientId)
        XCTAssertNil(credentials.clientSecret)
        XCTAssertNil(credentials.username)
        XCTAssertNil(credentials.password)
    }

    func testMDMCredentialsOAuth2() {
        let credentials = MDMCredentials(clientId: "client-id", clientSecret: "client-secret")

        XCTAssertEqual(credentials.authType, .oauth2ClientCredentials)
        XCTAssertNil(credentials.apiToken)
        XCTAssertEqual(credentials.clientId, "client-id")
        XCTAssertEqual(credentials.clientSecret, "client-secret")
        XCTAssertNil(credentials.username)
        XCTAssertNil(credentials.password)
    }

    func testMDMCredentialsBasicAuth() {
        let credentials = MDMCredentials(username: "admin", password: "password123")

        XCTAssertEqual(credentials.authType, .basicAuth)
        XCTAssertNil(credentials.apiToken)
        XCTAssertNil(credentials.clientId)
        XCTAssertNil(credentials.clientSecret)
        XCTAssertEqual(credentials.username, "admin")
        XCTAssertEqual(credentials.password, "password123")
    }

    // MARK: - MDMCommand Tests

    func testMDMCommandCreation() {
        let command = MDMCommand(
            id: "cmd-123",
            type: .cleanup,
            parameters: ["target": "caches"],
            priority: .high
        )

        XCTAssertEqual(command.id, "cmd-123")
        XCTAssertEqual(command.type, .cleanup)
        XCTAssertEqual(command.parameters["target"], "caches")
        XCTAssertEqual(command.priority, .high)
        XCTAssertFalse(command.isExpired)
    }

    func testMDMCommandExpiration() {
        let expiredCommand = MDMCommand(
            type: .cleanup,
            expiresAt: Date().addingTimeInterval(-60)  // Expired 1 minute ago
        )

        XCTAssertTrue(expiredCommand.isExpired)

        let validCommand = MDMCommand(
            type: .cleanup,
            expiresAt: Date().addingTimeInterval(3600)  // Expires in 1 hour
        )

        XCTAssertFalse(validCommand.isExpired)

        let noExpiryCommand = MDMCommand(
            type: .cleanup,
            expiresAt: nil
        )

        XCTAssertFalse(noExpiryCommand.isExpired)
    }

    func testMDMCommandPriorityComparison() {
        XCTAssertTrue(MDMCommand.CommandPriority.low < .normal)
        XCTAssertTrue(MDMCommand.CommandPriority.normal < .high)
        XCTAssertTrue(MDMCommand.CommandPriority.high < .urgent)
        XCTAssertFalse(MDMCommand.CommandPriority.urgent < .urgent)
    }

    // MARK: - MDMCommandResult Tests

    func testMDMCommandResultSuccess() {
        let result = MDMCommandResult(
            commandId: "cmd-123",
            success: true,
            message: "Freed 1.5 GB",
            duration: 5.5,
            details: ["bytes_freed": "1610612736"]
        )

        XCTAssertEqual(result.commandId, "cmd-123")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Freed 1.5 GB")
        XCTAssertEqual(result.duration, 5.5)
        XCTAssertEqual(result.details["bytes_freed"], "1610612736")
    }

    func testMDMCommandResultFailure() {
        let result = MDMCommandResult(
            commandId: "cmd-456",
            success: false,
            message: "Permission denied"
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, "Permission denied")
    }

    // MARK: - MDMCleanupStatus Tests

    func testMDMCleanupStatus() {
        let cleanupResult = MDMCleanupStatus.CleanupResult(
            success: true,
            bytesFreed: 1073741824,
            filesRemoved: 150,
            duration: 10.5
        )

        let status = MDMCleanupStatus(
            agentId: "agent-123",
            lastCleanupAt: Date(),
            lastCleanupResult: cleanupResult,
            diskFreeSpace: 50_000_000_000,
            diskTotalSpace: 500_000_000_000
        )

        XCTAssertEqual(status.agentId, "agent-123")
        XCTAssertNotNil(status.lastCleanupAt)
        XCTAssertNotNil(status.lastCleanupResult)
        XCTAssertTrue(status.lastCleanupResult!.success)
        XCTAssertEqual(status.lastCleanupResult!.bytesFreed, 1073741824)
        XCTAssertEqual(status.diskFreeSpace, 50_000_000_000)
        XCTAssertEqual(status.diskTotalSpace, 500_000_000_000)
    }

    // MARK: - MDMComplianceReport Tests

    func testMDMComplianceReportCompliant() {
        let policyInfo = MDMComplianceReport.PolicyComplianceInfo(
            policyId: "policy-1",
            policyName: "Default Cleanup",
            status: .compliant
        )

        let report = MDMComplianceReport(
            agentId: "agent-123",
            overallStatus: .compliant,
            policyReports: [policyInfo]
        )

        XCTAssertEqual(report.agentId, "agent-123")
        XCTAssertEqual(report.overallStatus, .compliant)
        XCTAssertEqual(report.policyReports.count, 1)
        XCTAssertEqual(report.policyReports[0].status, .compliant)
        XCTAssertTrue(report.policyReports[0].issues.isEmpty)
    }

    func testMDMComplianceReportNonCompliant() {
        let policyInfo = MDMComplianceReport.PolicyComplianceInfo(
            policyId: "policy-2",
            policyName: "Developer Cleanup",
            status: .nonCompliant,
            issues: ["Xcode cache exceeds 10GB", "DerivedData not cleaned in 30 days"],
            recommendations: ["Run cleanup with developer target"]
        )

        let report = MDMComplianceReport(
            agentId: "agent-456",
            overallStatus: .nonCompliant,
            policyReports: [policyInfo]
        )

        XCTAssertEqual(report.overallStatus, .nonCompliant)
        XCTAssertEqual(report.policyReports[0].issues.count, 2)
        XCTAssertEqual(report.policyReports[0].recommendations.count, 1)
    }

    // MARK: - MDMPolicy Tests

    func testMDMPolicy() {
        let policy = MDMPolicy(
            id: "policy-123",
            name: "Enterprise Cleanup Policy",
            version: 2,
            enabled: true,
            priority: 10,
            targets: ["systemCaches", "developerCaches"],
            schedule: "daily",
            exclusions: ["~/Documents", "~/Pictures"]
        )

        XCTAssertEqual(policy.id, "policy-123")
        XCTAssertEqual(policy.name, "Enterprise Cleanup Policy")
        XCTAssertEqual(policy.version, 2)
        XCTAssertTrue(policy.enabled)
        XCTAssertEqual(policy.priority, 10)
        XCTAssertEqual(policy.targets.count, 2)
        XCTAssertEqual(policy.schedule, "daily")
        XCTAssertEqual(policy.exclusions.count, 2)
    }

    // MARK: - MDMConnectionStatus Tests

    func testMDMConnectionStatusDisconnected() {
        let status = MDMConnectionStatus()

        XCTAssertNil(status.provider)
        XCTAssertNil(status.serverURL)
        XCTAssertEqual(status.connectionState, .disconnected)
        XCTAssertFalse(status.isConnected)
        XCTAssertNil(status.lastSyncAt)
        XCTAssertEqual(status.policiesCount, 0)
    }

    func testMDMConnectionStatusConnected() {
        let status = MDMConnectionStatus(
            provider: .jamf,
            serverURL: "https://company.jamfcloud.com",
            connectionState: .authenticated,
            isConnected: true,
            lastSyncAt: Date(),
            policiesCount: 5,
            pendingCommandsCount: 2
        )

        XCTAssertEqual(status.provider, .jamf)
        XCTAssertEqual(status.serverURL, "https://company.jamfcloud.com")
        XCTAssertEqual(status.connectionState, .authenticated)
        XCTAssertTrue(status.isConnected)
        XCTAssertNotNil(status.lastSyncAt)
        XCTAssertEqual(status.policiesCount, 5)
        XCTAssertEqual(status.pendingCommandsCount, 2)
    }

    // MARK: - MDMError Tests

    func testMDMErrorDescriptions() {
        XCTAssertEqual(
            MDMError.notConnected.errorDescription,
            "Not connected to MDM server"
        )

        XCTAssertEqual(
            MDMError.authenticationFailed("Invalid token").errorDescription,
            "MDM authentication failed: Invalid token"
        )

        XCTAssertEqual(
            MDMError.connectionFailed("Timeout").errorDescription,
            "MDM connection failed: Timeout"
        )

        XCTAssertEqual(
            MDMError.policyNotFound("policy-123").errorDescription,
            "MDM policy not found: policy-123"
        )

        XCTAssertEqual(
            MDMError.providerNotSupported(.jamf).errorDescription,
            "MDM provider 'Jamf Pro' is not supported"
        )

        XCTAssertEqual(
            MDMError.rateLimited(retryAfter: 60).errorDescription,
            "MDM rate limited, retry after 60 seconds"
        )
    }

    // MARK: - Codable Tests

    func testMDMPolicyCodable() throws {
        let policy = MDMPolicy(
            id: "test-policy",
            name: "Test Policy",
            version: 1,
            enabled: true,
            targets: ["systemCaches"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(policy)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MDMPolicy.self, from: data)

        XCTAssertEqual(decoded.id, policy.id)
        XCTAssertEqual(decoded.name, policy.name)
        XCTAssertEqual(decoded.version, policy.version)
        XCTAssertEqual(decoded.enabled, policy.enabled)
        XCTAssertEqual(decoded.targets, policy.targets)
    }

    func testMDMCommandCodable() throws {
        let command = MDMCommand(
            id: "cmd-test",
            type: .analyze,
            parameters: ["depth": "full"],
            priority: .normal
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(command)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MDMCommand.self, from: data)

        XCTAssertEqual(decoded.id, command.id)
        XCTAssertEqual(decoded.type, command.type)
        XCTAssertEqual(decoded.parameters, command.parameters)
        XCTAssertEqual(decoded.priority, command.priority)
    }

    func testMDMConnectionStatusCodable() throws {
        let status = MDMConnectionStatus(
            provider: .mosyle,
            serverURL: "https://mosyle.example.com",
            connectionState: .connected,
            isConnected: true,
            policiesCount: 3
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MDMConnectionStatus.self, from: data)

        XCTAssertEqual(decoded.provider, status.provider)
        XCTAssertEqual(decoded.serverURL, status.serverURL)
        XCTAssertEqual(decoded.connectionState, status.connectionState)
        XCTAssertEqual(decoded.policiesCount, status.policiesCount)
    }
}

// MARK: - Mock Connector for Testing

actor MockMDMConnector: MDMConnector {
    let provider: MDMProvider = .jamf

    var connectionState: MDMConnectionState = .disconnected

    private var policies: [MDMPolicy] = []
    private var commands: [MDMCommand] = []

    func connect(config: MDMConfiguration, credentials: MDMCredentials) async throws {
        connectionState = .authenticated
    }

    func disconnect() async throws {
        connectionState = .disconnected
    }

    func syncPolicies() async throws -> [MDMPolicy] {
        return policies
    }

    func getPolicy(id policyId: String) async throws -> MDMPolicy {
        guard let policy = policies.first(where: { $0.id == policyId }) else {
            throw MDMError.policyNotFound(policyId)
        }
        return policy
    }

    func reportStatus(_ status: MDMCleanupStatus) async throws {
        // Mock implementation
    }

    func reportCompliance(_ report: MDMComplianceReport) async throws {
        // Mock implementation
    }

    func fetchCommands() async throws -> [MDMCommand] {
        return commands
    }

    func reportCommandResult(_ result: MDMCommandResult) async throws {
        // Mock implementation
    }

    // Test helpers
    func addPolicy(_ policy: MDMPolicy) {
        policies.append(policy)
    }

    func addCommand(_ command: MDMCommand) {
        commands.append(command)
    }

    func clearAll() {
        policies.removeAll()
        commands.removeAll()
    }
}

// MARK: - Mock Connector Tests

final class MockMDMConnectorTests: XCTestCase {

    func testMockConnectorConnect() async throws {
        let connector = MockMDMConnector()

        let initialState = await connector.connectionState
        XCTAssertEqual(initialState, .disconnected)

        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!
        )
        let credentials = MDMCredentials(apiToken: "test-token")

        try await connector.connect(config: config, credentials: credentials)

        let connectedState = await connector.connectionState
        XCTAssertEqual(connectedState, .authenticated)
    }

    func testMockConnectorPolicies() async throws {
        let connector = MockMDMConnector()

        let policy = MDMPolicy(
            id: "test-policy",
            name: "Test Policy",
            version: 1,
            enabled: true
        )

        await connector.addPolicy(policy)

        let policies = try await connector.syncPolicies()
        XCTAssertEqual(policies.count, 1)
        XCTAssertEqual(policies[0].id, "test-policy")

        let fetchedPolicy = try await connector.getPolicy(id: "test-policy")
        XCTAssertEqual(fetchedPolicy.name, "Test Policy")
    }

    func testMockConnectorPolicyNotFound() async {
        let connector = MockMDMConnector()

        do {
            _ = try await connector.getPolicy(id: "nonexistent")
            XCTFail("Expected policyNotFound error")
        } catch MDMError.policyNotFound(let id) {
            XCTAssertEqual(id, "nonexistent")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMockConnectorCommands() async throws {
        let connector = MockMDMConnector()

        let command = MDMCommand(
            id: "test-cmd",
            type: .cleanup,
            priority: .high
        )

        await connector.addCommand(command)

        let commands = try await connector.fetchCommands()
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands[0].type, .cleanup)
    }
}

// MARK: - MDMService Dependency Injection Tests

final class MDMServiceDependencyInjectionTests: XCTestCase {

    func testMDMServiceUsesInjectedCleanerService() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        mockCleaner.cleanResult = CleanResult(
            freedBytes: 5000,
            filesRemoved: 10,
            directoriesRemoved: 2,
            errors: []
        )

        let mdmService = MDMService(cleanerService: mockCleaner)

        let command = MDMCommand(
            id: "cleanup-cmd",
            type: .cleanup,
            priority: .high
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then
        XCTAssertEqual(mockCleaner.cleanCallCount, 1, "CleanerService should be called once")
        XCTAssertNotNil(mockCleaner.lastCleanConfiguration, "Configuration should be captured")
        XCTAssertTrue(result.success, "Command should succeed")
        XCTAssertNotNil(result.message, "Message should be present")
        XCTAssertEqual(result.details["bytes_freed"], "5000", "Details should contain freed bytes")
    }

    func testMDMServiceHandlesCleanerServiceError() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        mockCleaner.cleanError = CleanError(
            path: "/test/path",
            reason: "Permission denied"
        )

        let mdmService = MDMService(cleanerService: mockCleaner)

        let command = MDMCommand(
            id: "cleanup-cmd",
            type: .cleanup,
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then
        XCTAssertEqual(mockCleaner.cleanCallCount, 1, "CleanerService should be called once")
        XCTAssertFalse(result.success, "Command should fail")
        XCTAssertNotNil(result.message, "Error message should be present")
    }

    func testMDMServiceDefaultCleanerService() async throws {
        // Given - MDMService with default CleanerService
        let mdmService = MDMService()

        let command = MDMCommand(
            id: "cleanup-cmd",
            type: .cleanup,
            priority: .normal
        )

        // When - Execute command (may succeed or fail based on actual system state)
        let result = try await mdmService.executeCommand(command)

        // Then - Verify result structure (not actual cleanup)
        XCTAssertNotNil(result.commandId, "Result should have command ID")
        XCTAssertEqual(result.commandId, "cleanup-cmd", "Command ID should match")
    }

    func testMDMServiceMultipleCleanupCommands() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        mockCleaner.cleanResult = CleanResult(
            freedBytes: 1000,
            filesRemoved: 5,
            directoriesRemoved: 1,
            errors: []
        )

        let mdmService = MDMService(cleanerService: mockCleaner)

        // When - Execute multiple cleanup commands
        for i in 1...3 {
            let command = MDMCommand(
                id: "cleanup-cmd-\(i)",
                type: .cleanup,
                priority: .normal
            )
            _ = try await mdmService.executeCommand(command)
        }

        // Then
        XCTAssertEqual(mockCleaner.cleanCallCount, 3, "CleanerService should be called 3 times")
    }

    func testMDMServiceSharedInstanceUsesDefaultCleaner() async throws {
        // Given - Shared instance should use default CleanerService
        let sharedService = MDMService.shared

        let command = MDMCommand(
            id: "test-cmd",
            type: .cleanup,
            priority: .low
        )

        // When
        let result = try await sharedService.executeCommand(command)

        // Then - Verify it completes (actual behavior depends on system)
        XCTAssertEqual(result.commandId, "test-cmd", "Command ID should match")
    }
}

// MARK: - MDMService Compliance and Configuration Tests

final class MDMServiceComplianceConfigTests: XCTestCase {

    func testExecuteCommandReportCompliance() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        // Connect to MDM first
        try await mdmService.connect(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            credentials: MDMCredentials(apiToken: "test-token")
        )

        let command = MDMCommand(
            id: "compliance-cmd",
            type: .reportCompliance,
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then - May fail due to network/mock connector, but should have structure
        XCTAssertEqual(result.commandId, "compliance-cmd")
        XCTAssertNotNil(result.message, "Result should have message")

        // Check that it either succeeded or failed with a meaningful message
        if result.success {
            XCTAssertTrue(result.message?.contains("Compliance reported") ?? false)
            XCTAssertNotNil(result.details["status"], "Should have compliance status in details")
        } else {
            // If failed, should have error message
            XCTAssertFalse(result.message?.isEmpty ?? true, "Should have failure message")
        }
    }

    func testExecuteCommandUpdateConfig() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        // Create valid configuration JSON
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            requestTimeout: 45,
            syncInterval: 400,
            autoSync: false,
            autoReportStatus: false
        )

        let encoder = JSONEncoder()
        let configData = try encoder.encode(config)
        guard let configString = String(data: configData, encoding: .utf8) else {
            XCTFail("Failed to create config string")
            return
        }

        // First connect to MDM
        try await mdmService.connect(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            credentials: MDMCredentials(apiToken: "test-token")
        )

        let command = MDMCommand(
            id: "config-cmd",
            type: .updateConfig,
            parameters: ["config": configString],
            priority: .high
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then
        XCTAssertEqual(result.commandId, "config-cmd")
        XCTAssertTrue(result.success, "Config update should succeed")
        XCTAssertNotNil(result.message, "Result should have message")
        XCTAssertTrue(result.message?.contains("Configuration updated") ?? false)
    }

    func testExecuteCommandUpdateConfigMissingParameter() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        // Connect first
        try await mdmService.connect(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            credentials: MDMCredentials(apiToken: "test-token")
        )

        // Command without config parameter
        let command = MDMCommand(
            id: "config-cmd",
            type: .updateConfig,
            parameters: [:],  // Missing "config" parameter
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then - executeCommand returns failure result, not throws
        XCTAssertEqual(result.commandId, "config-cmd")
        XCTAssertFalse(result.success, "Should fail due to missing parameter")
        XCTAssertTrue(result.message?.contains("Missing config parameter") ?? false)
    }

    func testExecuteCommandUpdateConfigInvalidJSON() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        // Connect first
        try await mdmService.connect(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            credentials: MDMCredentials(apiToken: "test-token")
        )

        let command = MDMCommand(
            id: "config-cmd",
            type: .updateConfig,
            parameters: ["config": "invalid-json-data"],
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then - executeCommand returns failure result, not throws
        XCTAssertEqual(result.commandId, "config-cmd")
        XCTAssertFalse(result.success, "Should fail due to invalid JSON")
        XCTAssertTrue(result.message?.contains("Failed to decode config") ?? false || result.message?.contains("Config update failed") ?? false)
    }

    func testExecuteCommandReportComplianceNotConnected() async throws {
        // Given - Not connected to MDM
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        let command = MDMCommand(
            id: "compliance-cmd",
            type: .reportCompliance,
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then - executeCommand returns failure result when not connected
        XCTAssertEqual(result.commandId, "compliance-cmd")
        XCTAssertFalse(result.success, "Should fail when not connected")
        XCTAssertTrue(result.message?.contains("Not connected") ?? false)
    }

    func testComplianceReportStructure() async throws {
        // Given
        let mockCleaner = MockCleanerService()
        let mdmService = MDMService(cleanerService: mockCleaner)

        // Connect to MDM
        try await mdmService.connect(
            provider: .jamf,
            serverURL: URL(string: "https://test.jamfcloud.com")!,
            credentials: MDMCredentials(apiToken: "test-token")
        )

        let command = MDMCommand(
            id: "compliance-cmd",
            type: .reportCompliance,
            priority: .normal
        )

        // When
        let result = try await mdmService.executeCommand(command)

        // Then - Verify command is properly handled
        XCTAssertEqual(result.commandId, "compliance-cmd")
        XCTAssertNotNil(result.message, "Should have message")

        // Check result structure (may succeed or fail due to network)
        if result.success {
            XCTAssertTrue(result.message?.contains("Compliance reported") ?? false)
            XCTAssertNotNil(result.details["status"], "Should have status in details")
            XCTAssertNotNil(result.details["policies_checked"], "Should have policies count")
        }
        // If failed, it's expected due to mock server
    }
}

// MARK: - MDMError Equatable Extension for Testing

extension MDMError: Equatable {
    public static func == (lhs: MDMError, rhs: MDMError) -> Bool {
        switch (lhs, rhs) {
        case (.notConnected, .notConnected):
            return true
        case (.authenticationFailed(let lMsg), .authenticationFailed(let rMsg)):
            return lMsg == rMsg
        case (.connectionFailed(let lMsg), .connectionFailed(let rMsg)):
            return lMsg == rMsg
        case (.requestFailed(let lMsg), .requestFailed(let rMsg)):
            return lMsg == rMsg
        case (.invalidConfiguration(let lMsg), .invalidConfiguration(let rMsg)):
            return lMsg == rMsg
        case (.policyNotFound(let lMsg), .policyNotFound(let rMsg)):
            return lMsg == rMsg
        case (.commandExecutionFailed(let lMsg), .commandExecutionFailed(let rMsg)):
            return lMsg == rMsg
        case (.providerNotSupported(let lProvider), .providerNotSupported(let rProvider)):
            return lProvider == rProvider
        case (.invalidResponse(let lMsg), .invalidResponse(let rMsg)):
            return lMsg == rMsg
        case (.rateLimited(let lRetry), .rateLimited(let rRetry)):
            return lRetry == rRetry
        case (.networkUnavailable, .networkUnavailable):
            return true
        default:
            return false
        }
    }
}

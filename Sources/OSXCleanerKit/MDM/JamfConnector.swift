// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Jamf Pro MDM Connector
///
/// Integrates OSX Cleaner with Jamf Pro MDM platform for enterprise deployment.
/// Supports OAuth 2.0 Client Credentials authentication and Jamf Pro REST API.
public actor JamfConnector: MDMConnector {

    // MARK: - Properties

    public let provider: MDMProvider = .jamf

    public private(set) var connectionState: MDMConnectionState = .disconnected

    private var config: MDMConfiguration?
    private var credentials: MDMCredentials?
    private var accessToken: String?
    private var tokenExpiresAt: Date?
    private var cachedPolicies: [MDMPolicy] = []
    private var lastSyncAt: Date?

    private let session: URLSession

    // MARK: - Initialization

    public init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Connection

    public func connect(config: MDMConfiguration, credentials: MDMCredentials) async throws {
        guard config.provider == .jamf else {
            throw MDMError.invalidConfiguration("Configuration is not for Jamf provider")
        }

        self.config = config
        self.credentials = credentials
        self.connectionState = .connecting

        AppLogger.shared.info("Connecting to Jamf Pro: \(config.serverURL.absoluteString)")

        do {
            try await authenticate()
            connectionState = .authenticated
            AppLogger.shared.info("Successfully connected to Jamf Pro")
        } catch {
            connectionState = .error
            throw error
        }
    }

    public func disconnect() async throws {
        if let token = accessToken, let config = config {
            // Invalidate the access token
            try? await invalidateToken(token, serverURL: config.serverURL)
        }

        accessToken = nil
        tokenExpiresAt = nil
        config = nil
        credentials = nil
        cachedPolicies = []
        connectionState = .disconnected

        AppLogger.shared.info("Disconnected from Jamf Pro")
    }

    // MARK: - Authentication

    private func authenticate() async throws {
        guard let config = config, let credentials = credentials else {
            throw MDMError.notConnected
        }

        connectionState = .authenticating

        switch credentials.authType {
        case .oauth2ClientCredentials:
            guard let clientId = credentials.clientId,
                  let clientSecret = credentials.clientSecret else {
                throw MDMError.authenticationFailed("Missing client credentials")
            }
            try await authenticateWithOAuth(
                serverURL: config.serverURL,
                clientId: clientId,
                clientSecret: clientSecret
            )

        case .basicAuth:
            guard let username = credentials.username,
                  let password = credentials.password else {
                throw MDMError.authenticationFailed("Missing basic auth credentials")
            }
            try await authenticateWithBasicAuth(
                serverURL: config.serverURL,
                username: username,
                password: password
            )

        case .apiToken:
            guard let token = credentials.apiToken else {
                throw MDMError.authenticationFailed("Missing API token")
            }
            // API tokens don't need authentication, just store
            accessToken = token
            tokenExpiresAt = Date.distantFuture
        }
    }

    private func authenticateWithOAuth(
        serverURL: URL,
        clientId: String,
        clientSecret: String
    ) async throws {
        let tokenURL = serverURL.appendingPathComponent("/api/oauth/token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(clientId):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw MDMError.authenticationFailed("Failed to encode credentials")
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw MDMError.authenticationFailed("Invalid client credentials")
            }
            throw MDMError.authenticationFailed("HTTP \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(JamfOAuthResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
    }

    private func authenticateWithBasicAuth(
        serverURL: URL,
        username: String,
        password: String
    ) async throws {
        // Jamf Pro API v1 token endpoint for basic auth
        let tokenURL = serverURL.appendingPathComponent("/api/v1/auth/token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"

        let credentials = "\(username):\(password)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw MDMError.authenticationFailed("Failed to encode credentials")
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw MDMError.authenticationFailed("Invalid username or password")
            }
            throw MDMError.authenticationFailed("HTTP \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(JamfTokenResponse.self, from: data)
        accessToken = tokenResponse.token
        tokenExpiresAt = ISO8601DateFormatter().date(from: tokenResponse.expires)
    }

    private func invalidateToken(_ token: String, serverURL: URL) async throws {
        let invalidateURL = serverURL.appendingPathComponent("/api/v1/auth/invalidate-token")

        var request = URLRequest(url: invalidateURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try? await session.data(for: request)
    }

    private func ensureAuthenticated() async throws {
        guard let tokenExpiresAt = tokenExpiresAt else {
            throw MDMError.notConnected
        }

        // Refresh token if expired or about to expire
        if Date() >= tokenExpiresAt.addingTimeInterval(-60) {
            try await authenticate()
        }
    }

    // MARK: - Policy Management

    public func syncPolicies() async throws -> [MDMPolicy] {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Syncing policies from Jamf Pro")

        // Fetch policies from Jamf Pro API
        let policiesURL = config.serverURL.appendingPathComponent("/api/v1/policies")

        var request = URLRequest(url: policiesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to fetch policies: HTTP \(httpResponse.statusCode)")
        }

        let jamfPolicies = try JSONDecoder().decode(JamfPoliciesResponse.self, from: data)
        let policies = jamfPolicies.results.compactMap { mapJamfPolicy($0) }

        cachedPolicies = policies
        lastSyncAt = Date()

        AppLogger.shared.info("Synced \(policies.count) policies from Jamf Pro")

        return policies
    }

    public func getPolicy(id policyId: String) async throws -> MDMPolicy {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        let policyURL = config.serverURL.appendingPathComponent("/api/v1/policies/\(policyId)")

        var request = URLRequest(url: policyURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        if httpResponse.statusCode == 404 {
            throw MDMError.policyNotFound(policyId)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to fetch policy: HTTP \(httpResponse.statusCode)")
        }

        let jamfPolicy = try JSONDecoder().decode(JamfPolicy.self, from: data)

        guard let policy = mapJamfPolicy(jamfPolicy) else {
            throw MDMError.invalidResponse("Failed to parse policy")
        }

        return policy
    }

    private func mapJamfPolicy(_ jamfPolicy: JamfPolicy) -> MDMPolicy? {
        // Map Jamf policy to MDM policy
        // Only include policies that have cleanup-related payloads
        guard jamfPolicy.general.enabled else {
            return nil
        }

        return MDMPolicy(
            id: String(jamfPolicy.general.id),
            name: jamfPolicy.general.name,
            version: 1,
            enabled: jamfPolicy.general.enabled,
            priority: jamfPolicy.general.priority ?? 0,
            targets: mapJamfTargets(jamfPolicy),
            schedule: jamfPolicy.general.trigger,
            exclusions: [],
            conditions: [:],
            updatedAt: Date()
        )
    }

    private func mapJamfTargets(_ policy: JamfPolicy) -> [String] {
        var targets: [String] = []

        // Map Jamf policy payloads to cleanup targets
        if let scripts = policy.scripts, !scripts.isEmpty {
            // Check script names for cleanup-related keywords
            for script in scripts {
                let name = script.name.lowercased()
                if name.contains("cache") {
                    targets.append("systemCaches")
                }
                if name.contains("developer") || name.contains("xcode") {
                    targets.append("developerCaches")
                }
                if name.contains("log") {
                    targets.append("systemLogs")
                }
            }
        }

        return targets.isEmpty ? ["systemCaches"] : targets
    }

    // MARK: - Status Reporting

    public func reportStatus(_ status: MDMCleanupStatus) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting cleanup status to Jamf Pro")

        // Use Jamf Pro inventory extension attributes
        let extensionURL = config.serverURL
            .appendingPathComponent("/api/v1/computers-inventory")
            .appendingPathComponent(status.agentId)
            .appendingPathComponent("extension-attributes")

        var request = URLRequest(url: extensionURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let extensionData = JamfExtensionAttributeUpdate(
            extensionAttributes: [
                JamfExtensionAttribute(
                    definitionId: "osxcleaner_status",
                    values: [formatStatusValue(status)]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(extensionData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report status: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported cleanup status to Jamf Pro")
    }

    private func formatStatusValue(_ status: MDMCleanupStatus) -> String {
        var value = "Last Cleanup: "
        if let lastCleanup = status.lastCleanupAt {
            let formatter = ISO8601DateFormatter()
            value += formatter.string(from: lastCleanup)
        } else {
            value += "Never"
        }

        if let result = status.lastCleanupResult {
            value += ", Freed: \(ByteCountFormatter.string(fromByteCount: Int64(result.bytesFreed), countStyle: .file))"
        }

        return value
    }

    public func reportCompliance(_ report: MDMComplianceReport) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting compliance to Jamf Pro")

        // Report compliance via Jamf Pro Smart Computer Groups or Extension Attributes
        let extensionURL = config.serverURL
            .appendingPathComponent("/api/v1/computers-inventory")
            .appendingPathComponent(report.agentId)
            .appendingPathComponent("extension-attributes")

        var request = URLRequest(url: extensionURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let complianceValue = formatComplianceValue(report)
        let extensionData = JamfExtensionAttributeUpdate(
            extensionAttributes: [
                JamfExtensionAttribute(
                    definitionId: "osxcleaner_compliance",
                    values: [complianceValue]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(extensionData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report compliance: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported compliance to Jamf Pro")
    }

    private func formatComplianceValue(_ report: MDMComplianceReport) -> String {
        switch report.overallStatus {
        case .compliant:
            return "Compliant"
        case .nonCompliant:
            let issues = report.policyReports.flatMap { $0.issues }
            return "Non-Compliant: \(issues.count) issue(s)"
        case .unknown:
            return "Unknown"
        case .error:
            return "Error"
        }
    }

    // MARK: - Remote Commands

    public func fetchCommands() async throws -> [MDMCommand] {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        // Jamf Pro uses policies with triggers for command execution
        // Fetch pending management commands
        let commandsURL = config.serverURL.appendingPathComponent("/api/v1/mdm/commands")

        var request = URLRequest(url: commandsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to fetch commands: HTTP \(httpResponse.statusCode)")
        }

        let commandsResponse = try JSONDecoder().decode(JamfCommandsResponse.self, from: data)

        return commandsResponse.results.compactMap { mapJamfCommand($0) }
    }

    private func mapJamfCommand(_ jamfCommand: JamfCommand) -> MDMCommand? {
        let commandType: MDMCommand.CommandType

        switch jamfCommand.commandType.lowercased() {
        case "customcommand":
            // Parse custom command for cleanup-related actions
            if jamfCommand.commandName?.lowercased().contains("cleanup") == true {
                commandType = .cleanup
            } else if jamfCommand.commandName?.lowercased().contains("analyze") == true {
                commandType = .analyze
            } else {
                return nil
            }
        case "refreshinventory":
            commandType = .reportStatus
        default:
            return nil
        }

        return MDMCommand(
            id: jamfCommand.uuid,
            type: commandType,
            parameters: [:],
            priority: .normal,
            createdAt: jamfCommand.dateTime ?? Date(),
            expiresAt: nil
        )
    }

    public func reportCommandResult(_ result: MDMCommandResult) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting command result to Jamf Pro: \(result.commandId)")

        // Report command result via Jamf Pro API
        let resultURL = config.serverURL.appendingPathComponent("/api/v1/mdm/commands/\(result.commandId)/status")

        var request = URLRequest(url: resultURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let statusData = JamfCommandStatus(
            status: result.success ? "Completed" : "Failed",
            message: result.message
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(statusData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report command result: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported command result to Jamf Pro")
    }
}

// MARK: - Jamf API Types

private struct JamfOAuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

private struct JamfTokenResponse: Codable {
    let token: String
    let expires: String
}

private struct JamfPoliciesResponse: Codable {
    let totalCount: Int?
    let results: [JamfPolicy]
}

private struct JamfPolicy: Codable {
    let general: JamfPolicyGeneral
    let scripts: [JamfScript]?
}

private struct JamfPolicyGeneral: Codable {
    let id: Int
    let name: String
    let enabled: Bool
    let trigger: String?
    let priority: Int?
}

private struct JamfScript: Codable {
    let id: Int
    let name: String
}

private struct JamfCommandsResponse: Codable {
    let totalCount: Int?
    let results: [JamfCommand]
}

private struct JamfCommand: Codable {
    let uuid: String
    let commandType: String
    let commandName: String?
    let dateTime: Date?
}

private struct JamfCommandStatus: Codable {
    let status: String
    let message: String?
}

private struct JamfExtensionAttributeUpdate: Codable {
    let extensionAttributes: [JamfExtensionAttribute]
}

private struct JamfExtensionAttribute: Codable {
    let definitionId: String
    let values: [String]
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Mosyle MDM Connector
///
/// Integrates OSX Cleaner with Mosyle MDM platform for enterprise deployment.
/// Supports API Token authentication and Mosyle REST API.
public actor MosyleConnector: MDMConnector {

    // MARK: - Properties

    public let provider: MDMProvider = .mosyle

    public private(set) var connectionState: MDMConnectionState = .disconnected

    private var config: MDMConfiguration?
    private var credentials: MDMCredentials?
    private var accessToken: String?
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
        guard config.provider == .mosyle else {
            throw MDMError.invalidConfiguration("Configuration is not for Mosyle provider")
        }

        self.config = config
        self.credentials = credentials
        self.connectionState = .connecting

        AppLogger.shared.info("Connecting to Mosyle: \(config.serverURL.absoluteString)")

        do {
            try await authenticate()
            connectionState = .authenticated
            AppLogger.shared.info("Successfully connected to Mosyle")
        } catch {
            connectionState = .error
            throw error
        }
    }

    public func disconnect() async throws {
        accessToken = nil
        config = nil
        credentials = nil
        cachedPolicies = []
        connectionState = .disconnected

        AppLogger.shared.info("Disconnected from Mosyle")
    }

    // MARK: - Authentication

    private func authenticate() async throws {
        guard let credentials = credentials else {
            throw MDMError.notConnected
        }

        connectionState = .authenticating

        switch credentials.authType {
        case .apiToken:
            guard let token = credentials.apiToken else {
                throw MDMError.authenticationFailed("Missing API token")
            }
            // Verify token by making a test request
            try await verifyToken(token)
            accessToken = token

        case .basicAuth:
            guard let username = credentials.username,
                  let password = credentials.password else {
                throw MDMError.authenticationFailed("Missing basic auth credentials")
            }
            try await authenticateWithBasicAuth(username: username, password: password)

        case .oauth2ClientCredentials:
            throw MDMError.authenticationFailed("OAuth2 not supported by Mosyle, use API token")
        }
    }

    private func verifyToken(_ token: String) async throws {
        guard let config = config else {
            throw MDMError.notConnected
        }

        let verifyURL = config.serverURL.appendingPathComponent("/api/v2/users/me")

        var request = URLRequest(url: verifyURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw MDMError.authenticationFailed("Invalid API token")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.authenticationFailed("Token verification failed: HTTP \(httpResponse.statusCode)")
        }
    }

    private func authenticateWithBasicAuth(username: String, password: String) async throws {
        guard let config = config else {
            throw MDMError.notConnected
        }

        let loginURL = config.serverURL.appendingPathComponent("/api/v2/login")

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let loginData = MosyleLoginRequest(email: username, password: password)
        request.httpBody = try JSONEncoder().encode(loginData)

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

        let loginResponse = try JSONDecoder().decode(MosyleLoginResponse.self, from: data)

        guard loginResponse.status == "success", let token = loginResponse.accessToken else {
            throw MDMError.authenticationFailed(loginResponse.message ?? "Authentication failed")
        }

        accessToken = token
    }

    private func ensureAuthenticated() async throws {
        guard accessToken != nil else {
            throw MDMError.notConnected
        }
    }

    // MARK: - Policy Management

    public func syncPolicies() async throws -> [MDMPolicy] {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Syncing policies from Mosyle")

        // Fetch profiles from Mosyle API
        let profilesURL = config.serverURL.appendingPathComponent("/api/v2/profiles")

        var request = URLRequest(url: profilesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to fetch profiles: HTTP \(httpResponse.statusCode)")
        }

        let profilesResponse = try JSONDecoder().decode(MosyleProfilesResponse.self, from: data)

        let policies = profilesResponse.response.compactMap { mapMosyleProfile($0) }

        cachedPolicies = policies
        lastSyncAt = Date()

        AppLogger.shared.info("Synced \(policies.count) policies from Mosyle")

        return policies
    }

    public func getPolicy(id policyId: String) async throws -> MDMPolicy {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        let profileURL = config.serverURL.appendingPathComponent("/api/v2/profiles/\(policyId)")

        var request = URLRequest(url: profileURL)
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
            throw MDMError.requestFailed("Failed to fetch profile: HTTP \(httpResponse.statusCode)")
        }

        let profileResponse = try JSONDecoder().decode(MosyleProfileDetailResponse.self, from: data)

        guard let profile = profileResponse.response,
              let policy = mapMosyleProfile(profile) else {
            throw MDMError.invalidResponse("Failed to parse profile")
        }

        return policy
    }

    private func mapMosyleProfile(_ profile: MosyleProfile) -> MDMPolicy? {
        guard profile.enabled else {
            return nil
        }

        return MDMPolicy(
            id: profile.id,
            name: profile.name,
            version: profile.version ?? 1,
            enabled: profile.enabled,
            priority: profile.priority ?? 0,
            targets: profile.targets ?? ["systemCaches"],
            schedule: profile.schedule,
            exclusions: profile.exclusions ?? [],
            conditions: [:],
            updatedAt: profile.updatedAt ?? Date()
        )
    }

    // MARK: - Status Reporting

    public func reportStatus(_ status: MDMCleanupStatus) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting cleanup status to Mosyle")

        let statusURL = config.serverURL.appendingPathComponent("/api/v2/devices/\(status.agentId)/status")

        var request = URLRequest(url: statusURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let statusData = MosyleStatusUpdate(
            customAttributes: [
                MosyleCustomAttribute(
                    name: "osxcleaner_last_cleanup",
                    value: formatStatusValue(status)
                ),
                MosyleCustomAttribute(
                    name: "osxcleaner_disk_free",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(status.diskFreeSpace),
                        countStyle: .file
                    )
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(statusData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report status: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported cleanup status to Mosyle")
    }

    private func formatStatusValue(_ status: MDMCleanupStatus) -> String {
        if let lastCleanup = status.lastCleanupAt {
            let formatter = ISO8601DateFormatter()
            var value = formatter.string(from: lastCleanup)

            if let result = status.lastCleanupResult {
                value += " (\(ByteCountFormatter.string(fromByteCount: Int64(result.bytesFreed), countStyle: .file)) freed)"
            }

            return value
        }

        return "Never"
    }

    public func reportCompliance(_ report: MDMComplianceReport) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting compliance to Mosyle")

        let complianceURL = config.serverURL.appendingPathComponent("/api/v2/devices/\(report.agentId)/compliance")

        var request = URLRequest(url: complianceURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let complianceData = MosyleComplianceUpdate(
            osxcleanerCompliance: MosyleComplianceStatus(
                status: report.overallStatus.rawValue,
                lastChecked: report.reportedAt,
                policies: report.policyReports.map { policy in
                    MosylePolicyCompliance(
                        policyId: policy.policyId,
                        policyName: policy.policyName,
                        status: policy.status.rawValue,
                        issues: policy.issues
                    )
                }
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(complianceData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report compliance: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported compliance to Mosyle")
    }

    // MARK: - Remote Commands

    public func fetchCommands() async throws -> [MDMCommand] {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        let commandsURL = config.serverURL.appendingPathComponent("/api/v2/commands/pending")

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

        let commandsResponse = try JSONDecoder().decode(MosyleCommandsResponse.self, from: data)

        return commandsResponse.response.compactMap { mapMosyleCommand($0) }
    }

    private func mapMosyleCommand(_ mosyleCommand: MosyleCommand) -> MDMCommand? {
        let commandType: MDMCommand.CommandType

        switch mosyleCommand.commandType.lowercased() {
        case "cleanup", "clean":
            commandType = .cleanup
        case "analyze", "scan":
            commandType = .analyze
        case "sync_policy", "syncpolicy":
            commandType = .syncPolicy
        case "report_status", "reportstatus":
            commandType = .reportStatus
        case "report_compliance", "reportcompliance":
            commandType = .reportCompliance
        default:
            return nil
        }

        let priority: MDMCommand.CommandPriority
        switch mosyleCommand.priority?.lowercased() {
        case "urgent":
            priority = .urgent
        case "high":
            priority = .high
        case "low":
            priority = .low
        default:
            priority = .normal
        }

        return MDMCommand(
            id: mosyleCommand.id,
            type: commandType,
            parameters: mosyleCommand.parameters ?? [:],
            priority: priority,
            createdAt: mosyleCommand.createdAt ?? Date(),
            expiresAt: mosyleCommand.expiresAt
        )
    }

    public func reportCommandResult(_ result: MDMCommandResult) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting command result to Mosyle: \(result.commandId)")

        let resultURL = config.serverURL.appendingPathComponent("/api/v2/commands/\(result.commandId)/result")

        var request = URLRequest(url: resultURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let resultData = MosyleCommandResult(
            status: result.success ? "completed" : "failed",
            message: result.message,
            executedAt: result.executedAt,
            duration: result.duration,
            details: result.details
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(resultData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to report command result: HTTP \(httpResponse.statusCode)")
        }

        AppLogger.shared.info("Successfully reported command result to Mosyle")
    }
}

// MARK: - Mosyle API Types

private struct MosyleLoginRequest: Codable {
    let email: String
    let password: String
}

private struct MosyleLoginResponse: Codable {
    let status: String
    let accessToken: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case accessToken = "access_token"
        case message
    }
}

private struct MosyleProfilesResponse: Codable {
    let status: String
    let response: [MosyleProfile]
}

private struct MosyleProfileDetailResponse: Codable {
    let status: String
    let response: MosyleProfile?
}

private struct MosyleProfile: Codable {
    let id: String
    let name: String
    let version: Int?
    let enabled: Bool
    let priority: Int?
    let targets: [String]?
    let schedule: String?
    let exclusions: [String]?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case enabled
        case priority
        case targets
        case schedule
        case exclusions
        case updatedAt = "updated_at"
    }
}

private struct MosyleStatusUpdate: Codable {
    let customAttributes: [MosyleCustomAttribute]

    enum CodingKeys: String, CodingKey {
        case customAttributes = "custom_attributes"
    }
}

private struct MosyleCustomAttribute: Codable {
    let name: String
    let value: String
}

private struct MosyleComplianceUpdate: Codable {
    let osxcleanerCompliance: MosyleComplianceStatus

    enum CodingKeys: String, CodingKey {
        case osxcleanerCompliance = "osxcleaner_compliance"
    }
}

private struct MosyleComplianceStatus: Codable {
    let status: String
    let lastChecked: Date
    let policies: [MosylePolicyCompliance]

    enum CodingKeys: String, CodingKey {
        case status
        case lastChecked = "last_checked"
        case policies
    }
}

private struct MosylePolicyCompliance: Codable {
    let policyId: String
    let policyName: String
    let status: String
    let issues: [String]

    enum CodingKeys: String, CodingKey {
        case policyId = "policy_id"
        case policyName = "policy_name"
        case status
        case issues
    }
}

private struct MosyleCommandsResponse: Codable {
    let status: String
    let response: [MosyleCommand]
}

private struct MosyleCommand: Codable {
    let id: String
    let commandType: String
    let priority: String?
    let parameters: [String: String]?
    let createdAt: Date?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case commandType = "command_type"
        case priority
        case parameters
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

private struct MosyleCommandResult: Codable {
    let status: String
    let message: String?
    let executedAt: Date
    let duration: TimeInterval
    let details: [String: String]

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case executedAt = "executed_at"
        case duration
        case details
    }
}

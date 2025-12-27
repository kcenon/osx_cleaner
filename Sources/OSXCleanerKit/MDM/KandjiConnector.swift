// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Kandji MDM Connector
///
/// Integrates OSX Cleaner with Kandji MDM platform for enterprise deployment.
/// Supports API Token authentication and Kandji REST API.
public actor KandjiConnector: MDMConnector {

    // MARK: - Properties

    public let provider: MDMProvider = .kandji

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
        guard config.provider == .kandji else {
            throw MDMError.invalidConfiguration("Configuration is not for Kandji provider")
        }

        self.config = config
        self.credentials = credentials
        self.connectionState = .connecting

        AppLogger.shared.info("Connecting to Kandji: \(config.serverURL.absoluteString)")

        do {
            try await authenticate()
            connectionState = .authenticated
            AppLogger.shared.info("Successfully connected to Kandji")
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

        AppLogger.shared.info("Disconnected from Kandji")
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

        case .basicAuth, .oauth2ClientCredentials:
            throw MDMError.authenticationFailed("Kandji only supports API token authentication")
        }
    }

    private func verifyToken(_ token: String) async throws {
        guard let config = config else {
            throw MDMError.notConnected
        }

        // Kandji API uses tenant-specific subdomain
        let verifyURL = config.serverURL.appendingPathComponent("/api/v1/prism/device_limit")

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

        if httpResponse.statusCode == 403 {
            throw MDMError.authenticationFailed("API token lacks required permissions")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.authenticationFailed("Token verification failed: HTTP \(httpResponse.statusCode)")
        }
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

        AppLogger.shared.info("Syncing blueprints from Kandji")

        // Fetch blueprints from Kandji API
        let blueprintsURL = config.serverURL.appendingPathComponent("/api/v1/blueprints")

        var request = URLRequest(url: blueprintsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MDMError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MDMError.requestFailed("Failed to fetch blueprints: HTTP \(httpResponse.statusCode)")
        }

        let blueprints = try JSONDecoder().decode([KandjiBlueprint].self, from: data)
        let policies = blueprints.compactMap { mapKandjiBlueprint($0) }

        cachedPolicies = policies
        lastSyncAt = Date()

        AppLogger.shared.info("Synced \(policies.count) policies from Kandji")

        return policies
    }

    public func getPolicy(id policyId: String) async throws -> MDMPolicy {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        let blueprintURL = config.serverURL.appendingPathComponent("/api/v1/blueprints/\(policyId)")

        var request = URLRequest(url: blueprintURL)
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
            throw MDMError.requestFailed("Failed to fetch blueprint: HTTP \(httpResponse.statusCode)")
        }

        let blueprint = try JSONDecoder().decode(KandjiBlueprint.self, from: data)

        guard let policy = mapKandjiBlueprint(blueprint) else {
            throw MDMError.invalidResponse("Failed to parse blueprint")
        }

        return policy
    }

    private func mapKandjiBlueprint(_ blueprint: KandjiBlueprint) -> MDMPolicy? {
        return MDMPolicy(
            id: blueprint.id,
            name: blueprint.name,
            version: 1,
            enabled: blueprint.active,
            priority: 0,
            targets: mapKandjiTargets(blueprint),
            schedule: nil,
            exclusions: [],
            conditions: [:],
            updatedAt: blueprint.updatedAt ?? Date()
        )
    }

    private func mapKandjiTargets(_ blueprint: KandjiBlueprint) -> [String] {
        var targets: [String] = []

        // Check blueprint parameters for cleanup-related settings
        if let params = blueprint.parameters {
            if params["cleanup_caches"] as? Bool == true {
                targets.append("systemCaches")
            }
            if params["cleanup_developer"] as? Bool == true {
                targets.append("developerCaches")
            }
            if params["cleanup_logs"] as? Bool == true {
                targets.append("systemLogs")
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

        AppLogger.shared.info("Reporting cleanup status to Kandji")

        // Kandji uses Custom Apps/Scripts for custom status reporting
        let statusURL = config.serverURL.appendingPathComponent("/api/v1/devices/\(status.agentId)/details")

        var request = URLRequest(url: statusURL)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let statusData = KandjiDeviceUpdate(
            customAttributes: [
                "osxcleaner_status": formatStatusJson(status)
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

        AppLogger.shared.info("Successfully reported cleanup status to Kandji")
    }

    private func formatStatusJson(_ status: MDMCleanupStatus) -> String {
        var dict: [String: Any] = [
            "disk_free": status.diskFreeSpace,
            "disk_total": status.diskTotalSpace
        ]

        if let lastCleanup = status.lastCleanupAt {
            dict["last_cleanup"] = ISO8601DateFormatter().string(from: lastCleanup)
        }

        if let result = status.lastCleanupResult {
            dict["last_result"] = [
                "success": result.success,
                "bytes_freed": result.bytesFreed,
                "files_removed": result.filesRemoved
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }

    public func reportCompliance(_ report: MDMComplianceReport) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting compliance to Kandji")

        let complianceURL = config.serverURL.appendingPathComponent("/api/v1/devices/\(report.agentId)/details")

        var request = URLRequest(url: complianceURL)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let complianceData = KandjiDeviceUpdate(
            customAttributes: [
                "osxcleaner_compliance": formatComplianceJson(report)
            ]
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

        AppLogger.shared.info("Successfully reported compliance to Kandji")
    }

    private func formatComplianceJson(_ report: MDMComplianceReport) -> String {
        let dict: [String: Any] = [
            "status": report.overallStatus.rawValue,
            "reported_at": ISO8601DateFormatter().string(from: report.reportedAt),
            "policies": report.policyReports.map { policy -> [String: Any] in
                [
                    "id": policy.policyId,
                    "name": policy.policyName,
                    "status": policy.status.rawValue,
                    "issues_count": policy.issues.count
                ]
            }
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }

    // MARK: - Remote Commands

    public func fetchCommands() async throws -> [MDMCommand] {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        // Kandji uses Custom Apps for custom command execution
        // Fetch pending commands via custom endpoint
        let commandsURL = config.serverURL.appendingPathComponent("/api/v1/library/custom-scripts")

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

        let scripts = try JSONDecoder().decode([KandjiCustomScript].self, from: data)

        // Filter for OSX Cleaner related scripts
        return scripts.compactMap { mapKandjiScript($0) }
    }

    private func mapKandjiScript(_ script: KandjiCustomScript) -> MDMCommand? {
        guard script.name.lowercased().contains("osxcleaner") else {
            return nil
        }

        let commandType: MDMCommand.CommandType

        let nameLower = script.name.lowercased()
        if nameLower.contains("cleanup") || nameLower.contains("clean") {
            commandType = .cleanup
        } else if nameLower.contains("analyze") || nameLower.contains("scan") {
            commandType = .analyze
        } else if nameLower.contains("sync") {
            commandType = .syncPolicy
        } else if nameLower.contains("status") {
            commandType = .reportStatus
        } else if nameLower.contains("compliance") {
            commandType = .reportCompliance
        } else {
            return nil
        }

        return MDMCommand(
            id: script.id,
            type: commandType,
            parameters: [:],
            priority: .normal,
            createdAt: script.createdAt ?? Date(),
            expiresAt: nil
        )
    }

    public func reportCommandResult(_ result: MDMCommandResult) async throws {
        try await ensureAuthenticated()

        guard let config = config, let token = accessToken else {
            throw MDMError.notConnected
        }

        AppLogger.shared.info("Reporting command result to Kandji: \(result.commandId)")

        // Kandji custom scripts report results via device activity
        let resultURL = config.serverURL.appendingPathComponent("/api/v1/library/custom-scripts/\(result.commandId)/status")

        var request = URLRequest(url: resultURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let resultData = KandjiScriptResult(
            status: result.success ? "completed" : "failed",
            exitCode: result.success ? 0 : 1,
            stdout: result.message ?? "",
            stderr: result.success ? "" : (result.message ?? "Unknown error"),
            executedAt: result.executedAt,
            duration: result.duration
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

        AppLogger.shared.info("Successfully reported command result to Kandji")
    }
}

// MARK: - Kandji API Types

private struct KandjiBlueprint: Codable {
    let id: String
    let name: String
    let active: Bool
    let description: String?
    let parameters: [String: Any]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case active
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        description = try container.decodeIfPresent(String.self, forKey: .description)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        parameters = nil  // Skip complex parameter parsing for now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(active, forKey: .active)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

private struct KandjiDeviceUpdate: Codable {
    let customAttributes: [String: String]

    enum CodingKeys: String, CodingKey {
        case customAttributes = "custom_attributes"
    }
}

private struct KandjiCustomScript: Codable {
    let id: String
    let name: String
    let description: String?
    let active: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case active
        case createdAt = "created_at"
    }
}

private struct KandjiScriptResult: Codable {
    let status: String
    let exitCode: Int
    let stdout: String
    let stderr: String
    let executedAt: Date
    let duration: TimeInterval

    enum CodingKeys: String, CodingKey {
        case status
        case exitCode = "exit_code"
        case stdout
        case stderr
        case executedAt = "executed_at"
        case duration
    }
}

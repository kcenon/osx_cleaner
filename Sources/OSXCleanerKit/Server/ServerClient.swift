// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

/// Client for communicating with the central management server
public actor ServerClient: ManagementServerProtocol {

    // MARK: - Properties

    public let serverURL: URL
    private let config: ServerClientConfig
    private let logger: Logger
    private let urlSession: URLSession

    private var authToken: String?
    private var tokenExpiresAt: Date?
    private var agentId: UUID?
    private var _connectionState: AgentConnectionState = .pending
    private weak var delegate: ManagementServerDelegate?

    // MARK: - ManagementServerProtocol Properties

    public var connectionState: AgentConnectionState {
        _connectionState
    }

    public var isRegistered: Bool {
        authToken != nil && agentId != nil
    }

    // MARK: - Initialization

    public init(config: ServerClientConfig, delegate: ManagementServerDelegate? = nil) {
        self.serverURL = config.serverURL
        self.config = config
        self.delegate = delegate
        self.logger = Logger(label: "com.osxcleaner.server-client")

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.requestTimeout
        sessionConfig.timeoutIntervalForResource = config.requestTimeout * 2
        self.urlSession = URLSession(configuration: sessionConfig)
    }

    // MARK: - Registration

    public func register(identity: AgentIdentity) async throws -> RegistrationResult {
        logger.info("Registering agent with server", metadata: [
            "hostname": "\(identity.hostname)",
            "serverURL": "\(serverURL)"
        ])

        let request = RegistrationRequest(
            identity: identity,
            capabilities: RegistrationRequest.defaultCapabilities
        )

        let message = ServerMessage(
            type: .register,
            agentId: identity.id,
            payload: request
        )

        let response: ServerResponse<RegistrationResult> = try await sendMessage(
            message,
            to: "/api/v1/agents/register"
        )

        guard response.success, let result = response.data else {
            let error = response.error ?? .serverError
            throw ServerCommunicationError.authenticationFailed(error.message)
        }

        if result.success {
            self.authToken = result.authToken
            self.tokenExpiresAt = result.tokenExpiresAt
            self.agentId = result.agentId
            self._connectionState = .active

            await delegate?.serverConnectionStateChanged(.active)

            logger.info("Agent registered successfully", metadata: [
                "agentId": "\(result.agentId?.uuidString ?? "unknown")"
            ])
        } else {
            self._connectionState = .rejected
            await delegate?.serverConnectionStateChanged(.rejected)
        }

        return result
    }

    public func unregister() async throws {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        logger.info("Unregistering agent from server")

        _ = try await sendAuthenticatedRequest(
            method: "DELETE",
            path: "/api/v1/agents/\(agentId.uuidString)"
        ) as ServerResponse<EmptyResponse>

        self.authToken = nil
        self.tokenExpiresAt = nil
        self.agentId = nil
        self._connectionState = .disconnected

        await delegate?.serverConnectionStateChanged(.disconnected)
    }

    // MARK: - Heartbeat

    public func heartbeat(status: AgentStatus) async throws -> HeartbeatResponse {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let request = HeartbeatRequest(status: status)
        let message = ServerMessage(
            type: .heartbeat,
            agentId: agentId,
            payload: request
        )

        let response: ServerResponse<HeartbeatResponse> = try await sendAuthenticatedMessage(
            message,
            to: "/api/v1/agents/\(agentId.uuidString)/heartbeat"
        )

        guard response.success, let result = response.data else {
            let error = response.error ?? .serverError
            throw ServerCommunicationError.serverError(error)
        }

        return result
    }

    // MARK: - Policies

    public func fetchPolicies(lastSyncVersion: Int?) async throws -> PolicyFetchResponse {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        var path = "/api/v1/agents/\(agentId.uuidString)/policies"
        if let version = lastSyncVersion {
            path += "?since=\(version)"
        }

        let response: ServerResponse<PolicyFetchResponse> = try await sendAuthenticatedRequest(
            method: "GET",
            path: path
        )

        guard response.success, let result = response.data else {
            let error = response.error ?? .serverError
            throw ServerCommunicationError.serverError(error)
        }

        return result
    }

    public func reportPolicyExecution(policyId: String, result: PolicyExecutionResult) async throws {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let _: ServerResponse<EmptyResponse> = try await sendAuthenticatedRequest(
            method: "POST",
            path: "/api/v1/agents/\(agentId.uuidString)/policies/\(policyId)/results",
            body: result
        )
    }

    // MARK: - Commands

    public func fetchPendingCommands() async throws -> [RemoteCommand] {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let response: ServerResponse<[RemoteCommand]> = try await sendAuthenticatedRequest(
            method: "GET",
            path: "/api/v1/agents/\(agentId.uuidString)/commands/pending"
        )

        return response.data ?? []
    }

    public func reportCommandResult(_ result: CommandResult) async throws {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let _: ServerResponse<EmptyResponse> = try await sendAuthenticatedRequest(
            method: "POST",
            path: "/api/v1/agents/\(agentId.uuidString)/commands/\(result.commandId.uuidString)/result",
            body: result
        )
    }

    // MARK: - Audit Logs

    public func uploadAuditEvents(_ events: [AuditEvent]) async throws {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let _: ServerResponse<EmptyResponse> = try await sendAuthenticatedRequest(
            method: "POST",
            path: "/api/v1/agents/\(agentId.uuidString)/audit/events",
            body: events
        )

        logger.debug("Uploaded \(events.count) audit events to server")
    }

    // MARK: - Status

    public func reportStatus(_ status: AgentStatus) async throws {
        guard let agentId = agentId else {
            throw ServerCommunicationError.notRegistered
        }

        let message = ServerMessage(
            type: .statusReport,
            agentId: agentId,
            payload: status
        )

        let _: ServerResponse<EmptyResponse> = try await sendAuthenticatedMessage(
            message,
            to: "/api/v1/agents/\(agentId.uuidString)/status"
        )
    }

    // MARK: - Private Helpers

    private func sendMessage<P: Codable & Sendable, R: Codable & Sendable>(
        _ message: ServerMessage<P>,
        to path: String
    ) async throws -> ServerResponse<R> {
        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ProtocolVersion.current.string, forHTTPHeaderField: "X-Protocol-Version")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(message)

        return try await executeRequest(request)
    }

    private func sendAuthenticatedMessage<P: Codable & Sendable, R: Codable & Sendable>(
        _ message: ServerMessage<P>,
        to path: String
    ) async throws -> ServerResponse<R> {
        guard let token = authToken else {
            throw ServerCommunicationError.notRegistered
        }

        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ProtocolVersion.current.string, forHTTPHeaderField: "X-Protocol-Version")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(message)

        return try await executeRequest(request)
    }

    private func sendAuthenticatedRequest<R: Codable & Sendable>(
        method: String,
        path: String
    ) async throws -> ServerResponse<R> {
        guard let token = authToken else {
            throw ServerCommunicationError.notRegistered
        }

        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ProtocolVersion.current.string, forHTTPHeaderField: "X-Protocol-Version")

        return try await executeRequest(request)
    }

    private func sendAuthenticatedRequest<B: Codable & Sendable, R: Codable & Sendable>(
        method: String,
        path: String,
        body: B
    ) async throws -> ServerResponse<R> {
        guard let token = authToken else {
            throw ServerCommunicationError.notRegistered
        }

        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ProtocolVersion.current.string, forHTTPHeaderField: "X-Protocol-Version")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        return try await executeRequest(request)
    }

    private func executeRequest<R: Codable & Sendable>(_ request: URLRequest) async throws -> ServerResponse<R> {
        var lastError: Error?

        for attempt in 0..<config.maxRetryAttempts {
            do {
                let (data, httpResponse) = try await urlSession.data(for: request)

                guard let response = httpResponse as? HTTPURLResponse else {
                    throw ServerCommunicationError.invalidResponse
                }

                // Check for auth errors
                if response.statusCode == 401 {
                    self._connectionState = .disconnected
                    await delegate?.serverConnectionStateChanged(.disconnected)
                    throw ServerCommunicationError.authenticationFailed("Token expired or invalid")
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let serverResponse = try decoder.decode(ServerResponse<R>.self, from: data)
                return serverResponse

            } catch let error as URLError where error.code == .timedOut {
                lastError = ServerCommunicationError.requestTimeout
            } catch let error as URLError where error.code == .notConnectedToInternet {
                lastError = ServerCommunicationError.networkUnavailable
            } catch {
                lastError = error
            }

            // Wait before retry
            if attempt < config.maxRetryAttempts - 1 {
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * 1_000_000_000))
            }
        }

        if let error = lastError as? ServerCommunicationError {
            await delegate?.serverDidEncounterError(error)
            throw error
        }

        let error = ServerCommunicationError.connectionFailed(lastError?.localizedDescription ?? "Unknown error")
        await delegate?.serverDidEncounterError(error)
        throw error
    }
}

// MARK: - Helper Types

/// Empty response for endpoints that don't return data
public struct EmptyResponse: Codable, Sendable {}

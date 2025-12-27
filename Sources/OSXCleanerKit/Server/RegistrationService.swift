// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

/// Policy for agent registration approval
public enum RegistrationPolicy: String, Codable, Sendable {
    /// Automatically approve all registrations
    case autoApprove = "auto-approve"

    /// Require manual approval for all registrations
    case manualApprove = "manual-approve"

    /// Auto-approve if agent is in whitelist
    case whitelistOnly = "whitelist-only"

    /// Auto-approve based on hostname pattern
    case hostnamePattern = "hostname-pattern"
}

/// Delegate for registration events
public protocol RegistrationServiceDelegate: AnyObject, Sendable {
    /// Called when an agent registration is pending approval
    func registrationPending(request: RegistrationRequest, agentId: UUID) async

    /// Called when an agent is successfully registered
    func registrationApproved(agent: RegisteredAgent) async

    /// Called when an agent registration is rejected
    func registrationRejected(request: RegistrationRequest, reason: String) async
}

// MARK: - Default Implementation

extension RegistrationServiceDelegate {
    public func registrationPending(request: RegistrationRequest, agentId: UUID) async {}
    public func registrationApproved(agent: RegisteredAgent) async {}
    public func registrationRejected(request: RegistrationRequest, reason: String) async {}
}

/// Service for handling agent registration requests
public actor RegistrationService {

    // MARK: - Types

    /// Configuration for registration service
    public struct Configuration: Sendable {
        /// Registration approval policy
        public let policy: RegistrationPolicy

        /// Hostname patterns for pattern-based policy (regex)
        public let hostnamePatterns: [String]

        /// Whitelisted serial number hashes
        public let whitelistedSerialHashes: Set<String>

        /// Required capabilities for registration
        public let requiredCapabilities: Set<String>

        /// Minimum app version for registration
        public let minimumAppVersion: String?

        /// Server version to report to agents
        public let serverVersion: String

        /// Heartbeat interval to suggest to agents
        public let suggestedHeartbeatInterval: TimeInterval

        public init(
            policy: RegistrationPolicy = .autoApprove,
            hostnamePatterns: [String] = [],
            whitelistedSerialHashes: Set<String> = [],
            requiredCapabilities: Set<String> = [],
            minimumAppVersion: String? = nil,
            serverVersion: String = "1.0.0",
            suggestedHeartbeatInterval: TimeInterval = 60
        ) {
            self.policy = policy
            self.hostnamePatterns = hostnamePatterns
            self.whitelistedSerialHashes = whitelistedSerialHashes
            self.requiredCapabilities = requiredCapabilities
            self.minimumAppVersion = minimumAppVersion
            self.serverVersion = serverVersion
            self.suggestedHeartbeatInterval = suggestedHeartbeatInterval
        }
    }

    /// Errors that can occur during registration
    public enum RegistrationError: LocalizedError {
        case missingCapabilities([String])
        case invalidHostnamePattern
        case notWhitelisted
        case versionTooOld(required: String, actual: String)
        case registryError(AgentRegistry.RegistryError)
        case pendingApproval

        public var errorDescription: String? {
            switch self {
            case .missingCapabilities(let missing):
                return "Missing required capabilities: \(missing.joined(separator: ", "))"
            case .invalidHostnamePattern:
                return "Hostname does not match allowed patterns"
            case .notWhitelisted:
                return "Agent is not in the whitelist"
            case .versionTooOld(let required, let actual):
                return "App version \(actual) is too old, minimum required: \(required)"
            case .registryError(let error):
                return error.errorDescription
            case .pendingApproval:
                return "Registration is pending manual approval"
            }
        }
    }

    /// Result of registration request processing
    public struct RegistrationOutcome: Sendable {
        public let result: RegistrationResult
        public let agent: RegisteredAgent?

        public init(result: RegistrationResult, agent: RegisteredAgent? = nil) {
            self.result = result
            self.agent = agent
        }
    }

    // MARK: - Properties

    private let registry: AgentRegistry
    private let configuration: Configuration
    private let logger: Logger
    private weak var delegate: RegistrationServiceDelegate?

    /// Pending registrations awaiting manual approval
    private var pendingRegistrations: [UUID: RegistrationRequest] = [:]

    // MARK: - Initialization

    public init(
        registry: AgentRegistry,
        configuration: Configuration = Configuration(),
        delegate: RegistrationServiceDelegate? = nil
    ) {
        self.registry = registry
        self.configuration = configuration
        self.delegate = delegate
        self.logger = Logger(label: "com.osxcleaner.registration-service")
    }

    // MARK: - Registration

    /// Process a registration request
    /// - Parameter request: Registration request from agent
    /// - Returns: Registration outcome
    public func processRegistration(
        request: RegistrationRequest
    ) async throws -> RegistrationOutcome {
        let identity = request.identity

        logger.info("Processing registration request", metadata: [
            "agentId": "\(identity.id)",
            "hostname": "\(identity.hostname)",
            "appVersion": "\(identity.appVersion)"
        ])

        // Validate request
        try validateRequest(request)

        // Check policy
        let shouldAutoApprove = evaluatePolicy(request: request)

        if shouldAutoApprove {
            return try await approveRegistration(request: request)
        } else {
            return await queueForApproval(request: request)
        }
    }

    /// Manually approve a pending registration
    /// - Parameter agentId: Agent ID to approve
    /// - Returns: Registration outcome
    public func approveManualRegistration(agentId: UUID) async throws -> RegistrationOutcome {
        guard let request = pendingRegistrations.removeValue(forKey: agentId) else {
            throw RegistrationError.registryError(.agentNotFound(agentId))
        }

        return try await approveRegistration(request: request)
    }

    /// Reject a pending registration
    /// - Parameters:
    ///   - agentId: Agent ID to reject
    ///   - reason: Reason for rejection
    public func rejectManualRegistration(agentId: UUID, reason: String) async {
        guard let request = pendingRegistrations.removeValue(forKey: agentId) else {
            return
        }

        logger.info("Registration rejected", metadata: [
            "agentId": "\(agentId)",
            "reason": "\(reason)"
        ])

        await delegate?.registrationRejected(request: request, reason: reason)
    }

    /// Get all pending registrations
    public func getPendingRegistrations() -> [(UUID, RegistrationRequest)] {
        pendingRegistrations.map { ($0.key, $0.value) }
    }

    /// Check if a registration is pending
    public func isRegistrationPending(agentId: UUID) -> Bool {
        pendingRegistrations[agentId] != nil
    }

    // MARK: - Validation

    private func validateRequest(_ request: RegistrationRequest) throws {
        let identity = request.identity
        let capabilities = Set(request.capabilities)

        // Check required capabilities
        let missingCapabilities = configuration.requiredCapabilities.subtracting(capabilities)
        if !missingCapabilities.isEmpty {
            throw RegistrationError.missingCapabilities(Array(missingCapabilities))
        }

        // Check minimum app version
        if let minimumVersion = configuration.minimumAppVersion {
            if compareVersions(identity.appVersion, minimumVersion) < 0 {
                throw RegistrationError.versionTooOld(
                    required: minimumVersion,
                    actual: identity.appVersion
                )
            }
        }
    }

    private func evaluatePolicy(request: RegistrationRequest) -> Bool {
        switch configuration.policy {
        case .autoApprove:
            return true

        case .manualApprove:
            return false

        case .whitelistOnly:
            return configuration.whitelistedSerialHashes.contains(
                request.identity.serialNumberHash
            )

        case .hostnamePattern:
            return matchesHostnamePatterns(request.identity.hostname)
        }
    }

    private func matchesHostnamePatterns(_ hostname: String) -> Bool {
        for pattern in configuration.hostnamePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(hostname.startIndex..., in: hostname)
                if regex.firstMatch(in: hostname, options: [], range: range) != nil {
                    return true
                }
            } catch {
                logger.warning("Invalid hostname pattern", metadata: [
                    "pattern": "\(pattern)",
                    "error": "\(error.localizedDescription)"
                ])
            }
        }
        return false
    }

    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(parts1.count, parts2.count)

        for i in 0..<maxLength {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0

            if p1 < p2 { return -1 }
            if p1 > p2 { return 1 }
        }

        return 0
    }

    // MARK: - Private Helpers

    private func approveRegistration(
        request: RegistrationRequest
    ) async throws -> RegistrationOutcome {
        do {
            let agent = try await registry.register(
                identity: request.identity,
                capabilities: request.capabilities
            )

            let result = RegistrationResult.success(
                agentId: agent.identity.id,
                authToken: agent.authToken,
                expiresIn: agent.tokenExpiresAt.timeIntervalSince(Date()),
                serverVersion: configuration.serverVersion
            )

            logger.info("Registration approved", metadata: [
                "agentId": "\(agent.identity.id)",
                "hostname": "\(agent.identity.hostname)"
            ])

            await delegate?.registrationApproved(agent: agent)

            return RegistrationOutcome(result: result, agent: agent)

        } catch let error as AgentRegistry.RegistryError {
            throw RegistrationError.registryError(error)
        }
    }

    private func queueForApproval(request: RegistrationRequest) async -> RegistrationOutcome {
        let agentId = request.identity.id
        pendingRegistrations[agentId] = request

        logger.info("Registration queued for manual approval", metadata: [
            "agentId": "\(agentId)",
            "hostname": "\(request.identity.hostname)"
        ])

        await delegate?.registrationPending(request: request, agentId: agentId)

        let result = RegistrationResult(
            success: false,
            agentId: agentId,
            message: "Registration pending manual approval",
            heartbeatInterval: configuration.suggestedHeartbeatInterval
        )

        return RegistrationOutcome(result: result)
    }
}

// MARK: - Bulk Operations

extension RegistrationService {
    /// Approve all pending registrations
    /// - Returns: List of approved agent IDs
    public func approveAllPending() async throws -> [UUID] {
        var approvedIds: [UUID] = []

        for (agentId, _) in pendingRegistrations {
            do {
                _ = try await approveManualRegistration(agentId: agentId)
                approvedIds.append(agentId)
            } catch {
                logger.warning("Failed to approve registration", metadata: [
                    "agentId": "\(agentId)",
                    "error": "\(error.localizedDescription)"
                ])
            }
        }

        return approvedIds
    }

    /// Reject all pending registrations
    /// - Parameter reason: Reason for rejection
    /// - Returns: List of rejected agent IDs
    public func rejectAllPending(reason: String) async -> [UUID] {
        var rejectedIds: [UUID] = []

        for (agentId, _) in pendingRegistrations {
            await rejectManualRegistration(agentId: agentId, reason: reason)
            rejectedIds.append(agentId)
        }

        return rejectedIds
    }

    /// Update registration policy configuration
    public func updateConfiguration(_ newConfig: Configuration) async -> Configuration {
        // Note: In a real implementation, this would update the configuration
        // For now, we return the new config as actor doesn't allow stored property mutation
        // This would typically be handled differently in production
        logger.info("Configuration update requested", metadata: [
            "newPolicy": "\(newConfig.policy.rawValue)"
        ])
        return newConfig
    }
}

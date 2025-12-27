// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

// MARK: - Access Control Errors

/// Errors that can occur during access control
public enum AccessControlError: LocalizedError {
    case unauthorized
    case forbidden(Permission)
    case invalidToken
    case tokenExpired
    case userNotFound
    case userDisabled
    case insufficientPrivileges(required: Role, actual: Role)
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required"
        case .forbidden(let permission):
            return "Access denied: missing permission '\(permission.rawValue)'"
        case .invalidToken:
            return "Invalid authentication token"
        case .tokenExpired:
            return "Authentication token has expired"
        case .userNotFound:
            return "User not found"
        case .userDisabled:
            return "User account is disabled"
        case .insufficientPrivileges(let required, let actual):
            return "Insufficient privileges: required \(required.displayName), have \(actual.displayName)"
        case .sessionExpired:
            return "Session has expired"
        }
    }

    /// HTTP status code for this error
    public var httpStatusCode: Int {
        switch self {
        case .unauthorized, .invalidToken, .tokenExpired, .sessionExpired:
            return 401
        case .forbidden, .insufficientPrivileges, .userDisabled:
            return 403
        case .userNotFound:
            return 404
        }
    }
}

// MARK: - Access Request

/// Represents an access request to be validated
public struct AccessRequest: Sendable {
    /// Request identifier
    public let id: UUID

    /// Bearer token from authorization header
    public let token: String?

    /// Requested resource path
    public let resource: String

    /// HTTP method
    public let method: String

    /// Client IP address
    public let clientIP: String?

    /// User agent string
    public let userAgent: String?

    /// Request timestamp
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        token: String?,
        resource: String,
        method: String,
        clientIP: String? = nil,
        userAgent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.token = token
        self.resource = resource
        self.method = method
        self.clientIP = clientIP
        self.userAgent = userAgent
        self.timestamp = timestamp
    }
}

// MARK: - Access Result

/// Result of an access control check
public struct AccessResult: Sendable {
    /// Whether access was granted
    public let granted: Bool

    /// User ID if authenticated
    public let userId: UUID?

    /// Username if authenticated
    public let username: String?

    /// User's role if authenticated
    public let role: Role?

    /// Denial reason if access was denied
    public let denialReason: AccessControlError?

    /// Request that was evaluated
    public let request: AccessRequest

    /// Evaluation timestamp
    public let evaluatedAt: Date

    public init(
        granted: Bool,
        userId: UUID? = nil,
        username: String? = nil,
        role: Role? = nil,
        denialReason: AccessControlError? = nil,
        request: AccessRequest,
        evaluatedAt: Date = Date()
    ) {
        self.granted = granted
        self.userId = userId
        self.username = username
        self.role = role
        self.denialReason = denialReason
        self.request = request
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - Access Policy

/// Defines access requirements for a resource
public struct AccessPolicy: Sendable {
    /// Resource pattern (supports wildcards)
    public let resourcePattern: String

    /// HTTP methods this policy applies to
    public let methods: Set<String>

    /// Required permissions (any of these)
    public let requiredPermissions: Set<Permission>

    /// Minimum required role
    public let minimumRole: Role?

    /// Whether authentication is required
    public let requiresAuthentication: Bool

    public init(
        resourcePattern: String,
        methods: Set<String> = ["GET", "POST", "PUT", "DELETE", "PATCH"],
        requiredPermissions: Set<Permission> = [],
        minimumRole: Role? = nil,
        requiresAuthentication: Bool = true
    ) {
        self.resourcePattern = resourcePattern
        self.methods = methods
        self.requiredPermissions = requiredPermissions
        self.minimumRole = minimumRole
        self.requiresAuthentication = requiresAuthentication
    }

    /// Check if this policy matches a resource and method
    public func matches(resource: String, method: String) -> Bool {
        guard methods.contains(method.uppercased()) else { return false }
        return matchesPattern(resource: resource)
    }

    private func matchesPattern(resource: String) -> Bool {
        let pattern = resourcePattern

        // Exact match
        if pattern == resource {
            return true
        }

        // Wildcard matching
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return resource.hasPrefix(prefix)
        }

        // Path parameter matching (e.g., /agents/{id} matches /agents/123)
        let patternParts = pattern.split(separator: "/")
        let resourceParts = resource.split(separator: "/")

        guard patternParts.count == resourceParts.count else { return false }

        for (patternPart, resourcePart) in zip(patternParts, resourceParts) {
            if patternPart.hasPrefix("{") && patternPart.hasSuffix("}") {
                continue  // Parameter placeholder matches anything
            }
            if patternPart != resourcePart {
                return false
            }
        }

        return true
    }
}

// MARK: - Access Audit Entry

/// Audit log entry for access control events
public struct AccessAuditEntry: Codable, Sendable {
    /// Entry identifier
    public let id: UUID

    /// Request identifier
    public let requestId: UUID

    /// User ID if authenticated
    public let userId: UUID?

    /// Username if authenticated
    public let username: String?

    /// User's role if authenticated
    public let role: String?

    /// Requested resource
    public let resource: String

    /// HTTP method
    public let method: String

    /// Whether access was granted
    public let granted: Bool

    /// Denial reason if applicable
    public let denialReason: String?

    /// Client IP address
    public let clientIP: String?

    /// User agent
    public let userAgent: String?

    /// Timestamp
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        requestId: UUID,
        userId: UUID?,
        username: String?,
        role: String?,
        resource: String,
        method: String,
        granted: Bool,
        denialReason: String? = nil,
        clientIP: String? = nil,
        userAgent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.userId = userId
        self.username = username
        self.role = role
        self.resource = resource
        self.method = method
        self.granted = granted
        self.denialReason = denialReason
        self.clientIP = clientIP
        self.userAgent = userAgent
        self.timestamp = timestamp
    }
}

// MARK: - Access Controller Configuration

/// Configuration for the access controller
public struct AccessControllerConfig: Sendable {
    /// Whether to log all access attempts
    public let logAllAccess: Bool

    /// Whether to log denied access attempts
    public let logDeniedAccess: Bool

    /// Maximum audit entries to keep in memory
    public let maxAuditEntries: Int

    /// Default policy for unmatched resources
    public let defaultPolicy: DefaultAccessPolicy

    public init(
        logAllAccess: Bool = true,
        logDeniedAccess: Bool = true,
        maxAuditEntries: Int = 10000,
        defaultPolicy: DefaultAccessPolicy = .deny
    ) {
        self.logAllAccess = logAllAccess
        self.logDeniedAccess = logDeniedAccess
        self.maxAuditEntries = maxAuditEntries
        self.defaultPolicy = defaultPolicy
    }
}

/// Default policy for resources without explicit policies
public enum DefaultAccessPolicy: Sendable {
    case allow
    case deny
    case authenticatedOnly
}

// MARK: - Access Controller

/// Actor responsible for validating access requests
public actor AccessController {

    // MARK: - Properties

    private let configuration: AccessControllerConfig
    private let jwtProvider: JWTProvider
    private let logger: Logger

    /// Registered access policies
    private var policies: [AccessPolicy] = []

    /// Audit log entries
    private var auditLog: [AccessAuditEntry] = []

    /// Active sessions cache (user ID -> last validated claims)
    private var sessionCache: [UUID: JWTClaims] = [:]

    // MARK: - Initialization

    public init(
        configuration: AccessControllerConfig = AccessControllerConfig(),
        jwtProvider: JWTProvider
    ) {
        self.configuration = configuration
        self.jwtProvider = jwtProvider
        self.logger = Logger(label: "com.osxcleaner.access-controller")

        // Register default policies
        Task {
            await registerDefaultPolicies()
        }
    }

    // MARK: - Policy Management

    /// Register an access policy
    public func registerPolicy(_ policy: AccessPolicy) {
        policies.append(policy)
        logger.debug("Registered access policy", metadata: [
            "pattern": "\(policy.resourcePattern)",
            "methods": "\(policy.methods.joined(separator: ", "))"
        ])
    }

    /// Register multiple policies
    public func registerPolicies(_ newPolicies: [AccessPolicy]) {
        policies.append(contentsOf: newPolicies)
    }

    /// Remove all policies matching a pattern
    public func removePolicies(matching pattern: String) {
        policies.removeAll { $0.resourcePattern == pattern }
    }

    /// Clear all policies
    public func clearPolicies() {
        policies.removeAll()
    }

    /// Get all registered policies
    public func allPolicies() -> [AccessPolicy] {
        policies
    }

    // MARK: - Access Validation

    /// Validate an access request
    public func validate(_ request: AccessRequest) async -> AccessResult {
        // Find matching policy
        let matchingPolicy = policies.first { $0.matches(resource: request.resource, method: request.method) }

        // Check if authentication is required
        let requiresAuth = matchingPolicy?.requiresAuthentication ?? (configuration.defaultPolicy != .allow)

        // Handle unauthenticated requests
        guard let token = request.token else {
            if requiresAuth {
                let result = AccessResult(
                    granted: false,
                    denialReason: .unauthorized,
                    request: request
                )
                await recordAudit(result: result)
                return result
            } else {
                let result = AccessResult(granted: true, request: request)
                await recordAudit(result: result)
                return result
            }
        }

        // Validate token
        do {
            let claims = try await jwtProvider.validate(token: token)

            // Check token type
            guard claims.tokenType == .access else {
                let result = AccessResult(
                    granted: false,
                    denialReason: .invalidToken,
                    request: request
                )
                await recordAudit(result: result)
                return result
            }

            // Extract user info
            guard let userId = UUID(uuidString: claims.sub) else {
                let result = AccessResult(
                    granted: false,
                    denialReason: .invalidToken,
                    request: request
                )
                await recordAudit(result: result)
                return result
            }

            // Check role requirement
            if let minimumRole = matchingPolicy?.minimumRole {
                if !claims.role.hasAtLeastPrivilegesOf(minimumRole) {
                    let result = AccessResult(
                        granted: false,
                        userId: userId,
                        username: claims.username,
                        role: claims.role,
                        denialReason: .insufficientPrivileges(required: minimumRole, actual: claims.role),
                        request: request
                    )
                    await recordAudit(result: result)
                    return result
                }
            }

            // Check permission requirements
            if let policy = matchingPolicy, !policy.requiredPermissions.isEmpty {
                let hasPermission = policy.requiredPermissions.contains { claims.role.hasPermission($0) }
                if !hasPermission {
                    let missingPermission = policy.requiredPermissions.first!
                    let result = AccessResult(
                        granted: false,
                        userId: userId,
                        username: claims.username,
                        role: claims.role,
                        denialReason: .forbidden(missingPermission),
                        request: request
                    )
                    await recordAudit(result: result)
                    return result
                }
            }

            // Cache session
            sessionCache[userId] = claims

            // Access granted
            let result = AccessResult(
                granted: true,
                userId: userId,
                username: claims.username,
                role: claims.role,
                request: request
            )
            await recordAudit(result: result)

            logger.debug("Access granted", metadata: [
                "userId": "\(userId)",
                "username": "\(claims.username)",
                "resource": "\(request.resource)",
                "method": "\(request.method)"
            ])

            return result

        } catch let error as JWTError {
            let denialReason: AccessControlError = switch error {
            case .tokenExpired: .tokenExpired
            case .invalidSignature: .invalidToken
            default: .invalidToken
            }

            let result = AccessResult(
                granted: false,
                denialReason: denialReason,
                request: request
            )
            await recordAudit(result: result)
            return result
        } catch {
            let result = AccessResult(
                granted: false,
                denialReason: .invalidToken,
                request: request
            )
            await recordAudit(result: result)
            return result
        }
    }

    /// Check if a user has a specific permission
    public func checkPermission(
        token: String,
        permission: Permission
    ) async -> Bool {
        do {
            let claims = try await jwtProvider.validate(token: token)
            return claims.role.hasPermission(permission)
        } catch {
            return false
        }
    }

    /// Check if a user has a minimum role level
    public func checkRole(
        token: String,
        minimumRole: Role
    ) async -> Bool {
        do {
            let claims = try await jwtProvider.validate(token: token)
            return claims.role.hasAtLeastPrivilegesOf(minimumRole)
        } catch {
            return false
        }
    }

    // MARK: - Audit Log

    /// Get recent audit entries
    public func recentAuditEntries(limit: Int = 100) -> [AccessAuditEntry] {
        Array(auditLog.prefix(limit))
    }

    /// Get audit entries for a specific user
    public func auditEntries(forUser userId: UUID, limit: Int = 100) -> [AccessAuditEntry] {
        auditLog.filter { $0.userId == userId }.prefix(limit).map { $0 }
    }

    /// Get denied access attempts
    public func deniedAccessAttempts(limit: Int = 100) -> [AccessAuditEntry] {
        auditLog.filter { !$0.granted }.prefix(limit).map { $0 }
    }

    /// Clear audit log
    public func clearAuditLog() {
        auditLog.removeAll()
        logger.info("Cleared access audit log")
    }

    /// Export audit log as JSON
    public func exportAuditLog() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(auditLog)
    }

    // MARK: - Session Management

    /// Get cached session for a user
    public func session(for userId: UUID) -> JWTClaims? {
        sessionCache[userId]
    }

    /// Invalidate a user's session
    public func invalidateSession(for userId: UUID) {
        sessionCache.removeValue(forKey: userId)
        logger.debug("Session invalidated", metadata: ["userId": "\(userId)"])
    }

    /// Invalidate all sessions
    public func invalidateAllSessions() {
        sessionCache.removeAll()
        logger.info("All sessions invalidated")
    }

    /// Number of active sessions
    public var activeSessionCount: Int {
        sessionCache.count
    }

    // MARK: - Statistics

    /// Total number of audit entries
    public var auditEntryCount: Int {
        auditLog.count
    }

    /// Number of denied access attempts
    public var deniedAccessCount: Int {
        auditLog.filter { !$0.granted }.count
    }

    /// Number of registered policies
    public var policyCount: Int {
        policies.count
    }

    // MARK: - Private Methods

    private func registerDefaultPolicies() {
        // Public endpoints (no auth required)
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/health",
            methods: ["GET"],
            requiresAuthentication: false
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/auth/login",
            methods: ["POST"],
            requiresAuthentication: false
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/auth/refresh",
            methods: ["POST"],
            requiresAuthentication: false
        ))

        // Agent endpoints
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/agents",
            methods: ["GET"],
            requiredPermissions: [.viewAgents]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/agents/register",
            methods: ["POST"],
            requiredPermissions: [.registerAgents]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/agents/{id}",
            methods: ["GET"],
            requiredPermissions: [.viewAgents]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/agents/{id}",
            methods: ["DELETE"],
            requiredPermissions: [.unregisterAgents]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/agents/{id}/command",
            methods: ["POST"],
            requiredPermissions: [.commandAgents]
        ))

        // Policy endpoints
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies",
            methods: ["GET"],
            requiredPermissions: [.viewPolicies]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies",
            methods: ["POST"],
            requiredPermissions: [.createPolicies]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies/{id}",
            methods: ["GET"],
            requiredPermissions: [.viewPolicies]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies/{id}",
            methods: ["PUT", "PATCH"],
            requiredPermissions: [.updatePolicies]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies/{id}",
            methods: ["DELETE"],
            requiredPermissions: [.deletePolicies]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/policies/{id}/deploy",
            methods: ["POST"],
            requiredPermissions: [.deployPolicies]
        ))

        // Report endpoints
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/reports/*",
            methods: ["GET"],
            requiredPermissions: [.viewReports]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/reports/*/export",
            methods: ["POST"],
            requiredPermissions: [.exportReports]
        ))

        // Audit endpoints
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/audit/logs",
            methods: ["GET"],
            requiredPermissions: [.viewAuditLogs]
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/audit/logs/export",
            methods: ["POST"],
            requiredPermissions: [.exportAuditLogs]
        ))

        // User management endpoints (Admin only)
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/users",
            methods: ["GET"],
            requiredPermissions: [.viewUsers],
            minimumRole: .admin
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/users",
            methods: ["POST"],
            requiredPermissions: [.createUsers],
            minimumRole: .admin
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/users/{id}",
            methods: ["PUT", "PATCH"],
            requiredPermissions: [.updateUsers],
            minimumRole: .admin
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/users/{id}",
            methods: ["DELETE"],
            requiredPermissions: [.deleteUsers],
            minimumRole: .admin
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/users/{id}/role",
            methods: ["PUT"],
            requiredPermissions: [.manageRoles],
            minimumRole: .admin
        ))

        // System configuration (Admin only)
        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/config",
            methods: ["GET"],
            requiredPermissions: [.viewConfig],
            minimumRole: .admin
        ))

        registerPolicy(AccessPolicy(
            resourcePattern: "/api/v1/config",
            methods: ["PUT", "PATCH"],
            requiredPermissions: [.updateConfig],
            minimumRole: .admin
        ))

        logger.info("Registered default access policies", metadata: [
            "policyCount": "\(policies.count)"
        ])
    }

    private func recordAudit(result: AccessResult) async {
        let shouldLog = configuration.logAllAccess ||
            (configuration.logDeniedAccess && !result.granted)

        guard shouldLog else { return }

        let entry = AccessAuditEntry(
            requestId: result.request.id,
            userId: result.userId,
            username: result.username,
            role: result.role?.rawValue,
            resource: result.request.resource,
            method: result.request.method,
            granted: result.granted,
            denialReason: result.denialReason?.errorDescription,
            clientIP: result.request.clientIP,
            userAgent: result.request.userAgent,
            timestamp: result.evaluatedAt
        )

        auditLog.insert(entry, at: 0)

        // Memory management
        if auditLog.count > configuration.maxAuditEntries {
            auditLog = Array(auditLog.prefix(configuration.maxAuditEntries))
        }

        // Log denied access at warning level
        if !result.granted {
            logger.warning("Access denied", metadata: [
                "resource": "\(result.request.resource)",
                "method": "\(result.request.method)",
                "reason": "\(result.denialReason?.errorDescription ?? "unknown")",
                "clientIP": "\(result.request.clientIP ?? "unknown")"
            ])
        }
    }
}

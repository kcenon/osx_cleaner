// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - Role

/// Defines user roles for role-based access control (RBAC)
public enum Role: String, Codable, Sendable, CaseIterable {
    /// Full access to all features including user management
    case admin

    /// Can manage policies and view reports, but cannot manage users
    case `operator`

    /// Read-only access to reports and status information
    case viewer

    /// Display name for the role
    public var displayName: String {
        switch self {
        case .admin:
            return "Administrator"
        case .operator:
            return "Operator"
        case .viewer:
            return "Viewer"
        }
    }

    /// Role hierarchy level (higher = more privileges)
    public var hierarchyLevel: Int {
        switch self {
        case .admin:
            return 100
        case .operator:
            return 50
        case .viewer:
            return 10
        }
    }

    /// Check if this role has at least the same privileges as another role
    public func hasAtLeastPrivilegesOf(_ other: Role) -> Bool {
        self.hierarchyLevel >= other.hierarchyLevel
    }

    /// Get all permissions granted to this role
    public var permissions: Set<Permission> {
        switch self {
        case .admin:
            return Set(Permission.allCases)
        case .operator:
            return [
                // Agent permissions
                .viewAgents,
                .registerAgents,
                // Policy permissions
                .viewPolicies,
                .createPolicies,
                .updatePolicies,
                .deployPolicies,
                // Report permissions
                .viewReports,
                .exportReports,
                // Audit permissions
                .viewAuditLogs
            ]
        case .viewer:
            return [
                .viewAgents,
                .viewPolicies,
                .viewReports,
                .viewAuditLogs
            ]
        }
    }

    /// Check if this role has a specific permission
    public func hasPermission(_ permission: Permission) -> Bool {
        permissions.contains(permission)
    }
}

// MARK: - Permission

/// Defines granular permissions for access control
public enum Permission: String, Codable, Sendable, CaseIterable {
    // MARK: - Agent Permissions

    /// View registered agents and their status
    case viewAgents = "agents:view"

    /// Register new agents
    case registerAgents = "agents:register"

    /// Unregister agents
    case unregisterAgents = "agents:unregister"

    /// Send commands to agents
    case commandAgents = "agents:command"

    // MARK: - Policy Permissions

    /// View policies
    case viewPolicies = "policies:view"

    /// Create new policies
    case createPolicies = "policies:create"

    /// Update existing policies
    case updatePolicies = "policies:update"

    /// Delete policies
    case deletePolicies = "policies:delete"

    /// Deploy policies to agents
    case deployPolicies = "policies:deploy"

    // MARK: - Report Permissions

    /// View compliance reports
    case viewReports = "reports:view"

    /// Export reports
    case exportReports = "reports:export"

    // MARK: - Audit Permissions

    /// View audit logs
    case viewAuditLogs = "audit:view"

    /// Export audit logs
    case exportAuditLogs = "audit:export"

    // MARK: - User Management Permissions

    /// View users
    case viewUsers = "users:view"

    /// Create users
    case createUsers = "users:create"

    /// Update users
    case updateUsers = "users:update"

    /// Delete users
    case deleteUsers = "users:delete"

    /// Manage user roles
    case manageRoles = "users:roles"

    // MARK: - System Permissions

    /// View system configuration
    case viewConfig = "config:view"

    /// Update system configuration
    case updateConfig = "config:update"

    /// Display name for the permission
    public var displayName: String {
        switch self {
        case .viewAgents: return "View Agents"
        case .registerAgents: return "Register Agents"
        case .unregisterAgents: return "Unregister Agents"
        case .commandAgents: return "Command Agents"
        case .viewPolicies: return "View Policies"
        case .createPolicies: return "Create Policies"
        case .updatePolicies: return "Update Policies"
        case .deletePolicies: return "Delete Policies"
        case .deployPolicies: return "Deploy Policies"
        case .viewReports: return "View Reports"
        case .exportReports: return "Export Reports"
        case .viewAuditLogs: return "View Audit Logs"
        case .exportAuditLogs: return "Export Audit Logs"
        case .viewUsers: return "View Users"
        case .createUsers: return "Create Users"
        case .updateUsers: return "Update Users"
        case .deleteUsers: return "Delete Users"
        case .manageRoles: return "Manage Roles"
        case .viewConfig: return "View Configuration"
        case .updateConfig: return "Update Configuration"
        }
    }

    /// Category for grouping permissions
    public var category: PermissionCategory {
        switch self {
        case .viewAgents, .registerAgents, .unregisterAgents, .commandAgents:
            return .agents
        case .viewPolicies, .createPolicies, .updatePolicies, .deletePolicies, .deployPolicies:
            return .policies
        case .viewReports, .exportReports:
            return .reports
        case .viewAuditLogs, .exportAuditLogs:
            return .audit
        case .viewUsers, .createUsers, .updateUsers, .deleteUsers, .manageRoles:
            return .users
        case .viewConfig, .updateConfig:
            return .system
        }
    }
}

// MARK: - Permission Category

/// Categories for grouping permissions
public enum PermissionCategory: String, Codable, Sendable, CaseIterable {
    case agents
    case policies
    case reports
    case audit
    case users
    case system

    /// Display name for the category
    public var displayName: String {
        switch self {
        case .agents: return "Agent Management"
        case .policies: return "Policy Management"
        case .reports: return "Reporting"
        case .audit: return "Audit"
        case .users: return "User Management"
        case .system: return "System Configuration"
        }
    }

    /// Get all permissions in this category
    public var permissions: [Permission] {
        Permission.allCases.filter { $0.category == self }
    }
}

// MARK: - User

/// Represents a user in the RBAC system
public struct User: Codable, Sendable, Identifiable {

    // MARK: - Properties

    /// Unique user identifier
    public let id: UUID

    /// Username for login
    public let username: String

    /// User's email address
    public let email: String

    /// User's assigned role
    public var role: Role

    /// Whether the user account is active
    public var isActive: Bool

    /// Timestamp when the user was created
    public let createdAt: Date

    /// Timestamp of the last login
    public var lastLoginAt: Date?

    /// Additional metadata
    public var metadata: [String: String]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        username: String,
        email: String,
        role: Role,
        isActive: Bool = true,
        createdAt: Date = Date(),
        lastLoginAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.metadata = metadata
    }

    // MARK: - Permission Checking

    /// Check if the user has a specific permission
    public func hasPermission(_ permission: Permission) -> Bool {
        guard isActive else { return false }
        return role.hasPermission(permission)
    }

    /// Check if the user has all of the specified permissions
    public func hasAllPermissions(_ permissions: Set<Permission>) -> Bool {
        guard isActive else { return false }
        return permissions.allSatisfy { role.hasPermission($0) }
    }

    /// Check if the user has any of the specified permissions
    public func hasAnyPermission(_ permissions: Set<Permission>) -> Bool {
        guard isActive else { return false }
        return permissions.contains { role.hasPermission($0) }
    }
}

// MARK: - UserCredentials

/// Credentials for user authentication
public struct UserCredentials: Sendable {
    /// Username
    public let username: String

    /// Password (should be hashed before storage)
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// MARK: - PasswordHash

/// Password hashing utilities
public struct PasswordHash: Sendable {

    /// Hash a password using a secure algorithm
    /// Note: In production, use a proper password hashing library like BCrypt
    public static func hash(_ password: String, salt: String) -> String {
        let combined = password + salt
        guard let data = combined.data(using: .utf8) else { return "" }

        // Simple SHA-256 hash (in production, use BCrypt or Argon2)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            CC_SHA256(baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Verify a password against a hash
    public static func verify(_ password: String, hash: String, salt: String) -> Bool {
        return self.hash(password, salt: salt) == hash
    }

    /// Generate a random salt
    public static func generateSalt(length: Int = 32) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// Bridge to CommonCrypto for SHA256
import Darwin

@_silgen_name("CC_SHA256")
private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>?

private typealias CC_LONG = UInt32

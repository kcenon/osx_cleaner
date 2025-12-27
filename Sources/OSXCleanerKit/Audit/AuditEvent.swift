// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Category of audit events
public enum AuditEventCategory: String, Codable, CaseIterable, Sendable {
    /// Cleanup-related events (file deletion, cache cleanup)
    case cleanup

    /// Policy-related events (policy application, compliance check)
    case policy

    /// Security-related events (access control, authentication)
    case security

    /// System-related events (startup, shutdown, configuration)
    case system

    /// User action events (manual operations)
    case user
}

/// Result of an audit event
public enum AuditEventResult: String, Codable, Sendable {
    /// Operation completed successfully
    case success

    /// Operation failed
    case failure

    /// Operation completed with warnings
    case warning

    /// Operation was skipped
    case skipped
}

/// Severity level of an audit event
public enum AuditEventSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
    case critical
}

/// Represents a single audit event for enterprise logging
public struct AuditEvent: Codable, Identifiable, Sendable {
    /// Unique identifier for the event
    public let id: UUID

    /// Timestamp when the event occurred
    public let timestamp: Date

    /// Category of the event
    public let category: AuditEventCategory

    /// Action that was performed
    public let action: String

    /// Who or what performed the action (user, system, or policy name)
    public let actor: String

    /// Target of the action (file path, policy name, etc.)
    public let target: String

    /// Result of the action
    public let result: AuditEventResult

    /// Severity level of the event
    public let severity: AuditEventSeverity

    /// Additional metadata as key-value pairs
    public let metadata: [String: String]

    /// Optional session ID for grouping related events
    public let sessionId: String?

    /// Hostname where the event occurred
    public let hostname: String

    /// Username who triggered the event
    public let username: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: AuditEventCategory,
        action: String,
        actor: String,
        target: String,
        result: AuditEventResult,
        severity: AuditEventSeverity = .info,
        metadata: [String: String] = [:],
        sessionId: String? = nil,
        hostname: String? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.action = action
        self.actor = actor
        self.target = target
        self.result = result
        self.severity = severity
        self.metadata = metadata
        self.sessionId = sessionId
        self.hostname = hostname ?? ProcessInfo.processInfo.hostName
        self.username = username ?? NSUserName()
    }
}

// MARK: - Convenience Initializers

extension AuditEvent {
    /// Create a cleanup event
    public static func cleanup(
        action: String,
        target: String,
        result: AuditEventResult,
        freedBytes: UInt64? = nil,
        sessionId: String? = nil
    ) -> AuditEvent {
        var metadata: [String: String] = [:]
        if let bytes = freedBytes {
            metadata["freed_bytes"] = "\(bytes)"
            metadata["freed_formatted"] = ByteCountFormatter.string(
                fromByteCount: Int64(bytes),
                countStyle: .file
            )
        }

        return AuditEvent(
            category: .cleanup,
            action: action,
            actor: "osxcleaner",
            target: target,
            result: result,
            severity: result == .failure ? .error : .info,
            metadata: metadata,
            sessionId: sessionId
        )
    }

    /// Create a policy event
    public static func policy(
        action: String,
        policyName: String,
        result: AuditEventResult,
        details: [String: String] = [:]
    ) -> AuditEvent {
        AuditEvent(
            category: .policy,
            action: action,
            actor: "policy-engine",
            target: policyName,
            result: result,
            severity: result == .failure ? .warning : .info,
            metadata: details
        )
    }

    /// Create a security event
    public static func security(
        action: String,
        target: String,
        result: AuditEventResult,
        severity: AuditEventSeverity = .warning,
        details: [String: String] = [:]
    ) -> AuditEvent {
        AuditEvent(
            category: .security,
            action: action,
            actor: NSUserName(),
            target: target,
            result: result,
            severity: severity,
            metadata: details
        )
    }

    /// Create a system event
    public static func system(
        action: String,
        details: [String: String] = [:]
    ) -> AuditEvent {
        AuditEvent(
            category: .system,
            action: action,
            actor: "system",
            target: "osxcleaner",
            result: .success,
            severity: .info,
            metadata: details
        )
    }
}

// MARK: - Query Support

/// Query parameters for filtering audit events
public struct AuditEventQuery {
    /// Filter by start date (inclusive)
    public var startDate: Date?

    /// Filter by end date (inclusive)
    public var endDate: Date?

    /// Filter by category
    public var category: AuditEventCategory?

    /// Filter by result
    public var result: AuditEventResult?

    /// Filter by severity
    public var severity: AuditEventSeverity?

    /// Filter by session ID
    public var sessionId: String?

    /// Filter by action (partial match)
    public var action: String?

    /// Filter by target (partial match)
    public var target: String?

    /// Maximum number of results
    public var limit: Int?

    /// Offset for pagination
    public var offset: Int?

    /// Sort order (true = ascending, false = descending)
    public var ascending: Bool

    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        category: AuditEventCategory? = nil,
        result: AuditEventResult? = nil,
        severity: AuditEventSeverity? = nil,
        sessionId: String? = nil,
        action: String? = nil,
        target: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        ascending: Bool = false
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.result = result
        self.severity = severity
        self.sessionId = sessionId
        self.action = action
        self.target = target
        self.limit = limit
        self.offset = offset
        self.ascending = ascending
    }

    /// Query for the last N events
    public static func lastEvents(_ count: Int) -> AuditEventQuery {
        AuditEventQuery(limit: count, ascending: false)
    }

    /// Query for events in a specific category
    public static func forCategory(_ category: AuditEventCategory) -> AuditEventQuery {
        AuditEventQuery(category: category)
    }

    /// Query for events in a specific session
    public static func forSession(_ sessionId: String) -> AuditEventQuery {
        AuditEventQuery(sessionId: sessionId)
    }

    /// Query for events from today
    public static var today: AuditEventQuery {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return AuditEventQuery(startDate: startOfDay)
    }
}

// MARK: - Aggregate Statistics

/// Aggregate statistics for audit events
public struct AuditStatistics: Codable {
    /// Total number of events
    public let totalEvents: Int

    /// Events by category
    public let byCategory: [AuditEventCategory: Int]

    /// Events by result
    public let byResult: [AuditEventResult: Int]

    /// Total bytes freed (for cleanup events)
    public let totalFreedBytes: UInt64

    /// Date range of events
    public let dateRange: DateInterval?

    public init(
        totalEvents: Int,
        byCategory: [AuditEventCategory: Int],
        byResult: [AuditEventResult: Int],
        totalFreedBytes: UInt64,
        dateRange: DateInterval?
    ) {
        self.totalEvents = totalEvents
        self.byCategory = byCategory
        self.byResult = byResult
        self.totalFreedBytes = totalFreedBytes
        self.dateRange = dateRange
    }

    /// Formatted total freed space
    public var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalFreedBytes), countStyle: .file)
    }
}

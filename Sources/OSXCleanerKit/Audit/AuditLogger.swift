// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Configuration for the audit logger
public struct AuditLoggerConfig {
    /// Store configuration
    public let storeConfig: AuditStoreConfig

    /// Whether to also log to console
    public let consoleLogging: Bool

    /// Whether to automatically apply retention policy
    public let autoRetention: Bool

    /// Retention check interval in hours
    public let retentionCheckInterval: Int

    public init(
        storeConfig: AuditStoreConfig = AuditStoreConfig(),
        consoleLogging: Bool = false,
        autoRetention: Bool = true,
        retentionCheckInterval: Int = 24
    ) {
        self.storeConfig = storeConfig
        self.consoleLogging = consoleLogging
        self.autoRetention = autoRetention
        self.retentionCheckInterval = retentionCheckInterval
    }
}

/// Enterprise audit logging service
///
/// Provides comprehensive audit logging for all OSX Cleaner operations.
/// Supports event categorization, persistent storage, and compliance reporting.
///
/// ## Usage
/// ```swift
/// let logger = try AuditLogger.shared
///
/// // Log a cleanup operation
/// logger.logCleanup(
///     action: "delete_cache",
///     target: "~/Library/Caches/com.example.app",
///     result: .success,
///     freedBytes: 1_000_000
/// )
///
/// // Query recent events
/// let events = try logger.queryEvents(.lastEvents(100))
/// ```
public final class AuditLogger {

    // MARK: - Singleton

    private static var _shared: AuditLogger?
    private static let lock = NSLock()

    /// Shared instance of the audit logger
    public static var shared: AuditLogger {
        get throws {
            lock.lock()
            defer { lock.unlock() }

            if let instance = _shared {
                return instance
            }

            let instance = try AuditLogger()
            _shared = instance
            return instance
        }
    }

    // MARK: - Properties

    private let store: AuditEventStore
    private let config: AuditLoggerConfig
    private let logQueue: DispatchQueue
    private var lastRetentionCheck: Date?

    // MARK: - Initialization

    public init(config: AuditLoggerConfig = AuditLoggerConfig()) throws {
        self.config = config
        self.store = try AuditEventStore(config: config.storeConfig)
        self.logQueue = DispatchQueue(label: "com.osxcleaner.audit-logger", qos: .utility)

        // Log system startup
        log(.system(action: "audit_system_started", details: [
            "version": "1.0.0",
            "retention_days": "\(config.storeConfig.retentionDays)"
        ]))
    }

    // MARK: - Event Logging

    /// Log a generic audit event
    public func log(_ event: AuditEvent) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.store.insert(event)

                if self.config.consoleLogging {
                    self.printEvent(event)
                }

                self.checkRetentionPolicy()
            } catch {
                AppLogger.shared.error("Failed to log audit event: \(error.localizedDescription)")
            }
        }
    }

    /// Log a cleanup operation
    public func logCleanup(
        action: String,
        target: String,
        result: AuditEventResult,
        freedBytes: UInt64? = nil,
        sessionId: String? = nil
    ) {
        log(.cleanup(
            action: action,
            target: target,
            result: result,
            freedBytes: freedBytes,
            sessionId: sessionId
        ))
    }

    /// Log a policy-related event
    public func logPolicy(
        action: String,
        policyName: String,
        result: AuditEventResult,
        details: [String: String] = [:]
    ) {
        log(.policy(
            action: action,
            policyName: policyName,
            result: result,
            details: details
        ))
    }

    /// Log a security-related event
    public func logSecurity(
        action: String,
        target: String,
        result: AuditEventResult,
        severity: AuditEventSeverity = .warning,
        details: [String: String] = [:]
    ) {
        log(.security(
            action: action,
            target: target,
            result: result,
            severity: severity,
            details: details
        ))
    }

    /// Log a system event
    public func logSystem(action: String, details: [String: String] = [:]) {
        log(.system(action: action, details: details))
    }

    /// Log a user action
    public func logUserAction(action: String, target: String, result: AuditEventResult) {
        log(AuditEvent(
            category: .user,
            action: action,
            actor: NSUserName(),
            target: target,
            result: result,
            severity: .info
        ))
    }

    // MARK: - Session Management

    /// Start a new audit session and return the session ID
    public func startSession(type: String) -> String {
        let sessionId = UUID().uuidString

        log(AuditEvent(
            category: .system,
            action: "session_start",
            actor: "osxcleaner",
            target: type,
            result: .success,
            severity: .info,
            sessionId: sessionId
        ))

        return sessionId
    }

    /// End an audit session
    public func endSession(_ sessionId: String, result: AuditEventResult) {
        log(AuditEvent(
            category: .system,
            action: "session_end",
            actor: "osxcleaner",
            target: sessionId,
            result: result,
            severity: .info,
            sessionId: sessionId
        ))
    }

    // MARK: - Query Methods

    /// Query events based on filter criteria
    public func queryEvents(_ query: AuditEventQuery) throws -> [AuditEvent] {
        try store.query(query)
    }

    /// Get the count of events matching a query
    public func countEvents(_ query: AuditEventQuery) throws -> Int {
        try store.count(query)
    }

    /// Get aggregate statistics for events
    public func getStatistics(_ query: AuditEventQuery = AuditEventQuery()) throws -> AuditStatistics {
        try store.statistics(query)
    }

    /// Get recent events
    public func getRecentEvents(count: Int = 100) throws -> [AuditEvent] {
        try queryEvents(.lastEvents(count))
    }

    /// Get events for a specific category
    public func getEvents(category: AuditEventCategory, limit: Int = 100) throws -> [AuditEvent] {
        try queryEvents(AuditEventQuery(category: category, limit: limit))
    }

    /// Get events for a specific session
    public func getSessionEvents(_ sessionId: String) throws -> [AuditEvent] {
        try queryEvents(.forSession(sessionId))
    }

    // MARK: - Maintenance

    /// Manually apply retention policy
    @discardableResult
    public func applyRetention() throws -> Int {
        let deleted = try store.applyRetentionPolicy()

        if deleted > 0 {
            logSystem(action: "retention_applied", details: [
                "deleted_events": "\(deleted)"
            ])
            AppLogger.shared.info("Audit retention applied: \(deleted) old events removed")
        }

        return deleted
    }

    /// Clear all audit events (use with caution)
    public func clearAll() throws {
        logSecurity(
            action: "audit_clear_all",
            target: "audit_events",
            result: .success,
            severity: .critical
        )

        // Wait for the log event to be written
        logQueue.sync {}

        try store.clear()
        AppLogger.shared.warning("All audit events have been cleared")
    }

    /// Get database information
    public func getDatabaseInfo() -> (path: String, size: UInt64) {
        (store.getDatabasePath(), store.getDatabaseSize())
    }

    // MARK: - Private Helpers

    private func checkRetentionPolicy() {
        guard config.autoRetention else { return }

        let now = Date()

        // Only check periodically
        if let lastCheck = lastRetentionCheck {
            let hours = Calendar.current.dateComponents(
                [.hour],
                from: lastCheck,
                to: now
            ).hour ?? 0

            if hours < config.retentionCheckInterval {
                return
            }
        }

        lastRetentionCheck = now

        do {
            try applyRetention()
        } catch {
            AppLogger.shared.error("Failed to apply audit retention: \(error.localizedDescription)")
        }
    }

    private func printEvent(_ event: AuditEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let timestamp = formatter.string(from: event.timestamp)
        let categoryIcon = categoryIcon(for: event.category)
        let resultIcon = resultIcon(for: event.result)

        print("[\(timestamp)] \(categoryIcon) \(event.category.rawValue.uppercased()) \(resultIcon) \(event.action): \(event.target)")
    }

    private func categoryIcon(for category: AuditEventCategory) -> String {
        switch category {
        case .cleanup: return "🧹"
        case .policy: return "📋"
        case .security: return "🔒"
        case .system: return "⚙️"
        case .user: return "👤"
        }
    }

    private func resultIcon(for result: AuditEventResult) -> String {
        switch result {
        case .success: return "✓"
        case .failure: return "✗"
        case .warning: return "⚠"
        case .skipped: return "○"
        }
    }
}

// MARK: - Integration with Existing Services

extension AuditLogger {
    /// Log a cleanup session from AutomatedCleanupLoggingService
    public func logCleanupSession(
        session: CleanupSession,
        result: CleanupSessionResult?
    ) {
        let auditResult: AuditEventResult = {
            guard let result = result else { return .failure }
            return result.errorsCount == 0 ? .success : .warning
        }()

        var metadata: [String: String] = [
            "trigger_type": session.triggerType.rawValue,
            "cleanup_level": session.cleanupLevel
        ]

        if let result = result {
            metadata["freed_bytes"] = "\(result.freedBytes)"
            metadata["files_removed"] = "\(result.filesRemoved)"
            metadata["directories_removed"] = "\(result.directoriesRemoved)"
            metadata["errors_count"] = "\(result.errorsCount)"
            metadata["duration_seconds"] = String(format: "%.2f", result.durationSeconds)
        }

        log(AuditEvent(
            category: .cleanup,
            action: result != nil ? "session_completed" : "session_started",
            actor: "automated_cleanup",
            target: session.cleanupLevel,
            result: auditResult,
            severity: auditResult == .failure ? .error : .info,
            metadata: metadata,
            sessionId: session.sessionId
        ))
    }
}

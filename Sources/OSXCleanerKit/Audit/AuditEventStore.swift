// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import SQLite3

/// Errors that can occur during audit event storage operations
public enum AuditStoreError: LocalizedError {
    case databaseOpenFailed(String)
    case queryFailed(String)
    case insertFailed(String)
    case deleteFailed(String)
    case schemaCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let message):
            return "Failed to open audit database: \(message)"
        case .queryFailed(let message):
            return "Failed to query audit events: \(message)"
        case .insertFailed(let message):
            return "Failed to insert audit event: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete audit events: \(message)"
        case .schemaCreationFailed(let message):
            return "Failed to create audit database schema: \(message)"
        }
    }
}

/// Configuration for the audit event store
public struct AuditStoreConfig {
    /// Maximum number of events to retain
    public let maxEvents: Int

    /// Maximum age of events to retain (in days)
    public let retentionDays: Int

    /// Whether to vacuum database periodically
    public let autoVacuum: Bool

    public init(
        maxEvents: Int = 100_000,
        retentionDays: Int = 365,
        autoVacuum: Bool = true
    ) {
        self.maxEvents = maxEvents
        self.retentionDays = retentionDays
        self.autoVacuum = autoVacuum
    }
}

/// SQLite-based persistent storage for audit events
public final class AuditEventStore {

    // MARK: - Properties

    private var db: OpaquePointer?
    private let config: AuditStoreConfig
    private let dbQueue: DispatchQueue
    private let dateFormatter: ISO8601DateFormatter

    private var databasePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("audit.db")
    }

    // MARK: - Initialization

    public init(config: AuditStoreConfig = AuditStoreConfig()) throws {
        self.config = config
        self.dbQueue = DispatchQueue(label: "com.osxcleaner.audit-store", qos: .utility)
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try openDatabase()
        try createSchema()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Management

    private func openDatabase() throws {
        let directory = databasePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        if sqlite3_open(databasePath.path, &db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw AuditStoreError.databaseOpenFailed(message)
        }

        // Enable WAL mode for better performance
        executeSQL("PRAGMA journal_mode=WAL;")
        executeSQL("PRAGMA synchronous=NORMAL;")
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createSchema() throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS audit_events (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                category TEXT NOT NULL,
                action TEXT NOT NULL,
                actor TEXT NOT NULL,
                target TEXT NOT NULL,
                result TEXT NOT NULL,
                severity TEXT NOT NULL,
                metadata TEXT,
                session_id TEXT,
                hostname TEXT NOT NULL,
                username TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_events(timestamp);
            CREATE INDEX IF NOT EXISTS idx_audit_category ON audit_events(category);
            CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_events(session_id);
            CREATE INDEX IF NOT EXISTS idx_audit_result ON audit_events(result);
        """

        guard executeSQL(createTableSQL) else {
            throw AuditStoreError.schemaCreationFailed("Failed to create tables and indexes")
        }
    }

    @discardableResult
    private func executeSQL(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)

        if result != SQLITE_OK {
            if let errMsg = errMsg {
                AppLogger.shared.error("SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }

    // MARK: - Event Operations

    /// Insert a new audit event
    public func insert(_ event: AuditEvent) throws {
        try dbQueue.sync {
            let sql = """
                INSERT INTO audit_events
                (id, timestamp, category, action, actor, target, result, severity, metadata, session_id, hostname, username)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw AuditStoreError.insertFailed(String(cString: sqlite3_errmsg(db)))
            }

            let metadataJson = try? JSONEncoder().encode(event.metadata)
            let metadataString = metadataJson.flatMap { String(data: $0, encoding: .utf8) }

            sqlite3_bind_text(stmt, 1, event.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, dateFormatter.string(from: event.timestamp), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, event.category.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, event.action, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, event.actor, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, event.target, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, event.result.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 8, event.severity.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, metadataString ?? "{}", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 10, event.sessionId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 11, event.hostname, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 12, event.username, -1, SQLITE_TRANSIENT)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw AuditStoreError.insertFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    /// Query events based on filter criteria
    public func query(_ query: AuditEventQuery) throws -> [AuditEvent] {
        try dbQueue.sync {
            var conditions: [String] = []
            var params: [Any] = []

            if let startDate = query.startDate {
                conditions.append("timestamp >= ?")
                params.append(dateFormatter.string(from: startDate))
            }

            if let endDate = query.endDate {
                conditions.append("timestamp <= ?")
                params.append(dateFormatter.string(from: endDate))
            }

            if let category = query.category {
                conditions.append("category = ?")
                params.append(category.rawValue)
            }

            if let result = query.result {
                conditions.append("result = ?")
                params.append(result.rawValue)
            }

            if let severity = query.severity {
                conditions.append("severity = ?")
                params.append(severity.rawValue)
            }

            if let sessionId = query.sessionId {
                conditions.append("session_id = ?")
                params.append(sessionId)
            }

            if let action = query.action {
                conditions.append("action LIKE ?")
                params.append("%\(action)%")
            }

            if let target = query.target {
                conditions.append("target LIKE ?")
                params.append("%\(target)%")
            }

            var sql = "SELECT * FROM audit_events"
            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }

            sql += " ORDER BY timestamp " + (query.ascending ? "ASC" : "DESC")

            if let limit = query.limit {
                sql += " LIMIT \(limit)"
            }

            if let offset = query.offset {
                sql += " OFFSET \(offset)"
            }

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw AuditStoreError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            // Bind parameters
            for (index, param) in params.enumerated() {
                if let stringParam = param as? String {
                    sqlite3_bind_text(stmt, Int32(index + 1), stringParam, -1, SQLITE_TRANSIENT)
                }
            }

            var events: [AuditEvent] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let event = parseEvent(from: stmt) {
                    events.append(event)
                }
            }

            return events
        }
    }

    /// Get the total count of events matching a query
    public func count(_ query: AuditEventQuery) throws -> Int {
        try dbQueue.sync {
            var conditions: [String] = []

            if let startDate = query.startDate {
                conditions.append("timestamp >= '\(dateFormatter.string(from: startDate))'")
            }
            if let endDate = query.endDate {
                conditions.append("timestamp <= '\(dateFormatter.string(from: endDate))'")
            }
            if let category = query.category {
                conditions.append("category = '\(category.rawValue)'")
            }
            if let result = query.result {
                conditions.append("result = '\(result.rawValue)'")
            }

            var sql = "SELECT COUNT(*) FROM audit_events"
            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw AuditStoreError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int64(stmt, 0))
            }

            return 0
        }
    }

    /// Get aggregate statistics for events matching a query
    public func statistics(_ query: AuditEventQuery) throws -> AuditStatistics {
        let events = try self.query(query)

        var byCategory: [AuditEventCategory: Int] = [:]
        var byResult: [AuditEventResult: Int] = [:]
        var totalFreedBytes: UInt64 = 0
        var minDate: Date?
        var maxDate: Date?

        for event in events {
            byCategory[event.category, default: 0] += 1
            byResult[event.result, default: 0] += 1

            if let freedBytes = event.metadata["freed_bytes"], let bytes = UInt64(freedBytes) {
                totalFreedBytes += bytes
            }

            if minDate == nil || event.timestamp < minDate! {
                minDate = event.timestamp
            }
            if maxDate == nil || event.timestamp > maxDate! {
                maxDate = event.timestamp
            }
        }

        let dateRange: DateInterval?
        if let start = minDate, let end = maxDate {
            dateRange = DateInterval(start: start, end: end)
        } else {
            dateRange = nil
        }

        return AuditStatistics(
            totalEvents: events.count,
            byCategory: byCategory,
            byResult: byResult,
            totalFreedBytes: totalFreedBytes,
            dateRange: dateRange
        )
    }

    /// Delete events older than the retention period
    public func applyRetentionPolicy() throws -> Int {
        try dbQueue.sync {
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -config.retentionDays,
                to: Date()
            )!

            let sql = "DELETE FROM audit_events WHERE timestamp < ?"

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw AuditStoreError.deleteFailed(String(cString: sqlite3_errmsg(db)))
            }

            sqlite3_bind_text(stmt, 1, dateFormatter.string(from: cutoffDate), -1, SQLITE_TRANSIENT)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw AuditStoreError.deleteFailed(String(cString: sqlite3_errmsg(db)))
            }

            let deletedCount = Int(sqlite3_changes(db))

            if config.autoVacuum && deletedCount > 0 {
                executeSQL("VACUUM;")
            }

            return deletedCount
        }
    }

    /// Delete all events
    public func clear() throws {
        try dbQueue.sync {
            guard executeSQL("DELETE FROM audit_events;") else {
                throw AuditStoreError.deleteFailed("Failed to clear audit events")
            }

            if config.autoVacuum {
                executeSQL("VACUUM;")
            }
        }
    }

    /// Get the database file path
    public func getDatabasePath() -> String {
        databasePath.path
    }

    /// Get the database file size in bytes
    public func getDatabaseSize() -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: databasePath.path),
              let size = attributes[.size] as? UInt64 else {
            return 0
        }
        return size
    }

    // MARK: - Private Helpers

    private func parseEvent(from stmt: OpaquePointer?) -> AuditEvent? {
        guard let stmt = stmt else { return nil }

        guard let idStr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idStr)),
              let timestampStr = sqlite3_column_text(stmt, 1),
              let timestamp = dateFormatter.date(from: String(cString: timestampStr)),
              let categoryStr = sqlite3_column_text(stmt, 2),
              let category = AuditEventCategory(rawValue: String(cString: categoryStr)),
              let actionPtr = sqlite3_column_text(stmt, 3),
              let actorPtr = sqlite3_column_text(stmt, 4),
              let targetPtr = sqlite3_column_text(stmt, 5),
              let resultStr = sqlite3_column_text(stmt, 6),
              let result = AuditEventResult(rawValue: String(cString: resultStr)),
              let severityStr = sqlite3_column_text(stmt, 7),
              let severity = AuditEventSeverity(rawValue: String(cString: severityStr)),
              let hostnamePtr = sqlite3_column_text(stmt, 10),
              let usernamePtr = sqlite3_column_text(stmt, 11) else {
            return nil
        }

        let action = String(cString: actionPtr)
        let actor = String(cString: actorPtr)
        let target = String(cString: targetPtr)
        let hostname = String(cString: hostnamePtr)
        let username = String(cString: usernamePtr)

        var metadata: [String: String] = [:]
        if let metadataPtr = sqlite3_column_text(stmt, 8) {
            let metadataStr = String(cString: metadataPtr)
            if let data = metadataStr.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
                metadata = parsed
            }
        }

        let sessionId: String?
        if let sessionPtr = sqlite3_column_text(stmt, 9) {
            sessionId = String(cString: sessionPtr)
        } else {
            sessionId = nil
        }

        return AuditEvent(
            id: id,
            timestamp: timestamp,
            category: category,
            action: action,
            actor: actor,
            target: target,
            result: result,
            severity: severity,
            metadata: metadata,
            sessionId: sessionId,
            hostname: hostname,
            username: username
        )
    }
}

// MARK: - SQLite Transient Helper

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

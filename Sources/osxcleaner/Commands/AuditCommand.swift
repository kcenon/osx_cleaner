// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct AuditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "View and manage audit logs for enterprise compliance",
        subcommands: [
            ListAudit.self,
            ShowAudit.self,
            StatsAudit.self,
            ExportAudit.self,
            ClearAudit.self,
            InfoAudit.self
        ],
        defaultSubcommand: ListAudit.self
    )
}

// MARK: - List Subcommand

extension AuditCommand {
    struct ListAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List recent audit events"
        )

        @Option(name: .shortAndLong, help: "Number of events to show (default: 20)")
        var count: Int = 20

        @Option(name: .shortAndLong, help: "Filter by category (cleanup, policy, security, system, user)")
        var category: String?

        @Option(name: .shortAndLong, help: "Filter by result (success, failure, warning, skipped)")
        var result: String?

        @Option(name: .long, help: "Filter by session ID")
        var session: String?

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let logger = try AuditLogger.shared

            var query = AuditEventQuery(limit: count, ascending: false)

            if let categoryStr = category,
               let cat = AuditEventCategory(rawValue: categoryStr) {
                query.category = cat
            }

            if let resultStr = result,
               let res = AuditEventResult(rawValue: resultStr) {
                query.result = res
            }

            if let session = session {
                query.sessionId = session
            }

            let events = try logger.queryEvents(query)

            if events.isEmpty {
                progressView.display(message: "No audit events found")
                return
            }

            if json {
                let exporter = AuditExporter()
                let jsonStr = try exporter.exportToJSON(events)
                print(jsonStr)
            } else {
                printEventTable(events, progressView: progressView)
            }
        }

        private func printEventTable(_ events: [AuditEvent], progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm:ss"

            progressView.display(message: "")
            progressView.display(message: "╔═══════════════════╤═══════════╤════════════════════╤═══════════╤════════════════════════════════════╗")
            progressView.display(message: "║     Timestamp     │  Category │       Action       │  Result   │              Target                ║")
            progressView.display(message: "╠═══════════════════╪═══════════╪════════════════════╪═══════════╪════════════════════════════════════╣")

            for event in events {
                let timestamp = formatter.string(from: event.timestamp)
                let category = event.category.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0)
                let action = event.action.prefix(18).padding(toLength: 18, withPad: " ", startingAt: 0)
                let result = resultIcon(event.result) + " " + event.result.rawValue.prefix(7).padding(toLength: 7, withPad: " ", startingAt: 0)
                let target = event.target.prefix(34).padding(toLength: 34, withPad: " ", startingAt: 0)

                progressView.display(message: "║ \(timestamp) │ \(category) │ \(action) │ \(result) │ \(target) ║")
            }

            progressView.display(message: "╚═══════════════════╧═══════════╧════════════════════╧═══════════╧════════════════════════════════════╝")
            progressView.display(message: "")
            progressView.display(message: "Showing \(events.count) event(s)")
        }

        private func resultIcon(_ result: AuditEventResult) -> String {
            switch result {
            case .success: return "✓"
            case .failure: return "✗"
            case .warning: return "⚠"
            case .skipped: return "○"
            }
        }
    }
}

// MARK: - Show Subcommand

extension AuditCommand {
    struct ShowAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show detailed information about an audit event"
        )

        @Argument(help: "Event ID (UUID) or 'last' for the most recent event")
        var eventId: String

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let logger = try AuditLogger.shared

            let event: AuditEvent?

            if eventId == "last" {
                event = try logger.getRecentEvents(count: 1).first
            } else {
                // Search by ID prefix match
                let events = try logger.getRecentEvents(count: 1000)
                event = events.first { $0.id.uuidString.lowercased().hasPrefix(eventId.lowercased()) }
            }

            guard let event = event else {
                progressView.display(message: "Event not found: \(eventId)")
                return
            }

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(event)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                printEventDetails(event, progressView: progressView)
            }
        }

        private func printEventDetails(_ event: AuditEvent, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                     AUDIT EVENT DETAILS                   ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
            progressView.display(message: "  ID:         \(event.id.uuidString)")
            progressView.display(message: "  Timestamp:  \(formatter.string(from: event.timestamp))")
            progressView.display(message: "  Category:   \(event.category.rawValue)")
            progressView.display(message: "  Action:     \(event.action)")
            progressView.display(message: "  Actor:      \(event.actor)")
            progressView.display(message: "  Target:     \(event.target)")
            progressView.display(message: "  Result:     \(resultIcon(event.result)) \(event.result.rawValue)")
            progressView.display(message: "  Severity:   \(event.severity.rawValue)")
            progressView.display(message: "  Hostname:   \(event.hostname)")
            progressView.display(message: "  Username:   \(event.username)")

            if let sessionId = event.sessionId {
                progressView.display(message: "  Session:    \(sessionId)")
            }

            if !event.metadata.isEmpty {
                progressView.display(message: "")
                progressView.display(message: "  Metadata:")
                for (key, value) in event.metadata.sorted(by: { $0.key < $1.key }) {
                    progressView.display(message: "    \(key): \(value)")
                }
            }

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }

        private func resultIcon(_ result: AuditEventResult) -> String {
            switch result {
            case .success: return "✓"
            case .failure: return "✗"
            case .warning: return "⚠"
            case .skipped: return "○"
            }
        }
    }
}

// MARK: - Stats Subcommand

extension AuditCommand {
    struct StatsAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show audit event statistics"
        )

        @Option(name: .long, help: "Filter events from the last N days")
        var days: Int?

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let logger = try AuditLogger.shared

            var query = AuditEventQuery()

            if let days = days {
                query.startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            }

            let statistics = try logger.getStatistics(query)

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(statistics)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                let exporter = AuditExporter()
                let report = exporter.exportStatisticsReport(statistics)
                print(report)
            }
        }
    }
}

// MARK: - Export Subcommand

extension AuditCommand {
    struct ExportAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export audit events to a file"
        )

        @Option(name: .shortAndLong, help: "Export format (json, csv, jsonl)")
        var format: String = "json"

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        @Option(name: .long, help: "Filter events from the last N days")
        var days: Int?

        @Option(name: .long, help: "Filter by category")
        var category: String?

        @Option(name: .long, help: "Maximum number of events to export")
        var limit: Int?

        mutating func run() async throws {
            let progressView = ProgressView()
            let logger = try AuditLogger.shared
            let exporter = AuditExporter()

            guard let exportFormat = AuditExportFormat(rawValue: format) else {
                progressView.display(message: "Invalid format: \(format)")
                progressView.display(message: "Valid formats: json, csv, jsonl")
                return
            }

            var query = AuditEventQuery()

            if let days = days {
                query.startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())
            }

            if let categoryStr = category,
               let cat = AuditEventCategory(rawValue: categoryStr) {
                query.category = cat
            }

            if let limit = limit {
                query.limit = limit
            }

            let events = try logger.queryEvents(query)

            if events.isEmpty {
                progressView.display(message: "No events to export")
                return
            }

            progressView.display(message: "Exporting \(events.count) event(s)...")

            let result = try exporter.export(
                events: events,
                format: exportFormat,
                outputPath: output
            )

            progressView.display(message: "")
            progressView.display(message: "✓ Export completed successfully")
            progressView.display(message: "  File: \(result.filePath)")
            progressView.display(message: "  Events: \(result.eventCount)")
            progressView.display(message: "  Size: \(ByteCountFormatter.string(fromByteCount: Int64(result.fileSize), countStyle: .file))")
            progressView.display(message: "  Duration: \(String(format: "%.2f", result.duration))s")
        }
    }
}

// MARK: - Clear Subcommand

extension AuditCommand {
    struct ClearAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear audit events"
        )

        @Option(name: .long, help: "Delete events older than N days (applies retention policy)")
        var olderThan: Int?

        @Flag(name: .long, help: "Delete ALL audit events (requires --force)")
        var all: Bool = false

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let logger = try AuditLogger.shared

            if all {
                if !force {
                    progressView.display(message: "⚠️  WARNING: This will delete ALL audit events!")
                    progressView.display(message: "This action cannot be undone.")
                    progressView.display(message: "Use --force to confirm.")
                    return
                }

                progressView.display(message: "Clearing all audit events...")
                try logger.clearAll()
                progressView.display(message: "✓ All audit events have been cleared")

            } else if let days = olderThan {
                if !force {
                    progressView.display(message: "This will delete events older than \(days) days.")
                    progressView.display(message: "Use --force to confirm.")
                    return
                }

                progressView.display(message: "Applying retention policy (\(days) days)...")

                // Create a temporary logger with custom retention
                let customConfig = AuditLoggerConfig(
                    storeConfig: AuditStoreConfig(retentionDays: days)
                )
                let customLogger = try AuditLogger(config: customConfig)
                let deleted = try customLogger.applyRetention()

                progressView.display(message: "✓ Deleted \(deleted) old event(s)")

            } else {
                progressView.display(message: "Usage:")
                progressView.display(message: "  osxcleaner audit clear --older-than 90 --force")
                progressView.display(message: "  osxcleaner audit clear --all --force")
            }
        }
    }
}

// MARK: - Info Subcommand

extension AuditCommand {
    struct InfoAudit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Show audit system information"
        )

        mutating func run() async throws {
            let progressView = ProgressView()
            let logger = try AuditLogger.shared

            let (path, size) = logger.getDatabaseInfo()
            let eventCount = try logger.countEvents(AuditEventQuery())
            let statistics = try logger.getStatistics(AuditEventQuery())

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                AUDIT SYSTEM INFORMATION                   ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
            progressView.display(message: "  Database path:  \(path)")
            progressView.display(message: "  Database size:  \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
            progressView.display(message: "  Total events:   \(eventCount)")
            progressView.display(message: "")

            if let dateRange = statistics.dateRange {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                progressView.display(message: "  Date range:")
                progressView.display(message: "    From: \(formatter.string(from: dateRange.start))")
                progressView.display(message: "    To:   \(formatter.string(from: dateRange.end))")
            }

            progressView.display(message: "")
            progressView.display(message: "  Events by category:")
            for category in AuditEventCategory.allCases {
                let count = statistics.byCategory[category] ?? 0
                if count > 0 {
                    progressView.display(message: "    \(category.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)): \(count)")
                }
            }

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }
    }
}

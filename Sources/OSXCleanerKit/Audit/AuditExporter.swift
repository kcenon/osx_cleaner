// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Export format for audit events
public enum AuditExportFormat: String, CaseIterable {
    case json
    case csv
    case jsonLines = "jsonl"
}

/// Errors that can occur during export
public enum AuditExportError: LocalizedError {
    case noEventsToExport
    case encodingFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noEventsToExport:
            return "No audit events to export"
        case .encodingFailed(let message):
            return "Failed to encode audit events: \(message)"
        case .writeFailed(let message):
            return "Failed to write export file: \(message)"
        }
    }
}

/// Result of an export operation
public struct AuditExportResult {
    /// Path to the exported file
    public let filePath: String

    /// Number of events exported
    public let eventCount: Int

    /// Size of the exported file in bytes
    public let fileSize: UInt64

    /// Format used for export
    public let format: AuditExportFormat

    /// Time taken to export in seconds
    public let duration: TimeInterval
}

/// Service for exporting audit events to various formats
public final class AuditExporter {

    // MARK: - Properties

    private let dateFormatter: ISO8601DateFormatter
    private let csvDateFormatter: DateFormatter
    private let fileManager: FileManager

    // MARK: - Initialization

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        self.csvDateFormatter = DateFormatter()
        self.csvDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    // MARK: - Export Methods

    /// Export events to a file
    /// - Parameters:
    ///   - events: Events to export
    ///   - format: Export format
    ///   - outputPath: Optional output file path. If nil, creates file in default location
    /// - Returns: Export result with file details
    public func export(
        events: [AuditEvent],
        format: AuditExportFormat,
        outputPath: String? = nil
    ) throws -> AuditExportResult {
        guard !events.isEmpty else {
            throw AuditExportError.noEventsToExport
        }

        let startTime = Date()

        let filePath = outputPath ?? generateDefaultPath(format: format)
        let content: String

        switch format {
        case .json:
            content = try exportToJSON(events)
        case .csv:
            content = try exportToCSV(events)
        case .jsonLines:
            content = try exportToJSONLines(events)
        }

        // Ensure directory exists
        let directory = (filePath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        // Write file
        guard let data = content.data(using: .utf8) else {
            throw AuditExportError.encodingFailed("Failed to convert to UTF-8")
        }

        do {
            try data.write(to: URL(fileURLWithPath: filePath))
        } catch {
            throw AuditExportError.writeFailed(error.localizedDescription)
        }

        let duration = Date().timeIntervalSince(startTime)
        let fileSize = (try? fileManager.attributesOfItem(atPath: filePath)[.size] as? UInt64) ?? 0

        return AuditExportResult(
            filePath: filePath,
            eventCount: events.count,
            fileSize: fileSize,
            format: format,
            duration: duration
        )
    }

    /// Export events to JSON string
    public func exportToJSON(_ events: [AuditEvent]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData = AuditExportData(
            exportDate: Date(),
            hostname: ProcessInfo.processInfo.hostName,
            eventCount: events.count,
            events: events
        )

        do {
            let data = try encoder.encode(exportData)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw AuditExportError.encodingFailed("Failed to convert JSON to string")
            }
            return jsonString
        } catch {
            throw AuditExportError.encodingFailed(error.localizedDescription)
        }
    }

    /// Export events to JSON Lines format (one JSON object per line)
    public func exportToJSONLines(_ events: [AuditEvent]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let lines = try events.map { event -> String in
            let data = try encoder.encode(event)
            guard let line = String(data: data, encoding: .utf8) else {
                throw AuditExportError.encodingFailed("Failed to encode event")
            }
            return line
        }

        return lines.joined(separator: "\n")
    }

    /// Export events to CSV string
    public func exportToCSV(_ events: [AuditEvent]) throws -> String {
        var lines: [String] = []

        // Header row
        let headers = [
            "id",
            "timestamp",
            "category",
            "action",
            "actor",
            "target",
            "result",
            "severity",
            "session_id",
            "hostname",
            "username",
            "metadata"
        ]
        lines.append(headers.joined(separator: ","))

        // Data rows
        for event in events {
            let metadataJson = (try? JSONEncoder().encode(event.metadata))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            let row = [
                event.id.uuidString,
                csvDateFormatter.string(from: event.timestamp),
                event.category.rawValue,
                event.action,
                event.actor,
                escapeCSV(event.target),
                event.result.rawValue,
                event.severity.rawValue,
                event.sessionId ?? "",
                event.hostname,
                event.username,
                escapeCSV(metadataJson)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Statistics Export

    /// Export statistics as a formatted report
    public func exportStatisticsReport(_ statistics: AuditStatistics) -> String {
        var lines: [String] = []

        lines.append("=" * 60)
        lines.append("AUDIT STATISTICS REPORT")
        lines.append("=" * 60)
        lines.append("")

        // Date range
        if let dateRange = statistics.dateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            lines.append("Period: \(formatter.string(from: dateRange.start)) to \(formatter.string(from: dateRange.end))")
        }
        lines.append("")

        // Summary
        lines.append("SUMMARY")
        lines.append("-" * 40)
        lines.append("Total Events: \(statistics.totalEvents)")
        lines.append("Total Freed Space: \(statistics.formattedFreedSpace)")
        lines.append("")

        // By Category
        lines.append("EVENTS BY CATEGORY")
        lines.append("-" * 40)
        for category in AuditEventCategory.allCases {
            let count = statistics.byCategory[category] ?? 0
            let percentage = statistics.totalEvents > 0
                ? Double(count) / Double(statistics.totalEvents) * 100
                : 0
            let categoryName = category.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0)
            lines.append("  \(categoryName): \(String(format: "%5d", count)) (\(String(format: "%5.1f", percentage))%)")
        }
        lines.append("")

        // By Result
        lines.append("EVENTS BY RESULT")
        lines.append("-" * 40)
        for (result, count) in statistics.byResult.sorted(by: { $0.value > $1.value }) {
            let percentage = statistics.totalEvents > 0
                ? Double(count) / Double(statistics.totalEvents) * 100
                : 0
            let resultName = result.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0)
            lines.append("  \(resultName): \(String(format: "%5d", count)) (\(String(format: "%5.1f", percentage))%)")
        }
        lines.append("")

        lines.append("=" * 60)
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func generateDefaultPath(format: AuditExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let exportDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("exports")

        return exportDir
            .appendingPathComponent("audit_\(timestamp).\(format.rawValue)")
            .path
    }

    private func escapeCSV(_ value: String) -> String {
        // If value contains comma, newline, or double quote, wrap in quotes
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            // Escape double quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - Export Data Structure

private struct AuditExportData: Codable {
    let exportDate: Date
    let hostname: String
    let eventCount: Int
    let events: [AuditEvent]
}

// MARK: - String Repeat Operator

private extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}

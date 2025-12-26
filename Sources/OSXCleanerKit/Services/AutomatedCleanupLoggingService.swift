// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Configuration for automated cleanup logging
public struct CleanupLoggingConfig {
    /// Maximum size of a single log file in bytes (default: 10 MB)
    public let maxLogFileSize: UInt64

    /// Number of rotated log files to keep (default: 5)
    public let maxRotatedFiles: Int

    /// Whether to include detailed file-level logs
    public let includeDetailedLogs: Bool

    public init(
        maxLogFileSize: UInt64 = 10 * 1024 * 1024,
        maxRotatedFiles: Int = 5,
        includeDetailedLogs: Bool = false
    ) {
        self.maxLogFileSize = maxLogFileSize
        self.maxRotatedFiles = maxRotatedFiles
        self.includeDetailedLogs = includeDetailedLogs
    }
}

/// Represents a cleanup session for logging purposes
public struct CleanupSession: Codable {
    public let sessionId: String
    public let startTime: Date
    public var endTime: Date?
    public let triggerType: TriggerType
    public let cleanupLevel: String
    public var result: CleanupSessionResult?

    public enum TriggerType: String, Codable {
        case manual
        case scheduled
        case autoCleanup = "auto_cleanup"
        case diskMonitor = "disk_monitor"
    }

    public init(
        sessionId: String = UUID().uuidString,
        startTime: Date = Date(),
        triggerType: TriggerType,
        cleanupLevel: String
    ) {
        self.sessionId = sessionId
        self.startTime = startTime
        self.triggerType = triggerType
        self.cleanupLevel = cleanupLevel
    }
}

/// Result of a cleanup session
public struct CleanupSessionResult: Codable {
    public let freedBytes: UInt64
    public let filesRemoved: Int
    public let directoriesRemoved: Int
    public let errorsCount: Int
    public let durationSeconds: Double

    public var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(freedBytes), countStyle: .file)
    }

    public init(
        freedBytes: UInt64,
        filesRemoved: Int,
        directoriesRemoved: Int,
        errorsCount: Int,
        durationSeconds: Double
    ) {
        self.freedBytes = freedBytes
        self.filesRemoved = filesRemoved
        self.directoriesRemoved = directoriesRemoved
        self.errorsCount = errorsCount
        self.durationSeconds = durationSeconds
    }
}

/// Service for logging automated cleanup operations
///
/// Provides structured logging for scheduled and automated cleanup operations
/// with support for log rotation and long-term retention.
public final class AutomatedCleanupLoggingService {

    // MARK: - Singleton

    public static let shared = AutomatedCleanupLoggingService()

    // MARK: - Properties

    private let fileManager: FileManager
    private let config: CleanupLoggingConfig
    private let dateFormatter: ISO8601DateFormatter
    private let logQueue: DispatchQueue

    private var logDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("logs")
    }

    private var currentLogFile: URL {
        logDirectory.appendingPathComponent("cleanup.log")
    }

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        config: CleanupLoggingConfig = CleanupLoggingConfig()
    ) {
        self.fileManager = fileManager
        self.config = config
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.logQueue = DispatchQueue(label: "com.osxcleaner.cleanup-logging", qos: .utility)
    }

    // MARK: - Session Management

    /// Log the start of a cleanup session
    /// - Parameters:
    ///   - session: The cleanup session to log
    public func logSessionStart(_ session: CleanupSession) {
        let entry = LogEntry(
            timestamp: dateFormatter.string(from: session.startTime),
            level: "INFO",
            event: "SESSION_START",
            sessionId: session.sessionId,
            message: "Cleanup session started",
            details: [
                "trigger_type": session.triggerType.rawValue,
                "cleanup_level": session.cleanupLevel
            ]
        )
        writeLogEntry(entry)

        AppLogger.shared.info(
            "Cleanup session started [ID: \(session.sessionId), Trigger: \(session.triggerType.rawValue), Level: \(session.cleanupLevel)]"
        )
    }

    /// Log the end of a cleanup session
    /// - Parameters:
    ///   - session: The cleanup session with result
    public func logSessionEnd(_ session: CleanupSession) {
        guard let result = session.result, let endTime = session.endTime else {
            return
        }

        let entry = LogEntry(
            timestamp: dateFormatter.string(from: endTime),
            level: "INFO",
            event: "SESSION_END",
            sessionId: session.sessionId,
            message: "Cleanup session completed",
            details: [
                "freed_bytes": "\(result.freedBytes)",
                "freed_formatted": result.formattedFreedSpace,
                "files_removed": "\(result.filesRemoved)",
                "directories_removed": "\(result.directoriesRemoved)",
                "errors_count": "\(result.errorsCount)",
                "duration_seconds": String(format: "%.2f", result.durationSeconds)
            ]
        )
        writeLogEntry(entry)

        let statusEmoji = result.errorsCount == 0 ? "✓" : "⚠"
        AppLogger.shared.info(
            "\(statusEmoji) Cleanup session completed [ID: \(session.sessionId), Freed: \(result.formattedFreedSpace), Files: \(result.filesRemoved), Duration: \(String(format: "%.1f", result.durationSeconds))s]"
        )
    }

    /// Log a cleanup error
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - path: The path that caused the error
    ///   - error: The error description
    public func logError(sessionId: String, path: String, error: String) {
        let entry = LogEntry(
            timestamp: dateFormatter.string(from: Date()),
            level: "ERROR",
            event: "CLEANUP_ERROR",
            sessionId: sessionId,
            message: "Failed to clean path",
            details: [
                "path": path,
                "error": error
            ]
        )
        writeLogEntry(entry)

        AppLogger.shared.error("Cleanup error: \(path) - \(error)")
    }

    /// Log disk monitoring triggered cleanup
    /// - Parameters:
    ///   - usagePercent: Current disk usage percentage
    ///   - threshold: The threshold that was exceeded
    public func logDiskMonitorTrigger(usagePercent: Double, threshold: String) {
        let entry = LogEntry(
            timestamp: dateFormatter.string(from: Date()),
            level: "WARN",
            event: "DISK_MONITOR_TRIGGER",
            sessionId: nil,
            message: "Auto-cleanup triggered by disk monitor",
            details: [
                "usage_percent": String(format: "%.1f", usagePercent),
                "threshold": threshold
            ]
        )
        writeLogEntry(entry)

        AppLogger.shared.warning(
            "Disk monitor triggered cleanup: usage \(String(format: "%.1f", usagePercent))% exceeded \(threshold) threshold"
        )
    }

    // MARK: - Log File Management

    /// Get the path to the current log file
    public func getLogFilePath() -> String {
        currentLogFile.path
    }

    /// Get all log files including rotated ones
    public func getAllLogFiles() -> [URL] {
        var files: [URL] = []

        if fileManager.fileExists(atPath: currentLogFile.path) {
            files.append(currentLogFile)
        }

        for i in 1...config.maxRotatedFiles {
            let rotatedPath = logDirectory.appendingPathComponent("cleanup.log.\(i)")
            if fileManager.fileExists(atPath: rotatedPath.path) {
                files.append(rotatedPath)
            }
        }

        return files
    }

    /// Read recent log entries
    /// - Parameter count: Maximum number of entries to return
    /// - Returns: Array of log entries as dictionaries
    public func readRecentEntries(count: Int = 100) -> [[String: Any]] {
        guard let data = fileManager.contents(atPath: currentLogFile.path),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .suffix(count)

        return lines.compactMap { line -> [String: Any]? in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return json
        }
    }

    // MARK: - Private Methods

    private func writeLogEntry(_ entry: LogEntry) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.ensureLogDirectoryExists()
                self.rotateLogsIfNeeded()

                let jsonData = try JSONEncoder().encode(entry)
                guard var jsonString = String(data: jsonData, encoding: .utf8) else {
                    return
                }
                jsonString += "\n"

                if self.fileManager.fileExists(atPath: self.currentLogFile.path) {
                    let handle = try FileHandle(forWritingTo: self.currentLogFile)
                    handle.seekToEndOfFile()
                    if let data = jsonString.data(using: .utf8) {
                        handle.write(data)
                    }
                    try handle.close()
                } else {
                    try jsonString.write(to: self.currentLogFile, atomically: true, encoding: .utf8)
                }
            } catch {
                // Fallback to console logging if file logging fails
                AppLogger.shared.error("Failed to write cleanup log: \(error.localizedDescription)")
            }
        }
    }

    private func ensureLogDirectoryExists() throws {
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
    }

    private func rotateLogsIfNeeded() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: currentLogFile.path),
              let fileSize = attributes[.size] as? UInt64,
              fileSize > config.maxLogFileSize else {
            return
        }

        // Rotate existing files
        for i in (1..<config.maxRotatedFiles).reversed() {
            let oldPath = logDirectory.appendingPathComponent("cleanup.log.\(i)")
            let newPath = logDirectory.appendingPathComponent("cleanup.log.\(i + 1)")

            if fileManager.fileExists(atPath: oldPath.path) {
                try? fileManager.moveItem(at: oldPath, to: newPath)
            }
        }

        // Rotate current log to .1
        let rotatedPath = logDirectory.appendingPathComponent("cleanup.log.1")
        try? fileManager.moveItem(at: currentLogFile, to: rotatedPath)

        AppLogger.shared.info("Log file rotated: \(currentLogFile.path)")
    }
}

// MARK: - Log Entry Structure

private struct LogEntry: Codable {
    let timestamp: String
    let level: String
    let event: String
    let sessionId: String?
    let message: String
    let details: [String: String]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case level
        case event
        case sessionId = "session_id"
        case message
        case details
    }
}

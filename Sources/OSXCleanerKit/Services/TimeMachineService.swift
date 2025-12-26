// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Represents a local Time Machine snapshot
public struct Snapshot: Identifiable, Sendable {
    public let id: String
    public let date: Date
    public let volume: String
    public let estimatedSize: UInt64

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedSize), countStyle: .file)
    }

    public init(id: String, date: Date, volume: String, estimatedSize: UInt64 = 0) {
        self.id = id
        self.date = date
        self.volume = volume
        self.estimatedSize = estimatedSize
    }
}

/// Time Machine status information
public struct TimeMachineStatus: Sendable {
    public let isEnabled: Bool
    public let lastBackupDate: Date?
    public let backupDestination: String?
    public let isBackingUp: Bool

    public var formattedLastBackup: String? {
        guard let date = lastBackupDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public init(
        isEnabled: Bool,
        lastBackupDate: Date? = nil,
        backupDestination: String? = nil,
        isBackingUp: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.lastBackupDate = lastBackupDate
        self.backupDestination = backupDestination
        self.isBackingUp = isBackingUp
    }
}

/// Result of a snapshot deletion operation
public struct SnapshotDeletionResult: Sendable {
    public let success: Bool
    public let deletedCount: Int
    public let freedBytes: UInt64
    public let errors: [SnapshotError]

    public var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(freedBytes), countStyle: .file)
    }

    public init(
        success: Bool,
        deletedCount: Int = 0,
        freedBytes: UInt64 = 0,
        errors: [SnapshotError] = []
    ) {
        self.success = success
        self.deletedCount = deletedCount
        self.freedBytes = freedBytes
        self.errors = errors
    }
}

/// Error during snapshot operations
public struct SnapshotError: Error, Sendable {
    public let snapshot: String
    public let reason: String

    public init(snapshot: String, reason: String) {
        self.snapshot = snapshot
        self.reason = reason
    }
}

/// Service for managing Time Machine local snapshots
///
/// This service provides functionality to:
/// - List local APFS snapshots created by Time Machine
/// - Delete individual snapshots by date
/// - Thin all snapshots to free space
/// - Query Time Machine status and last backup date
///
/// Note: Some operations may require administrator privileges.
public final class TimeMachineService: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Status

    /// Check if Time Machine is enabled
    public func isTimeMachineEnabled() -> Bool {
        let result = runTmutil(["status"])
        // If tmutil status returns successfully and doesn't say "Automatic backups are off"
        return result.exitCode == 0 && !result.output.contains("Automatic backups: off")
    }

    /// Get Time Machine status information
    public func getStatus() async throws -> TimeMachineStatus {
        let statusResult = runTmutil(["status"])

        let isEnabled = statusResult.exitCode == 0 && !statusResult.output.contains("Automatic backups: off")
        let isBackingUp = statusResult.output.contains("Running = 1") || statusResult.output.contains("Running = true")

        // Get last backup date
        let lastBackupDate = try? await getLastBackupDate()

        // Get backup destination
        let destinationResult = runTmutil(["destinationinfo"])
        var backupDestination: String? = nil
        if destinationResult.exitCode == 0 {
            // Parse "Mount Point" line
            let lines = destinationResult.output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Mount Point") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        backupDestination = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        return TimeMachineStatus(
            isEnabled: isEnabled,
            lastBackupDate: lastBackupDate,
            backupDestination: backupDestination,
            isBackingUp: isBackingUp
        )
    }

    /// Get the date of the last successful backup
    public func getLastBackupDate() async throws -> Date? {
        let result = runTmutil(["latestbackup"])

        guard result.exitCode == 0 else {
            return nil
        }

        // Output is a path like: /Volumes/BackupDrive/Backups.backupdb/MacBook/2025-12-26-120000
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }

        // Extract date from path (format: YYYY-MM-DD-HHMMSS)
        let components = path.components(separatedBy: "/")
        guard let dateString = components.last else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: dateString)
    }

    // MARK: - Snapshot Listing

    /// List all local snapshots on the system
    public func listLocalSnapshots(volume: String = "/") async throws -> [Snapshot] {
        let result = runTmutil(["listlocalsnapshots", volume])

        guard result.exitCode == 0 else {
            throw SnapshotError(
                snapshot: volume,
                reason: "Failed to list snapshots: \(result.error)"
            )
        }

        return parseSnapshotList(result.output, volume: volume)
    }

    /// Parse snapshot listing output from tmutil
    private func parseSnapshotList(_ output: String, volume: String) -> [Snapshot] {
        var snapshots: [Snapshot] = []
        let lines = output.components(separatedBy: "\n")

        // Date formatter for snapshot dates (format: 2025-12-26-123456)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Format: "com.apple.TimeMachine.2025-12-26-123456.local" or just date
            guard !trimmed.isEmpty else { continue }

            // Skip header lines
            if trimmed.starts(with: "Snapshots for") { continue }

            // Extract date string
            var dateString: String = ""
            if trimmed.contains("com.apple.TimeMachine.") {
                // Full snapshot ID format
                let parts = trimmed.components(separatedBy: ".")
                if parts.count >= 3 {
                    dateString = parts[2]
                }
            } else {
                // Just the date string
                dateString = trimmed
            }

            // Parse the date
            if let date = formatter.date(from: dateString) {
                let snapshot = Snapshot(
                    id: trimmed,
                    date: date,
                    volume: volume,
                    estimatedSize: 0 // Size estimation is expensive, done separately
                )
                snapshots.append(snapshot)
            }
        }

        // Sort by date descending (newest first)
        return snapshots.sorted { $0.date > $1.date }
    }

    /// Estimate the total size of all local snapshots
    public func estimateSnapshotSize() async throws -> UInt64 {
        // Use diskutil to get APFS snapshot info
        let result = runCommand("/usr/sbin/diskutil", arguments: ["apfs", "listSnapshots", "/"])

        guard result.exitCode == 0 else {
            return 0
        }

        // Parse output to estimate size
        // This is an approximation as actual snapshot sizes are complex
        var totalSize: UInt64 = 0

        let lines = result.output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Size") || line.contains("Used") {
                // Try to extract size value
                if let sizeMatch = extractSize(from: line) {
                    totalSize += sizeMatch
                }
            }
        }

        return totalSize
    }

    /// Extract size in bytes from a string like "Size: 1.5 GB"
    private func extractSize(from string: String) -> UInt64? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(KB|MB|GB|TB|B)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }

        guard let valueRange = Range(match.range(at: 1), in: string),
              let unitRange = Range(match.range(at: 2), in: string) else {
            return nil
        }

        let value = Double(string[valueRange]) ?? 0
        let unit = String(string[unitRange]).uppercased()

        let multiplier: UInt64
        switch unit {
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        case "TB": multiplier = 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return UInt64(value * Double(multiplier))
    }

    // MARK: - Snapshot Deletion

    /// Delete a specific snapshot by date
    ///
    /// - Parameters:
    ///   - date: The date of the snapshot to delete
    ///   - dryRun: If true, only simulate the deletion
    /// - Returns: Result of the deletion operation
    public func deleteSnapshot(date: Date, dryRun: Bool = false) async throws -> SnapshotDeletionResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: date)

        AppLogger.shared.operation("\(dryRun ? "[DRY RUN] " : "")Deleting snapshot for \(dateString)")

        if dryRun {
            return SnapshotDeletionResult(success: true, deletedCount: 1, freedBytes: 0)
        }

        let result = runTmutil(["deletelocalsnapshots", dateString])

        if result.exitCode == 0 {
            AppLogger.shared.success("Deleted snapshot: \(dateString)")
            return SnapshotDeletionResult(success: true, deletedCount: 1, freedBytes: 0)
        } else {
            let error = SnapshotError(snapshot: dateString, reason: result.error)
            return SnapshotDeletionResult(success: false, deletedCount: 0, errors: [error])
        }
    }

    /// Delete a snapshot by its ID
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to delete
    ///   - dryRun: If true, only simulate the deletion
    public func deleteSnapshot(_ snapshot: Snapshot, dryRun: Bool = false) async throws -> SnapshotDeletionResult {
        return try await deleteSnapshot(date: snapshot.date, dryRun: dryRun)
    }

    /// Thin all local snapshots to free space
    ///
    /// This forces macOS to delete snapshots until the specified amount of space is available.
    /// Using a very large value (9999999999999) effectively removes all thinnable snapshots.
    ///
    /// - Parameters:
    ///   - keepBytes: Target free space in bytes (use 0 or very large value to thin aggressively)
    ///   - dryRun: If true, only simulate the operation
    public func thinSnapshots(keepBytes: UInt64 = 9999999999999, dryRun: Bool = false) async throws -> SnapshotDeletionResult {
        AppLogger.shared.operation("\(dryRun ? "[DRY RUN] " : "")Thinning local snapshots")

        // Get snapshot count before
        let snapshotsBefore = try await listLocalSnapshots()
        let countBefore = snapshotsBefore.count

        if dryRun {
            return SnapshotDeletionResult(
                success: true,
                deletedCount: countBefore,
                freedBytes: 0
            )
        }

        let result = runTmutil(["thinlocalsnapshots", "/", String(keepBytes)])

        if result.exitCode == 0 {
            // Get snapshot count after
            let snapshotsAfter = try await listLocalSnapshots()
            let deletedCount = countBefore - snapshotsAfter.count

            AppLogger.shared.success("Thinned \(deletedCount) snapshots")
            return SnapshotDeletionResult(
                success: true,
                deletedCount: max(0, deletedCount),
                freedBytes: 0  // Actual freed space is hard to determine
            )
        } else {
            let error = SnapshotError(snapshot: "/", reason: result.error)
            return SnapshotDeletionResult(success: false, errors: [error])
        }
    }

    /// Delete all local snapshots (convenience method)
    ///
    /// - Parameter dryRun: If true, only simulate the operation
    public func deleteAllSnapshots(dryRun: Bool = false) async throws -> SnapshotDeletionResult {
        return try await thinSnapshots(keepBytes: 9999999999999, dryRun: dryRun)
    }

    // MARK: - Command Execution

    /// Result of a command execution
    private struct CommandResult {
        let exitCode: Int32
        let output: String
        let error: String
    }

    /// Run tmutil command with arguments
    private func runTmutil(_ arguments: [String]) -> CommandResult {
        return runCommand("/usr/bin/tmutil", arguments: arguments)
    }

    /// Run a command with arguments
    private func runCommand(_ command: String, arguments: [String]) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return CommandResult(
                exitCode: process.terminationStatus,
                output: output,
                error: error
            )
        } catch {
            return CommandResult(
                exitCode: -1,
                output: "",
                error: error.localizedDescription
            )
        }
    }
}

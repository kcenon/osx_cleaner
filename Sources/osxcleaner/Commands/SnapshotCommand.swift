// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct SnapshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Manage Time Machine local snapshots",
        discussion: """
            View and manage local APFS snapshots created by Time Machine.
            Local snapshots can consume significant disk space (10-50GB or more).

            Examples:
              osxcleaner snapshot list
              osxcleaner snapshot status
              osxcleaner snapshot delete 2025-12-26-120000
              osxcleaner snapshot thin --dry-run
            """,
        subcommands: [
            ListSnapshots.self,
            StatusSnapshots.self,
            DeleteSnapshots.self,
            ThinSnapshots.self
        ],
        defaultSubcommand: ListSnapshots.self
    )
}

// MARK: - List Subcommand

extension SnapshotCommand {
    struct ListSnapshots: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all local Time Machine snapshots"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        @Option(name: .long, help: "Volume to list snapshots for (default: /)")
        var volume: String = "/"

        @Flag(name: .shortAndLong, help: "Show detailed information")
        var verbose: Bool = false

        mutating func run() async throws {
            let output = OutputHandler(format: format, quiet: false, verbose: verbose)
            let service = TimeMachineService()

            output.display(message: "Listing local snapshots for \(volume)...", level: .verbose)

            do {
                let snapshots = try await service.listLocalSnapshots(volume: volume)

                if snapshots.isEmpty {
                    output.display(message: "No local snapshots found.", level: .normal)
                    return
                }

                if format == .json {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                    let jsonData = try encoder.encode(snapshots.map { snapshot in
                        SnapshotJSON(
                            id: snapshot.id,
                            date: snapshot.date,
                            volume: snapshot.volume
                        )
                    })

                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    output.display(message: "Found \(snapshots.count) local snapshot(s):", level: .normal)
                    print("")

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short

                    for (index, snapshot) in snapshots.enumerated() {
                        let dateStr = dateFormatter.string(from: snapshot.date)
                        print("  \(index + 1). \(dateStr)")
                        if verbose {
                            print("     ID: \(snapshot.id)")
                            print("     Volume: \(snapshot.volume)")
                        }
                    }

                    print("")
                    output.display(
                        message: "Use 'osxcleaner snapshot delete <date>' to remove snapshots.",
                        level: .normal
                    )
                }
            } catch {
                output.displayError(error)
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }
        }
    }
}

// MARK: - Status Subcommand

extension SnapshotCommand {
    struct StatusSnapshots: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show Time Machine status and backup information"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let output = OutputHandler(format: format, quiet: false, verbose: false)
            let service = TimeMachineService()

            do {
                let status = try await service.getStatus()

                if format == .json {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                    let statusJSON = TimeMachineStatusJSON(
                        isEnabled: status.isEnabled,
                        isBackingUp: status.isBackingUp,
                        lastBackupDate: status.lastBackupDate,
                        backupDestination: status.backupDestination
                    )

                    let jsonData = try encoder.encode(statusJSON)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("")
                    print("Time Machine Status")
                    print("─────────────────────────────────────────")
                    print("  Enabled:            \(status.isEnabled ? "Yes ✓" : "No ✗")")
                    print("  Currently Backing Up: \(status.isBackingUp ? "Yes" : "No")")

                    if let lastBackup = status.formattedLastBackup {
                        print("  Last Backup:        \(lastBackup)")
                    } else {
                        print("  Last Backup:        Never")
                    }

                    if let destination = status.backupDestination {
                        print("  Destination:        \(destination)")
                    }

                    // Also show local snapshot count
                    let snapshots = try await service.listLocalSnapshots()
                    print("  Local Snapshots:    \(snapshots.count)")
                    print("─────────────────────────────────────────")
                    print("")
                }
            } catch {
                output.displayError(error)
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }
        }
    }
}

// MARK: - Delete Subcommand

extension SnapshotCommand {
    struct DeleteSnapshots: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a specific snapshot by date"
        )

        @Argument(help: "Snapshot date to delete (format: YYYY-MM-DD-HHMMSS)")
        var date: String

        @Flag(name: .long, help: "Simulate deletion without actually deleting")
        var dryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let service = TimeMachineService()

            // Parse date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"

            guard let snapshotDate = formatter.date(from: date) else {
                print("Error: Invalid date format. Use YYYY-MM-DD-HHMMSS (e.g., 2025-12-26-120000)")
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }

            // Confirm deletion
            if !force && !dryRun {
                print("")
                print("⚠️  Warning: Snapshot deletion is irreversible!")
                print("    Snapshot date: \(date)")
                print("")
                print("Are you sure you want to delete this snapshot? (y/N): ", terminator: "")

                guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                    print("Deletion cancelled.")
                    return
                }
            }

            do {
                let result = try await service.deleteSnapshot(date: snapshotDate, dryRun: dryRun)

                if result.success {
                    if dryRun {
                        print("✓ [DRY RUN] Would delete snapshot: \(date)")
                    } else {
                        print("✓ Successfully deleted snapshot: \(date)")
                    }
                } else {
                    for error in result.errors {
                        print("✗ Error: \(error.reason)")
                    }
                    throw ArgumentParser.ExitCode(ExitCode.generalError)
                }
            } catch let error as SnapshotError {
                print("✗ Error: \(error.reason)")
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }
        }
    }
}

// MARK: - Thin Subcommand

extension SnapshotCommand {
    struct ThinSnapshots: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "thin",
            abstract: "Thin (remove) all local snapshots to free space"
        )

        @Flag(name: .long, help: "Simulate thinning without actually deleting")
        var dryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        @Flag(name: .shortAndLong, help: "Show detailed output")
        var verbose: Bool = false

        mutating func run() async throws {
            let service = TimeMachineService()

            // Show current snapshot count
            let snapshots = try await service.listLocalSnapshots()

            if snapshots.isEmpty {
                print("No local snapshots to thin.")
                return
            }

            print("")
            print("Found \(snapshots.count) local snapshot(s) to thin.")

            // Confirm deletion
            if !force && !dryRun {
                print("")
                print("⚠️  Warning: This will remove ALL local Time Machine snapshots!")
                print("    This operation is irreversible.")
                print("")
                print("Are you sure you want to thin all snapshots? (y/N): ", terminator: "")

                guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                    print("Thinning cancelled.")
                    return
                }
            }

            do {
                let result = try await service.thinSnapshots(dryRun: dryRun)

                if result.success {
                    if dryRun {
                        print("✓ [DRY RUN] Would thin \(result.deletedCount) snapshot(s)")
                    } else {
                        print("✓ Successfully thinned \(result.deletedCount) snapshot(s)")
                    }
                } else {
                    for error in result.errors {
                        print("✗ Error: \(error.reason)")
                    }
                    throw ArgumentParser.ExitCode(ExitCode.generalError)
                }
            } catch let error as SnapshotError {
                print("✗ Error: \(error.reason)")
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }
        }
    }
}

// MARK: - JSON Types

private struct SnapshotJSON: Codable {
    let id: String
    let date: Date
    let volume: String
}

private struct TimeMachineStatusJSON: Codable {
    let isEnabled: Bool
    let isBackingUp: Bool
    let lastBackupDate: Date?
    let backupDestination: String?
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct LogsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Manage logs and crash reports",
        discussion: """
            Analyze and clean system logs and crash reports.
            View crash report analysis before cleanup to identify problematic apps.

            Examples:
              osxcleaner logs analyze
              osxcleaner logs analyze --format json
              osxcleaner logs clean --age 30
              osxcleaner logs clean --dry-run
            """,
        subcommands: [
            AnalyzeLogs.self,
            CleanLogs.self
        ],
        defaultSubcommand: AnalyzeLogs.self
    )
}

// MARK: - Analyze Logs

extension LogsCommand {
    struct AnalyzeLogs: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "analyze",
            abstract: "Analyze crash reports and logs"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        @Flag(name: .shortAndLong, help: "Show detailed information")
        var verbose: Bool = false

        mutating func run() async throws {
            let output = OutputHandler(format: format, quiet: false, verbose: verbose)
            let analysisService = CrashReportAnalysisService.shared

            output.display(message: "Analyzing crash reports...", level: .verbose)

            do {
                let analysis = try await analysisService.analyze()

                if format == .json {
                    displayJSONAnalysis(analysis)
                } else {
                    displayTextAnalysis(analysis, output: output)
                }
            } catch {
                output.displayError(error)
                throw ArgumentParser.ExitCode(ExitCode.generalError)
            }
        }

        private func displayTextAnalysis(_ analysis: CrashReportAnalysis, output: OutputHandler) {
            print("")
            print("Crash Report Analysis")
            print("─────────────────────────────────────────")

            if analysis.summaries.isEmpty {
                print("  No crash reports found.")
                print("")
                return
            }

            // Display app summaries
            for summary in analysis.summaries {
                let warningIcon = summary.hasRepeatedCrashes ? " ⚠️ Repeated crashes" : ""
                print("  \(summary.appName): \(summary.reportCount) reports (latest: \(summary.latestCrashRelative))\(warningIcon)")

                if verbose {
                    print("    Size: \(summary.formattedSize)")
                }
            }

            print("")
            print("─────────────────────────────────────────")
            print("  Total: \(analysis.totalReports) reports (\(analysis.formattedTotalSize))")

            if analysis.reportsOlderThan30Days > 0 {
                print("  Reports older than 30 days: \(analysis.reportsOlderThan30Days) reports (\(analysis.formattedOlderSize))")
            }

            print("")

            // Show recommendations
            let appsWithRepeatedCrashes = analysis.summaries.filter { $0.hasRepeatedCrashes }
            if !appsWithRepeatedCrashes.isEmpty {
                print("💡 Recommendation:")
                print("   The following apps have repeated crashes. Consider:")
                print("   - Updating to the latest version")
                print("   - Reinstalling the app")
                print("   - Checking for known issues")
                print("")
                for app in appsWithRepeatedCrashes {
                    print("   • \(app.appName) (\(app.reportCount) crashes)")
                }
                print("")
            }

            if analysis.reportsOlderThan30Days > 0 {
                print("Run 'osxcleaner logs clean --age 30' to remove old reports.")
                print("")
            }
        }

        private func displayJSONAnalysis(_ analysis: CrashReportAnalysis) {
            struct JSONOutput: Encodable {
                let totalReports: Int
                let totalSize: UInt64
                let totalSizeFormatted: String
                let reportsOlderThan30Days: Int
                let sizeOlderThan30Days: UInt64
                let apps: [AppSummaryJSON]

                struct AppSummaryJSON: Encodable {
                    let name: String
                    let reportCount: Int
                    let latestCrashDate: Date
                    let totalSize: UInt64
                    let hasRepeatedCrashes: Bool

                    enum CodingKeys: String, CodingKey {
                        case name
                        case reportCount = "report_count"
                        case latestCrashDate = "latest_crash_date"
                        case totalSize = "total_size"
                        case hasRepeatedCrashes = "has_repeated_crashes"
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case totalReports = "total_reports"
                    case totalSize = "total_size"
                    case totalSizeFormatted = "total_size_formatted"
                    case reportsOlderThan30Days = "reports_older_than_30_days"
                    case sizeOlderThan30Days = "size_older_than_30_days"
                    case apps
                }
            }

            let output = JSONOutput(
                totalReports: analysis.totalReports,
                totalSize: analysis.totalSize,
                totalSizeFormatted: analysis.formattedTotalSize,
                reportsOlderThan30Days: analysis.reportsOlderThan30Days,
                sizeOlderThan30Days: analysis.sizeOlderThan30Days,
                apps: analysis.summaries.map { summary in
                    JSONOutput.AppSummaryJSON(
                        name: summary.appName,
                        reportCount: summary.reportCount,
                        latestCrashDate: summary.latestCrashDate,
                        totalSize: summary.totalSize,
                        hasRepeatedCrashes: summary.hasRepeatedCrashes
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let jsonData = try? encoder.encode(output),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// MARK: - Clean Logs

extension LogsCommand {
    struct CleanLogs: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clean",
            abstract: "Clean logs and crash reports"
        )

        @Option(name: .long, help: "Delete files older than N days (default: 30)")
        var age: Int = 30

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        @Flag(name: .long, help: "Simulate cleanup without deleting files")
        var dryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        @Flag(name: .shortAndLong, help: "Show detailed output")
        var verbose: Bool = false

        @Flag(name: .long, help: "Clean all logs regardless of age")
        var all: Bool = false

        mutating func run() async throws {
            let output = OutputHandler(format: format, quiet: false, verbose: verbose)
            let analysisService = CrashReportAnalysisService.shared

            // First show analysis
            let analysis = try await analysisService.analyze()

            if analysis.totalReports == 0 {
                output.display(message: "No crash reports found to clean.", level: .normal)
                return
            }

            // Show what will be cleaned
            if !all {
                output.display(message: "Reports older than \(age) days: \(analysis.reportsOlderThan30Days) (\(analysis.formattedOlderSize))", level: .normal)
            } else {
                output.display(message: "All reports: \(analysis.totalReports) (\(analysis.formattedTotalSize))", level: .normal)
            }

            // Confirm deletion
            if !force && !dryRun {
                print("")
                print("⚠️  Warning: This will delete crash report files.")
                print("    This operation is irreversible.")
                print("")
                print("Are you sure you want to proceed? (y/N): ", terminator: "")

                guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                    print("Cleanup cancelled.")
                    return
                }
            }

            // Perform cleanup
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser.path
            let logsPath = "\(home)/Library/Logs"
            let diagnosticReportsPath = "\(logsPath)/DiagnosticReports"

            var filesRemoved = 0
            var bytesFreed: UInt64 = 0
            var errors: [String] = []

            // Calculate age threshold
            let ageThreshold = all ? Date.distantPast : Calendar.current.date(byAdding: .day, value: -age, to: Date()) ?? Date()

            // Clean crash reports
            if let enumerator = fileManager.enumerator(atPath: diagnosticReportsPath) {
                while let file = enumerator.nextObject() as? String {
                    let fullPath = (diagnosticReportsPath as NSString).appendingPathComponent(file)

                    // Check if it's a crash report file
                    let isCrashReport = CrashReport.ReportType.allCases.contains { type in
                        file.hasSuffix(type.rawValue)
                    }

                    guard isCrashReport else { continue }

                    // Get file attributes
                    guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                          let modDate = attrs[.modificationDate] as? Date,
                          let size = attrs[.size] as? UInt64 else {
                        continue
                    }

                    // Check age
                    guard modDate < ageThreshold else { continue }

                    if dryRun {
                        output.display(message: "[DRY RUN] Would delete: \(file)", level: .verbose)
                        filesRemoved += 1
                        bytesFreed += size
                    } else {
                        do {
                            try fileManager.removeItem(atPath: fullPath)
                            filesRemoved += 1
                            bytesFreed += size
                            output.display(message: "Deleted: \(file)", level: .verbose)
                        } catch {
                            errors.append("\(file): \(error.localizedDescription)")
                        }
                    }
                }
            }

            // Display results
            print("")
            if dryRun {
                output.displaySuccess("[DRY RUN] Would remove \(filesRemoved) files (\(ByteCountFormatter.string(fromByteCount: Int64(bytesFreed), countStyle: .file)))")
            } else {
                output.displaySuccess("Removed \(filesRemoved) files (\(ByteCountFormatter.string(fromByteCount: Int64(bytesFreed), countStyle: .file)))")
            }

            if !errors.isEmpty && verbose {
                print("")
                output.displayWarning("Errors occurred:")
                for error in errors.prefix(5) {
                    print("  - \(error)")
                }
                if errors.count > 5 {
                    print("  ... and \(errors.count - 5) more")
                }
            }
        }
    }
}

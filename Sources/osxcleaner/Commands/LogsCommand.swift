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

// MARK: - JSON Output Types

private struct CrashReportJSONOutput: Encodable {
    let totalReports: Int
    let totalSize: UInt64
    let totalSizeFormatted: String
    let reportsOlderThan30Days: Int
    let sizeOlderThan30Days: UInt64
    let apps: [AppSummaryJSON]

    enum CodingKeys: String, CodingKey {
        case totalReports = "total_reports"
        case totalSize = "total_size"
        case totalSizeFormatted = "total_size_formatted"
        case reportsOlderThan30Days = "reports_older_than_30_days"
        case sizeOlderThan30Days = "size_older_than_30_days"
        case apps
    }
}

private struct AppSummaryJSON: Encodable {
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

            displayAppSummaries(analysis.summaries)
            displayAnalysisSummary(analysis)
            displayRecommendations(analysis)
        }

        private func displayAppSummaries(_ summaries: [AppCrashSummary]) {
            for summary in summaries {
                let warningIcon = summary.hasRepeatedCrashes ? " ⚠️ Repeated crashes" : ""
                print("  \(summary.appName): \(summary.reportCount) reports (latest: \(summary.latestCrashRelative))\(warningIcon)")

                if verbose {
                    print("    Size: \(summary.formattedSize)")
                }
            }
        }

        private func displayAnalysisSummary(_ analysis: CrashReportAnalysis) {
            print("")
            print("─────────────────────────────────────────")
            print("  Total: \(analysis.totalReports) reports (\(analysis.formattedTotalSize))")

            if analysis.reportsOlderThan30Days > 0 {
                let olderMsg = "  Reports older than 30 days: \(analysis.reportsOlderThan30Days) reports"
                print("\(olderMsg) (\(analysis.formattedOlderSize))")
            }

            print("")
        }

        private func displayRecommendations(_ analysis: CrashReportAnalysis) {
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
            let output = CrashReportJSONOutput(
                totalReports: analysis.totalReports,
                totalSize: analysis.totalSize,
                totalSizeFormatted: analysis.formattedTotalSize,
                reportsOlderThan30Days: analysis.reportsOlderThan30Days,
                sizeOlderThan30Days: analysis.sizeOlderThan30Days,
                apps: analysis.summaries.map { summary in
                    AppSummaryJSON(
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

            let analysis = try await analysisService.analyze()

            if analysis.totalReports == 0 {
                output.display(message: "No crash reports found to clean.", level: .normal)
                return
            }

            displayCleanupPreview(analysis, output: output)

            guard shouldProceedWithCleanup() else {
                print("Cleanup cancelled.")
                return
            }

            let result = performCleanup(output: output)
            displayCleanupResults(result, output: output)
        }

        private func displayCleanupPreview(_ analysis: CrashReportAnalysis, output: OutputHandler) {
            if !all {
                let msg = "Reports older than \(age) days: \(analysis.reportsOlderThan30Days)"
                output.display(message: "\(msg) (\(analysis.formattedOlderSize))", level: .normal)
            } else {
                let msg = "All reports: \(analysis.totalReports)"
                output.display(message: "\(msg) (\(analysis.formattedTotalSize))", level: .normal)
            }
        }

        private func shouldProceedWithCleanup() -> Bool {
            if force || dryRun {
                return true
            }

            print("")
            print("⚠️  Warning: This will delete crash report files.")
            print("    This operation is irreversible.")
            print("")
            print("Are you sure you want to proceed? (y/N): ", terminator: "")

            guard let response = readLine()?.lowercased() else {
                return false
            }
            return response == "y" || response == "yes"
        }

        private func performCleanup(output: OutputHandler) -> CleanupResult {
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser.path
            let diagnosticReportsPath = "\(home)/Library/Logs/DiagnosticReports"

            var result = CleanupResult()
            let ageThreshold = calculateAgeThreshold()

            guard let enumerator = fileManager.enumerator(atPath: diagnosticReportsPath) else {
                return result
            }

            while let file = enumerator.nextObject() as? String {
                processFile(
                    file,
                    basePath: diagnosticReportsPath,
                    ageThreshold: ageThreshold,
                    output: output,
                    result: &result
                )
            }

            return result
        }

        private func calculateAgeThreshold() -> Date {
            if all {
                return Date.distantPast
            }
            return Calendar.current.date(byAdding: .day, value: -age, to: Date()) ?? Date()
        }

        private func processFile(
            _ file: String,
            basePath: String,
            ageThreshold: Date,
            output: OutputHandler,
            result: inout CleanupResult
        ) {
            let fullPath = (basePath as NSString).appendingPathComponent(file)
            let fileManager = FileManager.default

            guard isCrashReportFile(file) else { return }

            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                  let modDate = attrs[.modificationDate] as? Date,
                  let size = attrs[.size] as? UInt64,
                  modDate < ageThreshold else {
                return
            }

            if dryRun {
                output.display(message: "[DRY RUN] Would delete: \(file)", level: .verbose)
                result.filesRemoved += 1
                result.bytesFreed += size
            } else {
                deleteFile(fullPath, file: file, size: size, output: output, result: &result)
            }
        }

        private func isCrashReportFile(_ file: String) -> Bool {
            CrashReport.ReportType.allCases.contains { type in
                file.hasSuffix(type.rawValue)
            }
        }

        private func deleteFile(
            _ fullPath: String,
            file: String,
            size: UInt64,
            output: OutputHandler,
            result: inout CleanupResult
        ) {
            do {
                try FileManager.default.removeItem(atPath: fullPath)
                result.filesRemoved += 1
                result.bytesFreed += size
                output.display(message: "Deleted: \(file)", level: .verbose)
            } catch {
                result.errors.append("\(file): \(error.localizedDescription)")
            }
        }

        private func displayCleanupResults(_ result: CleanupResult, output: OutputHandler) {
            print("")
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(result.bytesFreed), countStyle: .file)

            if dryRun {
                output.displaySuccess("[DRY RUN] Would remove \(result.filesRemoved) files (\(sizeStr))")
            } else {
                output.displaySuccess("Removed \(result.filesRemoved) files (\(sizeStr))")
            }

            if !result.errors.isEmpty && verbose {
                print("")
                output.displayWarning("Errors occurred:")
                for error in result.errors.prefix(5) {
                    print("  - \(error)")
                }
                if result.errors.count > 5 {
                    print("  ... and \(result.errors.count - 5) more")
                }
            }
        }
    }
}

// MARK: - Helper Types

private struct CleanupResult {
    var filesRemoved: Int = 0
    var bytesFreed: UInt64 = 0
    var errors: [String] = []
}

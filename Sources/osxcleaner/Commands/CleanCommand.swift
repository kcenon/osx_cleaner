// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct CleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean specified targets with safety checks",
        discussion: """
            Performs disk cleanup based on the specified level and targets.
            Use --dry-run to preview what would be cleaned without deletion.

            Examples:
              osxcleaner clean --level light
              osxcleaner clean --level deep --target developer
              osxcleaner clean --level normal --dry-run
              osxcleaner clean --level deep --non-interactive --format json
            """
    )

    // MARK: - Options

    @Option(name: .shortAndLong, help: "Cleanup level (light, normal, deep, system)")
    var level: CleanupLevel = .normal

    @Option(name: .shortAndLong, help: "Cleanup target (browser, developer, logs, all)")
    var target: CleanupTarget = .all

    @Option(name: .long, help: "Output format (text, json)")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Minimum available space threshold (triggers cleanup if below)")
    var minSpace: UInt64?

    @Option(name: .long, help: "Unit for min-space (mb, gb, tb)")
    var minSpaceUnit: SpaceUnit = .gb

    // MARK: - Flags

    @Flag(name: .shortAndLong, help: "Perform dry run without actual deletion")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Skip confirmation prompts (for CI/CD)")
    var nonInteractive: Bool = false

    @Flag(name: .shortAndLong, help: "Minimal output")
    var quiet: Bool = false

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Ignore team configuration policies")
    var ignoreTeam: Bool = false

    // MARK: - Arguments

    @Argument(help: "Specific paths to clean (optional)")
    var paths: [String] = []

    // MARK: - Run

    mutating func run() async throws {
        let output = OutputHandler(format: format, quiet: quiet, verbose: verbose)
        let startTime = Date()
        let diskMonitor = DiskMonitoringService.shared

        let diskInfoBefore = try getDiskSpaceBefore(output: output, diskMonitor: diskMonitor)

        if try checkMinSpaceThreshold(diskInfoBefore: diskInfoBefore, output: output) {
            return
        }

        displayStartupInfo(output: output)

        try await performCleanup(
            output: output,
            diskMonitor: diskMonitor,
            diskInfoBefore: diskInfoBefore,
            startTime: startTime
        )
    }

    private func getDiskSpaceBefore(
        output: OutputHandler,
        diskMonitor: DiskMonitoringService
    ) throws -> DiskSpaceInfo {
        do {
            return try diskMonitor.getDiskSpace()
        } catch {
            output.displayError(error)
            throw ExitCode.generalError
        }
    }

    private func checkMinSpaceThreshold(
        diskInfoBefore: DiskSpaceInfo,
        output: OutputHandler
    ) throws -> Bool {
        guard let threshold = minSpace else { return false }

        let thresholdBytes = threshold * minSpaceUnit.bytesMultiplier

        if diskInfoBefore.availableSpace >= thresholdBytes {
            displaySkippedResult(diskInfoBefore: diskInfoBefore, threshold: threshold, output: output)
            return true
        }

        let msg = "Available space (\(diskInfoBefore.formattedAvailable)) < threshold"
        output.display(
            message: "\(msg) (\(threshold) \(minSpaceUnit.rawValue.uppercased())), proceeding with cleanup",
            level: .normal
        )
        return false
    }

    private func displaySkippedResult(
        diskInfoBefore: DiskSpaceInfo,
        threshold: UInt64,
        output: OutputHandler
    ) {
        let skippedResult = CleanResultJSON(
            status: "skipped",
            dryRun: dryRun,
            freedBytes: 0,
            freedFormatted: "0 bytes",
            filesRemoved: 0,
            directoriesRemoved: 0,
            errorCount: 0,
            before: DiskSpaceJSON(from: diskInfoBefore),
            after: DiskSpaceJSON(from: diskInfoBefore),
            durationMs: 0
        )

        if format == .json {
            if let jsonData = try? JSONEncoder().encode(skippedResult),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            let available = diskInfoBefore.formattedAvailable
            let unit = minSpaceUnit.rawValue.uppercased()
            output.display(
                message: "Cleanup skipped: available space (\(available)) >= threshold (\(threshold) \(unit))",
                level: .normal
            )
        }
    }

    private func displayStartupInfo(output: OutputHandler) {
        output.display(message: "Starting cleanup...", level: .normal)
        output.display(message: "Cleanup level: \(level.description)", level: .verbose)
        output.display(message: "Target: \(target.description)", level: .verbose)

        if dryRun {
            output.display(message: "[DRY RUN] No files will be deleted", level: .normal)
        }
    }

    private func performCleanup(
        output: OutputHandler,
        diskMonitor: DiskMonitoringService,
        diskInfoBefore: DiskSpaceInfo,
        startTime: Date
    ) async throws {
        let config = buildConfiguration()
        let service = CleanerService()
        let triggerType: CleanupSession.TriggerType = nonInteractive ? .scheduled : .manual

        do {
            let result = try await service.clean(with: config, triggerType: triggerType)
            let diskInfoAfter = try diskMonitor.getDiskSpace()
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

            displayResult(
                result,
                output: output,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs
            )
        } catch {
            output.displayError(error)
            throw ExitCode.generalError
        }
    }

    // MARK: - Private Methods

    private func buildConfiguration() -> CleanerConfiguration {
        let includeSystem = target == .all
        let includeDeveloper = target == .developer || target == .all
        let includeBrowser = target == .browser || target == .all
        let includeLogs = target == .logs || target == .all

        // Check for team configuration
        let teamService = TeamConfigService.shared
        var effectiveDryRun = dryRun
        var effectiveLevel = level
        var effectivePaths = paths

        if !ignoreTeam, let teamConfig = teamService.getActiveConfig() {
            // Apply team policies
            if teamConfig.policies.enforceDryRun {
                effectiveDryRun = true
            }

            // Override cleanup level if team policy doesn't allow override
            if !teamConfig.policies.allowOverride {
                switch teamConfig.policies.cleanupLevel.lowercased() {
                case "light":
                    effectiveLevel = .light
                case "deep", "aggressive":
                    effectiveLevel = .deep
                case "system":
                    effectiveLevel = .system
                default:
                    effectiveLevel = .normal
                }
            }

            // Apply exclusions to specific paths
            if !effectivePaths.isEmpty {
                effectivePaths = teamService.applyExclusions(
                    to: effectivePaths,
                    using: teamConfig
                )
            }
        }

        return CleanerConfiguration(
            cleanupLevel: effectiveLevel,
            dryRun: effectiveDryRun,
            includeSystemCaches: includeSystem,
            includeDeveloperCaches: includeDeveloper,
            includeBrowserCaches: includeBrowser,
            includeLogsCaches: includeLogs,
            specificPaths: effectivePaths
        )
    }

    private func displayResult(
        _ result: CleanResult,
        output: OutputHandler,
        diskInfoBefore: DiskSpaceInfo,
        diskInfoAfter: DiskSpaceInfo,
        durationMs: Int
    ) {
        switch format {
        case .text:
            displayTextResult(
                result,
                output: output,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs
            )
        case .json:
            displayJSONResult(
                result,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs
            )
        }
    }

    private func displayTextResult(
        _ result: CleanResult,
        output: OutputHandler,
        diskInfoBefore: DiskSpaceInfo,
        diskInfoAfter: DiskSpaceInfo,
        durationMs: Int
    ) {
        output.display(message: "", level: .normal)
        output.displaySuccess("Cleanup completed!")
        output.display(message: "Freed: \(result.formattedFreedSpace)", level: .normal)
        output.display(message: "Files removed: \(result.filesRemoved)", level: .normal)

        if result.directoriesRemoved > 0 {
            output.display(
                message: "Directories removed: \(result.directoriesRemoved)",
                level: .normal
            )
        }

        output.display(
            message: "Available space: \(diskInfoBefore.formattedAvailable) → \(diskInfoAfter.formattedAvailable)",
            level: .verbose
        )
        output.display(
            message: "Duration: \(durationMs)ms",
            level: .verbose
        )

        if !result.errors.isEmpty && verbose {
            output.display(message: "", level: .normal)
            output.displayWarning("\(result.errors.count) errors occurred:")
            for error in result.errors.prefix(5) {
                output.display(message: "  - \(error.path): \(error.reason)", level: .normal)
            }
            if result.errors.count > 5 {
                output.display(
                    message: "  ... and \(result.errors.count - 5) more",
                    level: .normal
                )
            }
        }
    }

    private func displayJSONResult(
        _ result: CleanResult,
        diskInfoBefore: DiskSpaceInfo,
        diskInfoAfter: DiskSpaceInfo,
        durationMs: Int
    ) {
        let jsonOutput = CleanResultJSON(
            status: result.errors.isEmpty ? "success" : "completed_with_errors",
            dryRun: dryRun,
            freedBytes: result.freedBytes,
            freedFormatted: result.formattedFreedSpace,
            filesRemoved: result.filesRemoved,
            directoriesRemoved: result.directoriesRemoved,
            errorCount: result.errors.count,
            before: DiskSpaceJSON(from: diskInfoBefore),
            after: DiskSpaceJSON(from: diskInfoAfter),
            durationMs: durationMs
        )

        if let jsonData = try? JSONEncoder().encode(jsonOutput),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

// MARK: - Exit Code Conformance

extension Int32: @retroactive Error {}

// MARK: - JSON Output Structure

private struct DiskSpaceJSON: Encodable {
    let total: UInt64
    let used: UInt64
    let available: UInt64

    init(from info: DiskSpaceInfo) {
        self.total = info.totalSpace
        self.used = info.usedSpace
        self.available = info.availableSpace
    }
}

private struct CleanResultJSON: Encodable {
    let status: String
    let dryRun: Bool
    let freedBytes: UInt64
    let freedFormatted: String
    let filesRemoved: Int
    let directoriesRemoved: Int
    let errorCount: Int
    let before: DiskSpaceJSON
    let after: DiskSpaceJSON
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case status
        case dryRun = "dry_run"
        case freedBytes = "freed_bytes"
        case freedFormatted = "freed_formatted"
        case filesRemoved = "files_removed"
        case directoriesRemoved = "directories_removed"
        case errorCount = "error_count"
        case before
        case after
        case durationMs = "duration_ms"
    }
}

// MARK: - Output Handler

struct OutputHandler {
    enum Level {
        case quiet
        case normal
        case verbose
    }

    private let format: OutputFormat
    private let quietMode: Bool
    private let verboseMode: Bool
    private let progressView: ProgressView

    init(format: OutputFormat, quiet: Bool, verbose: Bool) {
        self.format = format
        self.quietMode = quiet
        self.verboseMode = verbose
        self.progressView = ProgressView()
    }

    func display(message: String, level: Level) {
        guard format == .text else { return }

        switch level {
        case .quiet:
            progressView.display(message: message)
        case .normal:
            if !quietMode {
                progressView.display(message: message)
            }
        case .verbose:
            if verboseMode && !quietMode {
                progressView.display(message: message)
            }
        }
    }

    func displayError(_ error: Error) {
        progressView.displayError(error)
    }

    func displayWarning(_ message: String) {
        if format == .text && !quietMode {
            progressView.displayWarning(message)
        }
    }

    func displaySuccess(_ message: String) {
        if format == .text && !quietMode {
            progressView.displaySuccess(message)
        }
    }
}

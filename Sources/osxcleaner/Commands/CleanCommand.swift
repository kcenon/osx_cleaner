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
              osxcleaner clean --level deep --non-interactive --force --format json
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

    @Flag(name: .long, help: "Confirm destructive cleanup without prompting")
    var force: Bool = false

    @Flag(name: .shortAndLong, help: "Minimal output")
    var quiet: Bool = false

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Ignore team configuration policies")
    var ignoreTeam: Bool = false

    // MARK: - Arguments

    @Argument(help: "Specific paths to clean (optional)")
    var paths: [String] = []

    private var validatedPaths: [String]?

    // MARK: - Validation

    mutating func validate() throws {
        // Validate custom paths if provided
        if !paths.isEmpty {
            validatedPaths = try canonicalSpecificPaths()
        }

        // Check conflicting options: dryRun and nonInteractive
        if dryRun && !nonInteractive {
            // This is not conflicting - dry run without non-interactive is valid
        }

        // Validate quiet and verbose cannot be used together
        if quiet && verbose {
            throw ValidationError.conflictingOptions("Cannot use --quiet with --verbose")
        }

        // Validate minSpace is positive if provided
        if let minSpaceValue = minSpace {
            guard minSpaceValue > 0 else {
                throw ValidationError.invalidCheckInterval(Int(minSpaceValue))
            }
        }
    }

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
        let config = try buildConfiguration()
        let service = CleanerService()
        let triggerType: CleanupSession.TriggerType = nonInteractive ? .scheduled : .manual

        do {
            let plan = try buildCleanupPlan(from: config)

            if config.dryRun {
                let result = try await service.clean(with: config, triggerType: .manual)
                let diskInfoAfter = try diskMonitor.getDiskSpace()
                let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

                displayCleanupPreview(plan: plan, result: result, output: output, dryRunOnly: true)
                displayResult(
                    result,
                    output: output,
                    diskInfoBefore: diskInfoBefore,
                    diskInfoAfter: diskInfoAfter,
                    durationMs: durationMs,
                    dryRun: true
                )
                return
            }

            try enforceExecutionPolicy(for: plan)

            let previewConfig = configuration(config, dryRun: true)
            let previewResult = try await service.clean(with: previewConfig, triggerType: .manual)
            displayCleanupPreview(plan: plan, result: previewResult, output: output, dryRunOnly: false)
            try confirmExecutionIfNeeded(plan: plan, previewResult: previewResult, output: output)

            let result = try await service.clean(with: config, triggerType: triggerType)
            let diskInfoAfter = try diskMonitor.getDiskSpace()
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

            displayResult(
                result,
                output: output,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs,
                dryRun: config.dryRun
            )
        } catch {
            output.displayError(error)
            throw ExitCode.generalError
        }
    }

    // MARK: - Private Methods

    private func buildConfiguration() throws -> CleanerConfiguration {
        let hasSpecificPaths = !paths.isEmpty
        let includeSystem = !hasSpecificPaths && target == .all
        let includeDeveloper = !hasSpecificPaths && (target == .developer || target == .all)
        let includeBrowser = !hasSpecificPaths && (target == .browser || target == .all)
        let includeLogs = !hasSpecificPaths && (target == .logs || target == .all)

        // Check for team configuration
        let teamService = TeamConfigService.shared
        var effectiveDryRun = dryRun
        var effectiveLevel = level
        var effectivePaths = try canonicalSpecificPaths()

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

    private func canonicalSpecificPaths() throws -> [String] {
        guard !paths.isEmpty else { return [] }
        if let validatedPaths {
            return validatedPaths
        }

        let options = PathValidator.ValidationOptions.lenient
        return try PathValidator.validateAll(paths, options: options).map(\.path)
    }

    private func configuration(_ config: CleanerConfiguration, dryRun: Bool) -> CleanerConfiguration {
        CleanerConfiguration(
            cleanupLevel: config.cleanupLevel,
            dryRun: dryRun,
            includeSystemCaches: config.includeSystemCaches,
            includeDeveloperCaches: config.includeDeveloperCaches,
            includeBrowserCaches: config.includeBrowserCaches,
            includeLogsCaches: config.includeLogsCaches,
            specificPaths: config.specificPaths
        )
    }

    private func buildCleanupPlan(from config: CleanerConfiguration) throws -> CleanupPlan {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var targets: [CleanupPlanTarget] = []

        if config.includeSystemCaches {
            targets.append(try planTarget(path: "\(home)/Library/Caches", label: "User caches"))
            targets.append(try planTarget(path: "/Library/Caches", label: "System caches"))
        }

        if config.includeDeveloperCaches {
            targets.append(try planTarget(
                path: "\(home)/Library/Developer/Xcode/DerivedData",
                label: "Xcode DerivedData"
            ))
            targets.append(try planTarget(
                path: "\(home)/Library/Developer/Xcode/Archives",
                label: "Xcode Archives"
            ))
            targets.append(try planTarget(path: "\(home)/.gradle/caches", label: "Gradle cache"))
            targets.append(try planTarget(path: "\(home)/.npm/_cacache", label: "npm cache"))
            targets.append(try planTarget(
                path: "\(home)/.cargo/registry/cache",
                label: "Cargo registry cache"
            ))
        }

        if config.includeBrowserCaches {
            targets.append(try planTarget(
                path: "\(home)/Library/Caches/com.apple.Safari",
                label: "Safari cache"
            ))
            targets.append(try planTarget(
                path: "\(home)/Library/Caches/Google/Chrome",
                label: "Chrome cache"
            ))
            targets.append(try planTarget(
                path: "\(home)/Library/Caches/Firefox",
                label: "Firefox cache"
            ))
        }

        if config.includeLogsCaches {
            targets.append(try planTarget(path: "\(home)/Library/Logs", label: "User logs"))
            targets.append(try planTarget(
                path: "\(home)/Library/Logs/DiagnosticReports",
                label: "Diagnostic reports"
            ))
        }

        for path in config.specificPaths {
            targets.append(try planTarget(path: path, label: "Custom path"))
        }

        return CleanupPlan(targets: targets, cleanupLevel: config.cleanupLevel)
    }

    private func planTarget(path: String, label: String) throws -> CleanupPlanTarget {
        let canonicalPath = try PathValidator.validatePath(path, options: .lenient)
        let safetyLevel = try PathValidator.safetyLevel(for: canonicalPath)
        return CleanupPlanTarget(label: label, path: canonicalPath, safetyLevel: safetyLevel)
    }

    private func enforceExecutionPolicy(for plan: CleanupPlan) throws {
        let blockedTargets = plan.targets.filter { $0.safetyLevel == .danger }
        guard blockedTargets.isEmpty else {
            let blockedPaths = blockedTargets.map(\.path).joined(separator: ", ")
            throw ValidationError.conflictingOptions(
                "Refusing to clean danger-level target(s): \(blockedPaths)"
            )
        }

        guard plan.requiresConfirmation, !force else { return }

        if nonInteractive {
            throw ValidationError.conflictingOptions(
                "--non-interactive requires --force for warning or system-level cleanup"
            )
        }
    }

    private func confirmExecutionIfNeeded(
        plan: CleanupPlan,
        previewResult: CleanResult,
        output: OutputHandler
    ) throws {
        guard plan.requiresConfirmation, !force else { return }

        let risky = plan.targets.filter { target in
            target.safetyLevel.requiresConfirmation &&
                plan.cleanupLevel.canDelete(target.safetyLevel)
        }

        let header: String
        if risky.isEmpty {
            // System-level cleanup always requires confirmation even without
            // explicit warning targets (e.g., level=system over only safe paths).
            header = "This cleanup runs at the system level and requires confirmation."
        } else {
            let bulletList = risky
                .map { target in
                    "  - [\(shortSafetyName(target.safetyLevel))] \(target.label): \(target.path)"
                }
                .joined(separator: "\n")
            header = """
                This cleanup will delete the following risky targets:
                \(bulletList)
                """
        }

        output.displayPrompt(
            """
            \(header)
            Estimated reclaimable space: \(previewResult.formattedFreedSpace)
            Type 'yes' to continue:
            """
        )

        let answer = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard answer == "yes" else {
            throw CleanupError.operationCancelled
        }
    }

    private func displayCleanupPreview(
        plan: CleanupPlan,
        result: CleanResult,
        output: OutputHandler,
        dryRunOnly: Bool
    ) {
        let title = dryRunOnly ? "Dry-run preview:" : "Cleanup preview:"
        let matchedItems = result.filesRemoved + result.directoriesRemoved

        output.display(message: "", level: .normal)
        output.display(message: title, level: .normal)
        output.display(message: "Targets: \(plan.targets.count)", level: .normal)
        output.display(message: "Safety levels: \(plan.safetySummary)", level: .normal)
        output.display(message: "Highest safety: \(plan.highestSafety.description)", level: .normal)
        output.display(message: "Estimated reclaimable space: \(result.formattedFreedSpace)", level: .normal)
        output.display(message: "Items matched: \(matchedItems)", level: .normal)

        displayPlanTargets(plan: plan, output: output)
        displayRiskyTargets(plan: plan, output: output)

        if dryRunOnly {
            displayDryRunPolicyHint(plan: plan, output: output)
        }

        if !result.errors.isEmpty {
            output.displayWarning("Skipped \(result.errors.count) target(s) due to safety or access policy")
        }
    }

    private func displayPlanTargets(plan: CleanupPlan, output: OutputHandler) {
        guard !plan.targets.isEmpty else { return }

        output.display(message: "Planned targets:", level: .normal)
        for target in plan.targets {
            let line = "  - [\(shortSafetyName(target.safetyLevel))] \(target.label): \(target.path)"
            output.display(message: line, level: .normal)
        }
    }

    private func displayRiskyTargets(plan: CleanupPlan, output: OutputHandler) {
        let risky = plan.targets.filter { target in
            target.safetyLevel.requiresConfirmation &&
                plan.cleanupLevel.canDelete(target.safetyLevel)
        }
        guard !risky.isEmpty else { return }

        output.display(message: "Risky targets requiring approval:", level: .normal)
        for target in risky {
            let line = "  ! [\(shortSafetyName(target.safetyLevel))] \(target.label): \(target.path)"
            output.display(message: line, level: .normal)
        }
    }

    private func displayDryRunPolicyHint(plan: CleanupPlan, output: OutputHandler) {
        guard plan.requiresConfirmation else { return }
        let message = "Note: a real run requires interactive 'yes' approval " +
            "or --non-interactive --force for the targets above."
        output.display(message: message, level: .normal)
    }

    private func shortSafetyName(_ level: SafetyLevel) -> String {
        switch level {
        case .safe:
            return "safe"
        case .caution:
            return "caution"
        case .warning:
            return "warning"
        case .danger:
            return "danger"
        }
    }

    private func displayResult(
        _ result: CleanResult,
        output: OutputHandler,
        diskInfoBefore: DiskSpaceInfo,
        diskInfoAfter: DiskSpaceInfo,
        durationMs: Int,
        dryRun: Bool
    ) {
        switch format {
        case .text:
            displayTextResult(
                result,
                output: output,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs,
                dryRun: dryRun
            )
        case .json:
            displayJSONResult(
                result,
                diskInfoBefore: diskInfoBefore,
                diskInfoAfter: diskInfoAfter,
                durationMs: durationMs,
                dryRun: dryRun
            )
        }
    }

    private func displayTextResult(
        _ result: CleanResult,
        output: OutputHandler,
        diskInfoBefore: DiskSpaceInfo,
        diskInfoAfter: DiskSpaceInfo,
        durationMs: Int,
        dryRun: Bool
    ) {
        output.display(message: "", level: .normal)
        output.displaySuccess(dryRun ? "Dry run completed!" : "Cleanup completed!")
        output.display(
            message: "\(dryRun ? "Would free" : "Freed"): \(result.formattedFreedSpace)",
            level: .normal
        )
        output.display(
            message: "\(dryRun ? "Files matched" : "Files removed"): \(result.filesRemoved)",
            level: .normal
        )

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
        durationMs: Int,
        dryRun: Bool
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

// MARK: - Cleanup Planning

private struct CleanupPlan {
    let targets: [CleanupPlanTarget]
    let cleanupLevel: CleanupLevel

    var highestSafety: SafetyLevel {
        targets.map(\.safetyLevel).max() ?? .safe
    }

    var requiresConfirmation: Bool {
        cleanupLevel == .system ||
            targets.contains { target in
                target.safetyLevel.requiresConfirmation &&
                    cleanupLevel.canDelete(target.safetyLevel)
            }
    }

    var safetySummary: String {
        let counts = Dictionary(grouping: targets, by: \.safetyLevel)
            .mapValues(\.count)

        let parts = SafetyLevel.allCases.compactMap { level -> String? in
            guard let count = counts[level], count > 0 else { return nil }
            return "\(shortName(for: level)): \(count)"
        }

        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }

    private func shortName(for level: SafetyLevel) -> String {
        switch level {
        case .safe:
            return "safe"
        case .caution:
            return "caution"
        case .warning:
            return "warning"
        case .danger:
            return "danger"
        }
    }
}

private struct CleanupPlanTarget {
    let label: String
    let path: String
    let safetyLevel: SafetyLevel
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

    func displayPrompt(_ message: String) {
        let output = message.hasSuffix("\n") ? message : message + "\n"
        FileHandle.standardError.write(Data(output.utf8))
    }

    func displaySuccess(_ message: String) {
        if format == .text && !quietMode {
            progressView.displaySuccess(message)
        }
    }
}

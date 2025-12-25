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

    // MARK: - Flags

    @Flag(name: .shortAndLong, help: "Perform dry run without actual deletion")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Skip confirmation prompts (for CI/CD)")
    var nonInteractive: Bool = false

    @Flag(name: .shortAndLong, help: "Minimal output")
    var quiet: Bool = false

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose: Bool = false

    // MARK: - Arguments

    @Argument(help: "Specific paths to clean (optional)")
    var paths: [String] = []

    // MARK: - Run

    mutating func run() async throws {
        let output = OutputHandler(format: format, quiet: quiet, verbose: verbose)

        output.display(message: "Starting cleanup...", level: .normal)
        output.display(message: "Cleanup level: \(level.description)", level: .verbose)
        output.display(message: "Target: \(target.description)", level: .verbose)

        if dryRun {
            output.display(message: "[DRY RUN] No files will be deleted", level: .normal)
        }

        let config = buildConfiguration()
        let service = CleanerService()

        do {
            let result = try await service.clean(with: config)
            displayResult(result, output: output)
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
        // Note: includeLogs will be used when CleanerConfiguration adds log cleanup support
        _ = target == .logs || target == .all

        return CleanerConfiguration(
            cleanupLevel: level,
            dryRun: dryRun,
            includeSystemCaches: includeSystem,
            includeDeveloperCaches: includeDeveloper,
            includeBrowserCaches: includeBrowser,
            specificPaths: paths
        )
    }

    private func displayResult(_ result: CleanResult, output: OutputHandler) {
        switch format {
        case .text:
            displayTextResult(result, output: output)
        case .json:
            displayJSONResult(result, output: output)
        }
    }

    private func displayTextResult(_ result: CleanResult, output: OutputHandler) {
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

    private func displayJSONResult(_ result: CleanResult, output: OutputHandler) {
        let jsonOutput = CleanResultJSON(
            status: result.errors.isEmpty ? "success" : "completed_with_errors",
            dryRun: dryRun,
            freedBytes: result.freedBytes,
            freedFormatted: result.formattedFreedSpace,
            filesRemoved: result.filesRemoved,
            directoriesRemoved: result.directoriesRemoved,
            errorCount: result.errors.count
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

private struct CleanResultJSON: Encodable {
    let status: String
    let dryRun: Bool
    let freedBytes: UInt64
    let freedFormatted: String
    let filesRemoved: Int
    let directoriesRemoved: Int
    let errorCount: Int

    enum CodingKeys: String, CodingKey {
        case status
        case dryRun = "dry_run"
        case freedBytes = "freed_bytes"
        case freedFormatted = "freed_formatted"
        case filesRemoved = "files_removed"
        case directoriesRemoved = "directories_removed"
        case errorCount = "error_count"
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

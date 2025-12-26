// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct TeamCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "team",
        abstract: "Manage team environment configuration",
        discussion: """
            Team configuration enables shared cleanup policies across development teams.
            Load configurations from local files or remote URLs (YAML/JSON supported).
            """,
        subcommands: [
            LoadTeamConfig.self,
            StatusTeamConfig.self,
            SyncTeamConfig.self,
            RemoveTeamConfig.self,
            SampleTeamConfig.self
        ],
        defaultSubcommand: StatusTeamConfig.self
    )
}

// MARK: - Load Command

extension TeamCommand {
    struct LoadTeamConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "load",
            abstract: "Load and apply team configuration"
        )

        @Argument(help: "Path to team configuration file (YAML or JSON) or remote URL")
        var source: String

        @Flag(name: .long, help: "Validate only without applying")
        var validateOnly: Bool = false

        @Option(name: .shortAndLong, help: "Output format (text/json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let progressView = ProgressView()
            let service = TeamConfigService.shared

            progressView.display(message: "Loading team configuration from: \(source)")

            do {
                let config: TeamConfig

                if source.hasPrefix("http://") || source.hasPrefix("https://") {
                    guard let url = URL(string: source) else {
                        throw TeamConfigError.parseError("Invalid URL: \(source)")
                    }
                    config = try await service.loadTeamConfig(from: url)
                } else {
                    config = try await service.loadTeamConfig(fromPath: source)
                }

                if validateOnly {
                    try service.validateConfig(config)
                    progressView.displaySuccess("Configuration is valid")
                    displayConfigSummary(config, using: progressView)
                } else {
                    try service.applyConfig(config)
                    progressView.displaySuccess("Team configuration applied successfully")
                    displayConfigSummary(config, using: progressView)
                }
            } catch let error as TeamConfigError {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }

        private func displayConfigSummary(_ config: TeamConfig, using progressView: ProgressView) {
            progressView.display(message: "")
            progressView.display(message: "=== Team Configuration Summary ===")
            progressView.display(message: "Team: \(config.team)")
            progressView.display(message: "Version: \(config.version)")
            progressView.display(message: "Cleanup Level: \(config.policies.cleanupLevel)")
            progressView.display(message: "Schedule: \(config.policies.schedule)")
            progressView.display(message: "Exclusions: \(config.exclusions.count) patterns")

            if let sync = config.sync, let url = sync.remoteURL {
                progressView.display(message: "Remote Sync: \(url)")
            }
        }
    }
}

// MARK: - Status Command

extension TeamCommand {
    struct StatusTeamConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show current team configuration status"
        )

        @Option(name: .shortAndLong, help: "Output format (text/json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let progressView = ProgressView()
            let service = TeamConfigService.shared
            let status = service.getStatus()

            if format == .json {
                let jsonData = try JSONEncoder().encode(StatusJSON(from: status))
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    progressView.display(message: jsonString)
                }
                return
            }

            progressView.display(message: "=== Team Configuration Status ===")
            progressView.display(message: "")

            if status.isActive {
                progressView.display(message: "Status: ✅ Active")
                progressView.display(message: "Team: \(status.teamName ?? "Unknown")")
                progressView.display(message: "Version: \(status.version ?? "Unknown")")
                progressView.display(message: "Cleanup Level: \(status.cleanupLevel ?? "Unknown")")
                progressView.display(message: "Schedule: \(status.schedule ?? "Unknown")")
                progressView.display(message: "Exclusions: \(status.exclusionsCount) patterns")
                progressView.display(message: "Last Sync: \(status.formattedLastSync)")

                if let remoteURL = status.remoteURL {
                    progressView.display(message: "Remote URL: \(remoteURL)")
                }
            } else {
                progressView.display(message: "Status: ❌ No active team configuration")
                progressView.display(message: "")
                progressView.display(message: "Use 'osxcleaner team load <path>' to load a configuration.")
                progressView.display(message: "Use 'osxcleaner team sample' to generate a sample configuration.")
            }
        }
    }

    private struct StatusJSON: Codable {
        let isActive: Bool
        let teamName: String?
        let version: String?
        let cleanupLevel: String?
        let schedule: String?
        let lastSyncTime: String?
        let remoteURL: String?
        let exclusionsCount: Int

        init(from status: TeamConfigStatus) {
            self.isActive = status.isActive
            self.teamName = status.teamName
            self.version = status.version
            self.cleanupLevel = status.cleanupLevel
            self.schedule = status.schedule
            self.lastSyncTime = status.lastSyncTime?.ISO8601Format()
            self.remoteURL = status.remoteURL
            self.exclusionsCount = status.exclusionsCount
        }
    }
}

// MARK: - Sync Command

extension TeamCommand {
    struct SyncTeamConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync",
            abstract: "Sync team configuration with remote source"
        )

        mutating func run() async throws {
            let progressView = ProgressView()
            let service = TeamConfigService.shared

            guard service.getActiveConfig() != nil else {
                progressView.displayWarning("No active team configuration to sync")
                progressView.display(message: "Use 'osxcleaner team load <path>' first.")
                throw ExitCode.generalError
            }

            progressView.display(message: "Syncing with remote configuration...")

            do {
                try await service.syncWithRemote()
                progressView.displaySuccess("Team configuration synced successfully")

                let status = service.getStatus()
                progressView.display(message: "Last sync: \(status.formattedLastSync)")
            } catch let error as TeamConfigError {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Remove Command

extension TeamCommand {
    struct RemoveTeamConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove active team configuration"
        )

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let service = TeamConfigService.shared

            guard service.getActiveConfig() != nil else {
                progressView.displayWarning("No active team configuration to remove")
                return
            }

            if !force {
                progressView.display(message: "Are you sure you want to remove the team configuration?")
                progressView.display(message: "This will disable team policies and exclusions.")
                progressView.display(message: "Use --force to skip this prompt.")
                return
            }

            do {
                try service.removeActiveConfig()
                progressView.displaySuccess("Team configuration removed")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Sample Command

extension TeamCommand {
    struct SampleTeamConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sample",
            abstract: "Generate a sample team configuration file"
        )

        @Option(name: .shortAndLong, help: "Output file path (default: stdout)")
        var output: String?

        mutating func run() async throws {
            let progressView = ProgressView()
            let service = TeamConfigService.shared

            do {
                let yamlContent = try service.generateSampleYAML()

                if let outputPath = output {
                    let expandedPath = (outputPath as NSString).expandingTildeInPath
                    let url = URL(fileURLWithPath: expandedPath)
                    try yamlContent.write(to: url, atomically: true, encoding: .utf8)
                    progressView.displaySuccess("Sample configuration written to: \(expandedPath)")
                } else {
                    progressView.display(message: "# OSX Cleaner Team Configuration Sample")
                    progressView.display(message: "# Save this to a file and customize for your team")
                    progressView.display(message: "")
                    progressView.display(message: yamlContent)
                }
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

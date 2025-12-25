// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import OSXCleanerKit

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage osxcleaner configuration",
        subcommands: [
            ShowConfig.self,
            SetConfig.self,
            ResetConfig.self
        ],
        defaultSubcommand: ShowConfig.self
    )
}

extension ConfigCommand {
    struct ShowConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show current configuration"
        )

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()
            let config = try configService.load()

            progressView.display(message: "=== OSX Cleaner Configuration ===")
            progressView.display(message: "")
            progressView.display(message: "Default safety level: \(config.defaultSafetyLevel)")
            progressView.display(message: "Auto-backup enabled: \(config.autoBackup)")
            progressView.display(message: "Log level: \(config.logLevel)")
            progressView.display(message: "")
            progressView.display(message: "Excluded paths:")
            for path in config.excludedPaths {
                progressView.display(message: "  - \(path)")
            }
        }
    }

    struct SetConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set a configuration value"
        )

        @Argument(help: "Configuration key")
        var key: String

        @Argument(help: "Configuration value")
        var value: String

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()

            try configService.set(key: key, value: value)
            progressView.display(message: "Configuration updated: \(key) = \(value)")
        }
    }

    struct ResetConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reset",
            abstract: "Reset configuration to defaults"
        )

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()

            if !force {
                progressView.display(message: "Are you sure you want to reset all configuration?")
                progressView.display(message: "This action cannot be undone.")
                progressView.display(message: "Use --force to skip this prompt.")
                return
            }

            let configService = ConfigurationService()
            try configService.reset()
            progressView.display(message: "Configuration reset to defaults")
        }
    }
}

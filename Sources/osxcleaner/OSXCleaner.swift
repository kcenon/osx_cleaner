// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import OSXCleanerKit

@main
struct OSXCleaner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "osxcleaner",
        abstract: "A safe and efficient macOS disk cleanup utility",
        version: "0.1.0",
        subcommands: [
            CleanCommand.self,
            AnalyzeCommand.self,
            ConfigCommand.self,
            LogsCommand.self,
            ScheduleCommand.self,
            SnapshotCommand.self,
            MonitorCommand.self,
            MetricsCommand.self,
            AuditCommand.self,
            PolicyCommand.self,
            InteractiveCommand.self,
            TeamCommand.self,
            ServerCommand.self,
            FleetCommand.self,
            MDMCommand.self
        ],
        defaultSubcommand: AnalyzeCommand.self
    )
}

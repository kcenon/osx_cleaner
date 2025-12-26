// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct ScheduleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schedule",
        abstract: "Manage automated cleanup schedules",
        discussion: """
            Create, list, and remove automated cleanup schedules using macOS launchd.
            Schedules are installed as LaunchAgents and run in the background.

            Examples:
              osxcleaner schedule list
              osxcleaner schedule add --frequency daily --level light
              osxcleaner schedule add --frequency weekly --level normal --hour 3
              osxcleaner schedule remove daily
            """,
        subcommands: [
            ListSchedules.self,
            AddSchedule.self,
            RemoveSchedule.self,
            EnableSchedule.self,
            DisableSchedule.self
        ],
        defaultSubcommand: ListSchedules.self
    )
}

// MARK: - List Schedules

extension ScheduleCommand {
    struct ListSchedules: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all configured schedules"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let scheduler = SchedulerService()
            let schedules = scheduler.listSchedules()

            switch format {
            case .text:
                displayTextSchedules(schedules)
            case .json:
                displayJSONSchedules(schedules)
            }
        }

        private func displayTextSchedules(_ schedules: [ScheduleInfo]) {
            let progressView = ProgressView()

            progressView.display(message: "=== Configured Schedules ===")
            progressView.display(message: "")

            if schedules.isEmpty {
                progressView.display(message: "No schedules configured.")
                progressView.display(message: "")
                progressView.display(message: "Use 'osxcleaner schedule add' to create a schedule.")
                return
            }

            for schedule in schedules {
                let status = schedule.enabled ? "enabled" : "disabled"
                progressView.display(
                    message: "[\(schedule.frequency)] Level: \(schedule.level) - \(status)"
                )
                progressView.display(message: "  Time: \(schedule.timeDescription)")
                progressView.display(message: "  Path: \(schedule.plistPath)")
                progressView.display(message: "")
            }
        }

        private func displayJSONSchedules(_ schedules: [ScheduleInfo]) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let jsonData = try? encoder.encode(schedules),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// MARK: - Add Schedule

extension ScheduleCommand {
    struct AddSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add a new cleanup schedule"
        )

        @Option(name: .shortAndLong, help: "Schedule frequency (daily, weekly, monthly)")
        var frequency: ScheduleFrequency = .daily

        @Option(name: .shortAndLong, help: "Cleanup level (light, normal, deep)")
        var level: CleanupLevel = .light

        @Option(name: .long, help: "Hour to run (0-23, default: 3)")
        var hour: Int = 3

        @Option(name: .long, help: "Minute to run (0-59, default: 0)")
        var minute: Int = 0

        @Option(name: .long, help: "Day of week for weekly schedules (0=Sunday, 1=Monday, etc.)")
        var weekday: Int?

        @Option(name: .long, help: "Day of month for monthly schedules (1-31)")
        var day: Int?

        @Flag(name: .long, help: "Enable schedule immediately after creation")
        var enable: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = SchedulerService()

            let config = ScheduleConfig(
                frequency: frequency,
                level: level,
                hour: hour,
                minute: minute,
                weekday: frequency == .weekly ? (weekday ?? 0) : nil,
                day: frequency == .monthly ? (day ?? 1) : nil
            )

            do {
                try scheduler.validateConfig(config)
            } catch {
                progressView.displayError(error)
                throw ExitCode.configurationError
            }

            progressView.display(message: "Creating \(frequency.rawValue) schedule...")

            do {
                try scheduler.createSchedule(config)
                progressView.displaySuccess("Schedule created: \(config.plistName)")

                if enable {
                    try scheduler.enableSchedule(frequency)
                    progressView.displaySuccess("Schedule enabled")
                } else {
                    progressView.display(message: "")
                    progressView.display(message: "Run 'osxcleaner schedule enable \(frequency.rawValue)' to activate")
                }
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Remove Schedule

extension ScheduleCommand {
    struct RemoveSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to remove (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = SchedulerService()

            if !force {
                progressView.display(message: "Are you sure you want to remove the \(frequency.rawValue) schedule?")
                progressView.display(message: "Use --force to skip this prompt.")
                return
            }

            do {
                try scheduler.removeSchedule(frequency)
                progressView.displaySuccess("Schedule removed: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Enable Schedule

extension ScheduleCommand {
    struct EnableSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to enable (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = SchedulerService()

            do {
                try scheduler.enableSchedule(frequency)
                progressView.displaySuccess("Schedule enabled: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Disable Schedule

extension ScheduleCommand {
    struct DisableSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to disable (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = SchedulerService()

            do {
                try scheduler.disableSchedule(frequency)
                progressView.displaySuccess("Schedule disabled: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - ArgumentParser Extensions

extension ScheduleFrequency: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }

    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

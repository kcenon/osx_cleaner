// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct MonitorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Monitor disk usage and send alerts",
        discussion: """
            Enable background disk monitoring to receive notifications when disk space
            is running low. Supports automatic cleanup at configurable thresholds.

            Examples:
              osxcleaner monitor status
              osxcleaner monitor enable --interval 3600
              osxcleaner monitor enable --auto-cleanup --level light
              osxcleaner monitor check
              osxcleaner monitor disable
            """,
        subcommands: [
            MonitorStatus.self,
            MonitorEnable.self,
            MonitorDisable.self,
            MonitorCheck.self
        ],
        defaultSubcommand: MonitorStatus.self
    )
}

// MARK: - Status

extension MonitorCommand {
    struct MonitorStatus: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show current monitoring status"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let progressView = ProgressView()
            let monitoringService = DiskMonitoringService.shared

            // Get current disk status
            let diskInfo: DiskSpaceInfo
            do {
                diskInfo = try monitoringService.getDiskSpace()
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }

            // Get monitoring status
            let status = monitoringService.getStatus()

            switch format {
            case .text:
                displayTextStatus(diskInfo: diskInfo, status: status, progressView: progressView)
            case .json:
                displayJSONStatus(diskInfo: diskInfo, status: status)
            }
        }

        private func displayTextStatus(
            diskInfo: DiskSpaceInfo,
            status: MonitoringStatus,
            progressView: ProgressView
        ) {
            progressView.display(message: "=== Disk Usage ===")
            progressView.display(message: "")
            progressView.display(message: "Volume: \(diskInfo.volumePath)")
            progressView.display(message: "Total:  \(diskInfo.formattedTotal)")
            progressView.display(message: "Used:   \(diskInfo.formattedUsed) (\(String(format: "%.1f", diskInfo.usagePercent))%)")
            progressView.display(message: "Free:   \(diskInfo.formattedAvailable)")
            progressView.display(message: "")

            // Usage bar
            let barWidth = 40
            let filledCount = Int(diskInfo.usagePercent / 100.0 * Double(barWidth))
            let emptyCount = barWidth - filledCount
            let bar = String(repeating: "█", count: filledCount) + String(repeating: "░", count: emptyCount)

            let color: String
            if diskInfo.usagePercent >= 95 {
                color = "\u{001B}[31m" // Red
            } else if diskInfo.usagePercent >= 85 {
                color = "\u{001B}[33m" // Yellow
            } else {
                color = "\u{001B}[32m" // Green
            }
            let reset = "\u{001B}[0m"

            progressView.display(message: "[\(color)\(bar)\(reset)]")
            progressView.display(message: "")

            // Threshold warnings
            if diskInfo.usagePercent >= Double(DiskThreshold.emergency.rawValue) {
                progressView.display(message: "⚠️  EMERGENCY: \(DiskThreshold.emergency.message)")
            } else if diskInfo.usagePercent >= Double(DiskThreshold.critical.rawValue) {
                progressView.display(message: "⚠️  CRITICAL: \(DiskThreshold.critical.message)")
            } else if diskInfo.usagePercent >= Double(DiskThreshold.warning.rawValue) {
                progressView.display(message: "⚠️  WARNING: \(DiskThreshold.warning.message)")
            }

            progressView.display(message: "")
            progressView.display(message: "=== Monitoring Status ===")
            progressView.display(message: "")
            progressView.display(message: "Enabled: \(status.isEnabled ? "Yes" : "No")")

            if let config = status.config {
                progressView.display(message: "Interval: \(config.checkIntervalSeconds)s")
                progressView.display(message: "Auto-cleanup: \(config.autoCleanupEnabled ? "Yes (\(config.autoCleanupLevel))" : "No")")
                progressView.display(message: "Notifications: \(config.notificationsEnabled ? "Yes" : "No")")
            }

            if let plistPath = status.plistPath {
                progressView.display(message: "Agent: \(plistPath)")
            }

            progressView.display(message: "")
            if !status.isEnabled {
                progressView.display(message: "Use 'osxcleaner monitor enable' to start monitoring.")
            }
        }

        private func displayJSONStatus(diskInfo: DiskSpaceInfo, status: MonitoringStatus) {
            struct JSONOutput: Codable {
                let disk: DiskInfo
                let monitoring: MonitoringStatus

                struct DiskInfo: Codable {
                    let volumePath: String
                    let totalBytes: UInt64
                    let usedBytes: UInt64
                    let availableBytes: UInt64
                    let usagePercent: Double
                }
            }

            let output = JSONOutput(
                disk: JSONOutput.DiskInfo(
                    volumePath: diskInfo.volumePath,
                    totalBytes: diskInfo.totalSpace,
                    usedBytes: diskInfo.usedSpace,
                    availableBytes: diskInfo.availableSpace,
                    usagePercent: diskInfo.usagePercent
                ),
                monitoring: status
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let jsonData = try? encoder.encode(output),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// MARK: - Enable

extension MonitorCommand {
    struct MonitorEnable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable background disk monitoring"
        )

        @Option(name: .shortAndLong, help: "Check interval in seconds (default: 3600)")
        var interval: Int = 3600

        @Flag(name: .long, help: "Enable automatic cleanup at emergency threshold")
        var autoCleanup: Bool = false

        @Option(name: .shortAndLong, help: "Cleanup level for auto-cleanup (light, normal)")
        var level: CleanupLevel = .light

        @Option(name: .long, help: "Warning threshold percentage (default: 85)")
        var warning: Int?

        @Option(name: .long, help: "Critical threshold percentage (default: 90)")
        var critical: Int?

        @Option(name: .long, help: "Emergency threshold percentage (default: 95)")
        var emergency: Int?

        @Flag(name: .long, help: "Disable notifications")
        var noNotifications: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let monitoringService = DiskMonitoringService.shared
            let notificationService = NotificationService.shared

            // Request notification permission if notifications enabled
            if !noNotifications {
                progressView.display(message: "Requesting notification permission...")
                let granted = await notificationService.requestPermission()
                if !granted {
                    progressView.display(message: "Warning: Notification permission denied.")
                    progressView.display(message: "Disk warnings will be logged but not displayed.")
                }
                notificationService.registerNotificationCategories()
            }

            // Validate thresholds
            if let w = warning, !(50...99).contains(w) {
                progressView.displayError(MonitoringError.configurationError("Warning threshold must be 50-99"))
                throw ExitCode.configurationError
            }
            if let c = critical, !(50...99).contains(c) {
                progressView.displayError(MonitoringError.configurationError("Critical threshold must be 50-99"))
                throw ExitCode.configurationError
            }
            if let e = emergency, !(50...99).contains(e) {
                progressView.displayError(MonitoringError.configurationError("Emergency threshold must be 50-99"))
                throw ExitCode.configurationError
            }

            let config = MonitoringConfig(
                autoCleanupEnabled: autoCleanup,
                autoCleanupLevel: level.rawValue,
                checkIntervalSeconds: interval,
                notificationsEnabled: !noNotifications,
                warningThreshold: warning,
                criticalThreshold: critical,
                emergencyThreshold: emergency
            )

            do {
                progressView.display(message: "Enabling disk monitoring...")
                try monitoringService.enableMonitoring(config)
                progressView.displaySuccess("Disk monitoring enabled")
                progressView.display(message: "")
                progressView.display(message: "Configuration:")
                progressView.display(message: "  Check interval: \(interval) seconds")
                progressView.display(message: "  Auto-cleanup: \(autoCleanup ? "enabled (\(level.rawValue))" : "disabled")")
                progressView.display(message: "  Notifications: \(!noNotifications ? "enabled" : "disabled")")
                progressView.display(message: "")
                progressView.display(message: "Thresholds:")
                progressView.display(message: "  Warning:   \(config.effectiveWarningThreshold)%")
                progressView.display(message: "  Critical:  \(config.effectiveCriticalThreshold)%")
                progressView.display(message: "  Emergency: \(config.effectiveEmergencyThreshold)%")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Disable

extension MonitorCommand {
    struct MonitorDisable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable background disk monitoring"
        )

        mutating func run() async throws {
            let progressView = ProgressView()
            let monitoringService = DiskMonitoringService.shared

            do {
                try monitoringService.disableMonitoring()
                progressView.displaySuccess("Disk monitoring disabled")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Check

extension MonitorCommand {
    struct MonitorCheck: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "check",
            abstract: "Perform a disk usage check now"
        )

        @Flag(name: .long, help: "Run automatic cleanup if threshold exceeded")
        var autoCleanup: Bool = false

        @Option(name: .shortAndLong, help: "Cleanup level for auto-cleanup")
        var level: CleanupLevel = .light

        @Flag(name: .long, help: "Skip sending notifications")
        var quiet: Bool = false

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let progressView = ProgressView()
            let monitoringService = DiskMonitoringService.shared

            // Try to load saved config, or use defaults
            let config = MonitoringConfig(
                autoCleanupEnabled: autoCleanup,
                autoCleanupLevel: level.rawValue,
                checkIntervalSeconds: 0,  // Not relevant for manual check
                notificationsEnabled: !quiet
            )

            do {
                let (diskInfo, threshold) = try await monitoringService.checkDiskUsage(config: config)

                switch format {
                case .text:
                    displayTextCheck(diskInfo: diskInfo, threshold: threshold, progressView: progressView)
                case .json:
                    displayJSONCheck(diskInfo: diskInfo, threshold: threshold)
                }

                // Trigger auto-cleanup if enabled and threshold exceeded
                if autoCleanup, let threshold = threshold, threshold >= .emergency {
                    progressView.display(message: "")
                    progressView.display(message: "Auto-cleanup triggered at emergency threshold...")

                    // Log disk monitor trigger
                    let loggingService = AutomatedCleanupLoggingService.shared
                    loggingService.logDiskMonitorTrigger(
                        usagePercent: diskInfo.usagePercent,
                        threshold: "\(threshold)"
                    )

                    // Execute actual cleanup
                    let cleanerService = CleanerService()
                    let config = CleanerConfiguration(
                        cleanupLevel: level,
                        dryRun: false,
                        includeSystemCaches: true,
                        includeDeveloperCaches: true,
                        includeBrowserCaches: true,
                        specificPaths: []
                    )

                    do {
                        let result = try await cleanerService.clean(
                            with: config,
                            triggerType: .diskMonitor
                        )
                        progressView.displaySuccess(
                            "Auto-cleanup completed: freed \(result.formattedFreedSpace)"
                        )
                    } catch {
                        progressView.displayError(error)
                        AppLogger.shared.error("Auto-cleanup failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }

        private func displayTextCheck(
            diskInfo: DiskSpaceInfo,
            threshold: DiskThreshold?,
            progressView: ProgressView
        ) {
            progressView.display(message: "Disk Usage: \(String(format: "%.1f", diskInfo.usagePercent))%")
            progressView.display(message: "Available:  \(diskInfo.formattedAvailable)")

            if let threshold = threshold {
                progressView.display(message: "")
                progressView.display(message: "⚠️  Threshold exceeded: \(threshold.message)")
                progressView.display(message: threshold.recommendation)
            } else {
                progressView.displaySuccess("Disk usage is within normal limits")
            }
        }

        private func displayJSONCheck(diskInfo: DiskSpaceInfo, threshold: DiskThreshold?) {
            struct JSONOutput: Codable {
                let usagePercent: Double
                let availableBytes: UInt64
                let thresholdExceeded: Bool
                let thresholdLevel: String?
            }

            let output = JSONOutput(
                usagePercent: diskInfo.usagePercent,
                availableBytes: diskInfo.availableSpace,
                thresholdExceeded: threshold != nil,
                thresholdLevel: threshold.map { "\($0)" }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let jsonData = try? encoder.encode(output),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct MetricsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metrics",
        abstract: "Prometheus metrics endpoint for remote monitoring",
        discussion: """
            Start a Prometheus metrics server to expose disk usage and cleanup
            statistics for remote monitoring with tools like Prometheus and Grafana.

            Examples:
              osxcleaner metrics start                    # Start server on port 9090
              osxcleaner metrics start --port 8080        # Use custom port
              osxcleaner metrics stop                     # Stop the server
              osxcleaner metrics status                   # Show server status
              osxcleaner metrics show                     # Display current metrics
            """,
        subcommands: [
            MetricsStart.self,
            MetricsStop.self,
            MetricsStatus.self,
            MetricsShow.self,
            MetricsReset.self
        ],
        defaultSubcommand: MetricsStatus.self
    )
}

// MARK: - Start

extension MetricsCommand {
    struct MetricsStart: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start the Prometheus metrics server"
        )

        @Option(name: .shortAndLong, help: "Port to listen on (default: 9090)")
        var port: UInt16 = 9090

        @Option(name: .long, help: "Host to bind to (default: 127.0.0.1)")
        var host: String = "127.0.0.1"

        @Flag(name: .long, help: "Run in foreground (don't daemonize)")
        var foreground: Bool = false

        @Flag(name: .long, help: "Include labels in metrics")
        var labels: Bool = true

        mutating func run() async throws {
            let progressView = ProgressView()
            let metricsService = PrometheusMetricsService.shared

            if metricsService.running {
                progressView.displayWarning("Metrics server is already running")
                return
            }

            let config = MetricsConfig(
                port: port,
                host: host,
                includeLabels: labels
            )

            do {
                try metricsService.start(config: config)
                progressView.displaySuccess("Prometheus metrics server started")
                progressView.display(message: "")
                progressView.display(message: "Configuration:")
                progressView.display(message: "  Endpoint: http://\(host):\(port)/metrics")
                progressView.display(message: "  Health:   http://\(host):\(port)/health")
                progressView.display(message: "")

                if foreground {
                    progressView.display(message: "Running in foreground. Press Ctrl+C to stop.")
                    progressView.display(message: "")

                    // Set up signal handlers
                    signal(SIGINT) { _ in
                        PrometheusMetricsService.shared.stop()
                        Darwin.exit(0)
                    }

                    signal(SIGTERM) { _ in
                        PrometheusMetricsService.shared.stop()
                        Darwin.exit(0)
                    }

                    // Keep the process running using async sleep
                    while metricsService.running {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                } else {
                    progressView.display(message: "Server is running in background.")
                    progressView.display(message: "Use 'osxcleaner metrics stop' to stop the server.")
                }
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Stop

extension MetricsCommand {
    struct MetricsStop: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop the Prometheus metrics server"
        )

        mutating func run() async throws {
            let progressView = ProgressView()
            let metricsService = PrometheusMetricsService.shared

            if !metricsService.running {
                progressView.display(message: "Metrics server is not running")
                return
            }

            metricsService.stop()
            progressView.displaySuccess("Prometheus metrics server stopped")
        }
    }
}

// MARK: - Status

extension MetricsCommand {
    struct MetricsStatus: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show metrics server status"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let progressView = ProgressView()
            let metricsService = PrometheusMetricsService.shared

            let stats = metricsService.cleanupStats

            switch format {
            case .text:
                displayTextStatus(
                    running: metricsService.running,
                    stats: stats,
                    progressView: progressView
                )
            case .json:
                displayJSONStatus(running: metricsService.running, stats: stats)
            }
        }

        private func displayTextStatus(
            running: Bool,
            stats: CleanupStatistics,
            progressView: ProgressView
        ) {
            progressView.display(message: "=== Prometheus Metrics Server ===")
            progressView.display(message: "")
            progressView.display(message: "Status: \(running ? "Running" : "Stopped")")
            progressView.display(message: "")
            progressView.display(message: "=== Cleanup Statistics ===")
            progressView.display(message: "")
            progressView.display(message: "Total operations:  \(stats.totalOperations)")
            progressView.display(message: "Total bytes freed: \(formatBytes(stats.totalBytesFreed))")
            progressView.display(message: "Files removed:     \(stats.totalFilesRemoved)")
            progressView.display(message: "Directories removed: \(stats.totalDirectoriesRemoved)")
            progressView.display(message: "Total errors:      \(stats.totalErrors)")

            if let lastCleanup = stats.lastCleanupTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                progressView.display(message: "Last cleanup:      \(formatter.string(from: lastCleanup))")
            } else {
                progressView.display(message: "Last cleanup:      Never")
            }

            progressView.display(message: "")
            if !running {
                progressView.display(message: "Use 'osxcleaner metrics start' to start the server.")
            }
        }

        private func displayJSONStatus(running: Bool, stats: CleanupStatistics) {
            struct JSONOutput: Codable {
                let serverRunning: Bool
                let statistics: CleanupStatistics
            }

            let output = JSONOutput(
                serverRunning: running,
                statistics: stats
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            if let jsonData = try? encoder.encode(output),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }

        private func formatBytes(_ bytes: UInt64) -> String {
            ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
    }
}

// MARK: - Show

extension MetricsCommand {
    struct MetricsShow: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Display current metrics in Prometheus format"
        )

        @Flag(name: .long, help: "Include labels in metrics output")
        var labels: Bool = true

        mutating func run() async throws {
            let progressView = ProgressView()
            let metricsService = PrometheusMetricsService.shared

            do {
                let collection = try metricsService.collectMetrics()
                print(collection.format())
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Reset

extension MetricsCommand {
    struct MetricsReset: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reset",
            abstract: "Reset cleanup statistics"
        )

        @Flag(name: .long, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let metricsService = PrometheusMetricsService.shared

            if !force {
                progressView.display(message: "This will reset all cleanup statistics.")
                progressView.display(message: "Are you sure? (use --force to skip this prompt)")
                return
            }

            metricsService.resetStatistics()
            progressView.displaySuccess("Cleanup statistics have been reset")
        }
    }
}

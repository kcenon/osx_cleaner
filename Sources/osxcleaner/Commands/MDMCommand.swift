// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct MDMCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mdm",
        abstract: "Manage MDM (Mobile Device Management) integration",
        discussion: """
            Connect OSX Cleaner to enterprise MDM platforms for centralized
            policy management and reporting.

            Supported MDM platforms:
              - jamf     Jamf Pro
              - mosyle   Mosyle
              - kandji   Kandji

            Examples:
              osxcleaner mdm status                           # Show MDM status
              osxcleaner mdm connect jamf https://company.jamfcloud.com
              osxcleaner mdm sync                             # Sync policies
              osxcleaner mdm compliance                       # Show compliance
            """,
        subcommands: [
            Status.self,
            Connect.self,
            Disconnect.self,
            Sync.self,
            Policies.self,
            Compliance.self,
            Commands.self
        ],
        defaultSubcommand: Status.self
    )
}

// MARK: - Status Subcommand

extension MDMCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show current MDM connection status"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared
            let status = await mdmService.getStatus()

            if json {
                try OutputFormatter.printJSON(status)
            } else {
                MDMOutputHelpers.printStatus(status, progressView: progressView)
            }
        }
    }
}

// MARK: - Connect Subcommand

extension MDMCommand {
    struct Connect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "connect",
            abstract: "Connect to an MDM platform"
        )

        @Argument(help: "MDM provider (jamf, mosyle, kandji)")
        var provider: String

        @Argument(help: "Server URL (e.g., https://company.jamfcloud.com)")
        var serverURL: String

        @Option(name: .shortAndLong, help: "API token for authentication")
        var token: String?

        @Option(name: .long, help: "OAuth2 client ID (Jamf Pro)")
        var clientId: String?

        @Option(name: .long, help: "OAuth2 client secret (Jamf Pro)")
        var clientSecret: String?

        @Option(name: .shortAndLong, help: "Username for basic auth")
        var username: String?

        @Option(name: .shortAndLong, help: "Password for basic auth")
        var password: String?

        mutating func run() async throws {
            let progressView = ProgressView()

            // Parse provider
            guard let mdmProvider = MDMProvider(rawValue: provider.lowercased()) else {
                progressView.display(message: "✗ Invalid provider: \(provider)")
                progressView.display(message: "  Supported: jamf, mosyle, kandji")
                return
            }

            // Parse URL
            guard let url = URL(string: serverURL) else {
                progressView.display(message: "✗ Invalid server URL: \(serverURL)")
                return
            }

            // Create credentials
            let credentials: MDMCredentials
            if let token = token {
                credentials = MDMCredentials(apiToken: token)
            } else if let clientId = clientId, let clientSecret = clientSecret {
                credentials = MDMCredentials(clientId: clientId, clientSecret: clientSecret)
            } else if let username = username, let password = password {
                credentials = MDMCredentials(username: username, password: password)
            } else {
                progressView.display(message: "✗ No credentials provided")
                progressView.display(message: "  Use --token, --client-id/--client-secret, or --username/--password")
                return
            }

            progressView.display(message: "")
            progressView.display(message: "Connecting to \(mdmProvider.displayName)...")
            progressView.display(message: "  Server: \(url.absoluteString)")

            do {
                let mdmService = MDMService.shared
                try await mdmService.connect(
                    provider: mdmProvider,
                    serverURL: url,
                    credentials: credentials
                )

                progressView.display(message: "")
                progressView.displaySuccess("Connected to \(mdmProvider.displayName)")

                // Sync policies
                progressView.display(message: "")
                progressView.display(message: "Syncing policies...")

                let policies = try await mdmService.syncPolicies()
                progressView.displaySuccess("Synced \(policies.count) policies")

            } catch {
                progressView.display(message: "")
                progressView.display(message: "✗ Connection failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Disconnect Subcommand

extension MDMCommand {
    struct Disconnect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disconnect",
            abstract: "Disconnect from the current MDM"
        )

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared

            guard await mdmService.isConnected else {
                progressView.display(message: "Not connected to any MDM")
                return
            }

            if !force {
                progressView.display(message: "This will disconnect from the MDM and clear cached policies.")
                progressView.display(message: "Use --force to confirm.")
                return
            }

            do {
                try await mdmService.disconnect()
                progressView.display(message: "")
                progressView.displaySuccess("Disconnected from MDM")
            } catch {
                progressView.display(message: "✗ Disconnect failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Sync Subcommand

extension MDMCommand {
    struct Sync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync",
            abstract: "Sync policies from MDM"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared

            guard await mdmService.isConnected else {
                progressView.display(message: "✗ Not connected to any MDM")
                progressView.display(message: "  Use 'osxcleaner mdm connect' first")
                return
            }

            do {
                let policies = try await mdmService.syncPolicies()

                if json {
                    try OutputFormatter.printJSON(policies)
                } else {
                    progressView.display(message: "")
                    progressView.displaySuccess("Synced \(policies.count) policies")

                    if !policies.isEmpty {
                        progressView.display(message: "")
                        progressView.display(message: "Policies:")
                        for policy in policies {
                            let statusIcon = policy.enabled ? "✓" : "○"
                            progressView.display(message: "  \(statusIcon) \(policy.name) (v\(policy.version))")
                        }
                    }
                }
            } catch {
                progressView.display(message: "✗ Sync failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Policies Subcommand

extension MDMCommand {
    struct Policies: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "policies",
            abstract: "List MDM policies"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        @Flag(name: .long, help: "Show only enabled policies")
        var enabledOnly: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared

            guard await mdmService.isConnected else {
                progressView.display(message: "✗ Not connected to any MDM")
                return
            }

            var policies = await mdmService.getCachedPolicies()

            if policies.isEmpty {
                // Try to sync first
                do {
                    policies = try await mdmService.syncPolicies()
                } catch {
                    progressView.display(message: "✗ Failed to fetch policies: \(error.localizedDescription)")
                    return
                }
            }

            if enabledOnly {
                policies = policies.filter { $0.enabled }
            }

            if json {
                try OutputFormatter.printJSON(policies)
            } else {
                MDMOutputHelpers.printPolicies(policies, progressView: progressView)
            }
        }
    }
}

// MARK: - Compliance Subcommand

extension MDMCommand {
    struct Compliance: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compliance",
            abstract: "Show or report compliance status"
        )

        @Flag(name: .shortAndLong, help: "Report compliance to MDM")
        var report: Bool = false

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared

            guard await mdmService.isConnected else {
                progressView.display(message: "✗ Not connected to any MDM")
                return
            }

            // Check compliance for all policies
            let policies = await mdmService.getCachedPolicies()

            if policies.isEmpty {
                progressView.display(message: "No policies to check compliance for")
                return
            }

            // Build compliance report
            var policyReports: [MDMComplianceReport.PolicyComplianceInfo] = []

            for mdmPolicy in policies {
                // Simple compliance check based on policy state
                let status: MDMComplianceReport.ComplianceStatus = mdmPolicy.enabled ? .compliant : .nonCompliant
                var issues: [String] = []

                if !mdmPolicy.enabled {
                    issues.append("Policy is disabled")
                }

                policyReports.append(MDMComplianceReport.PolicyComplianceInfo(
                    policyId: mdmPolicy.id,
                    policyName: mdmPolicy.name,
                    status: status,
                    issues: issues
                ))
            }

            let overallStatus: MDMComplianceReport.ComplianceStatus
            if policyReports.allSatisfy({ $0.status == .compliant }) {
                overallStatus = .compliant
            } else if policyReports.contains(where: { $0.status == .error }) {
                overallStatus = .error
            } else {
                overallStatus = .nonCompliant
            }

            let agentId = try await getAgentId()
            let complianceReport = MDMComplianceReport(
                agentId: agentId,
                overallStatus: overallStatus,
                policyReports: policyReports
            )

            if report {
                do {
                    try await mdmService.reportCompliance(complianceReport)
                    progressView.displaySuccess("Compliance reported to MDM")
                } catch {
                    progressView.display(message: "✗ Failed to report compliance: \(error.localizedDescription)")
                    return
                }
            }

            if json {
                try OutputFormatter.printJSON(complianceReport)
            } else {
                MDMOutputHelpers.printComplianceReport(complianceReport, progressView: progressView)
            }
        }

        private func getAgentId() async throws -> String {
            let configService = ConfigurationService()
            let config = try configService.load()

            if let agentId = config.agentId {
                return agentId.uuidString
            }

            return ProcessInfo.processInfo.hostName
        }
    }
}

// MARK: - Commands Subcommand

extension MDMCommand {
    struct Commands: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "commands",
            abstract: "Fetch and execute pending MDM commands"
        )

        @Flag(name: .shortAndLong, help: "Execute pending commands")
        var execute: Bool = false

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let mdmService = MDMService.shared

            guard await mdmService.isConnected else {
                progressView.display(message: "✗ Not connected to any MDM")
                return
            }

            do {
                let commands = try await mdmService.fetchCommands()

                if commands.isEmpty {
                    if !json {
                        progressView.display(message: "No pending commands")
                    } else {
                        print("[]")
                    }
                    return
                }

                if json && !execute {
                    try OutputFormatter.printJSON(commands)
                    return
                }

                if !execute {
                    MDMOutputHelpers.printCommands(commands, progressView: progressView)
                    return
                }

                // Execute commands
                progressView.display(message: "")
                progressView.display(message: "Executing \(commands.count) commands...")
                progressView.display(message: "")

                var results: [MDMCommandResult] = []

                for command in commands.sorted(by: { $0.priority > $1.priority }) {
                    progressView.display(message: "  Executing: \(command.type.rawValue)...")

                    let result = try await mdmService.executeCommand(command)
                    results.append(result)

                    let icon = result.success ? "✓" : "✗"
                    progressView.display(message: "    \(icon) \(result.message ?? (result.success ? "Success" : "Failed"))")

                    // Report result to MDM
                    try await mdmService.reportCommandResult(result)
                }

                MDMOutputHelpers.printCommandResults(results, progressView: progressView)

            } catch {
                progressView.display(message: "✗ Failed: \(error.localizedDescription)")
            }
        }
    }
}

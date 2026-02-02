// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import OSXCleanerKit

/// Helper utilities for MDM command output formatting
enum MDMOutputHelpers {
    /// Print MDM connection status
    static func printStatus(_ status: MDMConnectionStatus, progressView: ProgressView) {
        let formatter = OutputFormatter.standardDateFormatter()

        OutputFormatter.printHeader("MDM CONNECTION STATUS", progressView: progressView)

        if let provider = status.provider {
            progressView.display(message: "  Provider:        \(provider.displayName)")
        } else {
            progressView.display(message: "  Provider:        Not configured")
        }

        if let serverURL = status.serverURL {
            progressView.display(message: "  Server URL:      \(serverURL)")
        } else {
            progressView.display(message: "  Server URL:      -")
        }

        let stateIcon = status.isConnected ? "✓" : "○"
        let stateText = status.isConnected ? "Connected" : "Disconnected"
        progressView.display(message: "  Status:          \(stateIcon) \(stateText)")

        if let lastSync = status.lastSyncAt {
            progressView.display(message: "  Last Sync:       \(formatter.string(from: lastSync))")
        } else {
            progressView.display(message: "  Last Sync:       Never")
        }

        progressView.display(message: "  Policies:        \(status.policiesCount)")
        progressView.display(message: "  Pending Cmds:    \(status.pendingCommandsCount)")

        OutputFormatter.printFooter(progressView: progressView)
    }

    /// Print compliance status report
    static func printComplianceReport(_ report: MDMComplianceReport, progressView: ProgressView) {
        OutputFormatter.printHeader("COMPLIANCE STATUS", progressView: progressView)

        let statusIcon = complianceStatusIcon(report.overallStatus)
        progressView.display(message: "  Overall Status:  \(statusIcon) \(report.overallStatus.rawValue.capitalized)")
        progressView.display(message: "")
        progressView.display(message: "  Policy Compliance:")

        for policy in report.policyReports {
            let icon = complianceStatusIcon(policy.status)
            progressView.display(message: "    \(icon) \(policy.policyName)")
            for issue in policy.issues {
                progressView.display(message: "        - \(issue)")
            }
        }

        OutputFormatter.printFooter(progressView: progressView)
    }

    /// Print MDM policies list
    static func printPolicies(_ policies: [MDMPolicy], progressView: ProgressView) {
        OutputFormatter.printHeader("MDM POLICIES", progressView: progressView)

        if policies.isEmpty {
            progressView.display(message: "  No policies found")
        } else {
            for policy in policies.sorted(by: { $0.priority > $1.priority }) {
                let statusIcon = policy.enabled ? "✓" : "○"
                progressView.display(message: "  \(statusIcon) \(policy.name)")
                progressView.display(message: "      ID: \(policy.id)")
                progressView.display(message: "      Version: \(policy.version)")
                progressView.display(message: "      Priority: \(policy.priority)")
                if !policy.targets.isEmpty {
                    progressView.display(message: "      Targets: \(policy.targets.joined(separator: ", "))")
                }
                if let schedule = policy.schedule {
                    progressView.display(message: "      Schedule: \(schedule)")
                }
                progressView.display(message: "")
            }
        }

        OutputFormatter.printFooter("  Total: \(policies.count) policies", progressView: progressView)
    }

    /// Print MDM commands list
    static func printCommands(_ commands: [OSXCleanerKit.MDMCommand], progressView: ProgressView) {
        progressView.display(message: "")
        progressView.display(message: "Pending Commands (\(commands.count)):")
        progressView.display(message: "")

        for command in commands.sorted(by: { $0.priority > $1.priority }) {
            progressView.display(message: "  [\(command.priority)] \(command.type.rawValue)")
            progressView.display(message: "      ID: \(command.id)")
            if !command.parameters.isEmpty {
                progressView.display(message: "      Params: \(command.parameters)")
            }
            progressView.display(message: "")
        }

        progressView.display(message: "Use --execute to run these commands")
    }

    /// Print command execution results
    static func printCommandResults(_ results: [MDMCommandResult], progressView: ProgressView) {
        progressView.display(message: "")

        let successCount = results.filter { $0.success }.count
        progressView.displaySuccess("Executed \(successCount)/\(results.count) commands successfully")
    }

    // MARK: - Private Helpers

    private static func complianceStatusIcon(_ status: MDMComplianceReport.ComplianceStatus) -> String {
        switch status {
        case .compliant:
            return "✓"
        case .nonCompliant:
            return "✗"
        case .unknown:
            return "?"
        case .error:
            return "!"
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import OSXCleanerKit

/// Helper utilities for Policy command output formatting
enum PolicyOutputHelpers {
    /// Print policies in table format
    static func printPolicyTable(_ policies: [Policy], progressView: ProgressView) {
        progressView.display(message: "")
        progressView.display(message: "╔════════════════════════╤══════════╤════════╤═══════════════════════════════════════╗")
        progressView.display(message: "║         Name           │ Priority │ Rules  │            Description                ║")
        progressView.display(message: "╠════════════════════════╪══════════╪════════╪═══════════════════════════════════════╣")

        for policy in policies {
            let enabledIcon = policy.enabled ? "●" : "○"
            let name = "\(enabledIcon) \(policy.displayName ?? policy.name)".prefix(22).padding(toLength: 22, withPad: " ", startingAt: 0)
            let priority = priorityLabel(policy.priority).padding(toLength: 8, withPad: " ", startingAt: 0)
            let rules = "\(policy.enabledRules.count)/\(policy.rules.count)".padding(toLength: 6, withPad: " ", startingAt: 0)
            let description = (policy.description ?? "").prefix(37).padding(toLength: 37, withPad: " ", startingAt: 0)

            progressView.display(message: "║ \(name) │ \(priority) │ \(rules) │ \(description) ║")
        }

        progressView.display(message: "╚════════════════════════╧══════════╧════════╧═══════════════════════════════════════╝")
        progressView.display(message: "")
        progressView.display(message: "Legend: ● enabled, ○ disabled")
        progressView.display(message: "Showing \(policies.count) policy(ies)")
    }

    /// Print detailed policy information
    static func printPolicyDetails(_ policy: Policy, progressView: ProgressView) {
        let formatter = OutputFormatter.standardDateFormatter()

        OutputFormatter.printHeader("POLICY DETAILS", progressView: progressView)

        progressView.display(message: "  Name:          \(policy.name)")
        progressView.display(message: "  Display Name:  \(policy.displayName ?? "-")")
        progressView.display(message: "  Description:   \(policy.description ?? "-")")
        progressView.display(message: "  Version:       \(policy.version)")
        progressView.display(message: "  Priority:      \(policy.priority)")
        progressView.display(message: "  Enabled:       \(policy.enabled ? "Yes" : "No")")
        progressView.display(message: "  Notifications: \(policy.notifications ? "Yes" : "No")")
        progressView.display(message: "  Created:       \(formatter.string(from: policy.createdAt))")
        progressView.display(message: "  Updated:       \(formatter.string(from: policy.updatedAt))")

        if !policy.tags.isEmpty {
            progressView.display(message: "  Tags:          \(policy.tags.joined(separator: ", "))")
        }

        progressView.display(message: "")
        progressView.display(message: "  Rules (\(policy.rules.count)):")
        for rule in policy.rules {
            printRuleDetails(rule, progressView: progressView)
        }

        if !policy.exclusions.isEmpty {
            progressView.display(message: "")
            progressView.display(message: "  Exclusions:")
            for exclusion in policy.exclusions {
                progressView.display(message: "    - \(exclusion)")
            }
        }

        OutputFormatter.printFooter(progressView: progressView)
    }

    /// Print policy execution results
    static func printResults(_ results: [PolicyExecutionResult], progressView: ProgressView, dryRun: Bool) {
        for result in results {
            progressView.display(message: "")
            progressView.display(message: "Policy: \(result.policyName)")
            progressView.display(message: "  Status: \(result.success ? "✓ Success" : "✗ Failed")")
            progressView.display(message: "  Rules: \(result.successfulRules)/\(result.ruleResults.count) successful")
            progressView.display(message: "  Freed: \(result.formattedBytesFreed)\(dryRun ? " (estimated)" : "")")
            progressView.display(message: "  Items: \(result.totalItemsProcessed)")
            progressView.display(message: "  Duration: \(String(format: "%.2f", result.totalDuration))s")

            let failedRules = result.ruleResults.filter { !$0.success }
            if !failedRules.isEmpty {
                progressView.display(message: "")
                progressView.display(message: "  Failed rules:")
                for rule in failedRules {
                    progressView.display(message: "    - \(rule.ruleId): \(rule.error ?? "Unknown error")")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private static func priorityLabel(_ priority: PolicyPriority) -> String {
        switch priority {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    private static func printRuleDetails(_ rule: PolicyRule, progressView: ProgressView) {
        let enabledIcon = rule.enabled ? "●" : "○"
        progressView.display(message: "    \(enabledIcon) \(rule.id)")
        progressView.display(message: "      Target:   \(rule.target.rawValue)")
        progressView.display(message: "      Action:   \(rule.action.rawValue)")
        progressView.display(message: "      Schedule: \(rule.schedule.rawValue)")
        if let desc = rule.description {
            progressView.display(message: "      Info:     \(desc)")
        }
        if let conditions = rule.conditions {
            printConditions(conditions, progressView: progressView)
        }
    }

    private static func printConditions(_ conditions: PolicyCondition, progressView: ProgressView) {
        var conditionParts: [String] = []
        if let olderThan = conditions.olderThan {
            conditionParts.append("older than \(olderThan)")
        }
        if let minFreeSpace = conditions.minFreeSpace {
            conditionParts.append("when free space < \(minFreeSpace)")
        }
        if !conditionParts.isEmpty {
            progressView.display(message: "      Conditions: \(conditionParts.joined(separator: ", "))")
        }
    }
}

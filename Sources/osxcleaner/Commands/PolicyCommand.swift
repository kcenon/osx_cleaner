// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct PolicyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "policy",
        abstract: "Manage and apply cleanup policies",
        subcommands: [
            ListPolicy.self,
            ShowPolicy.self,
            AddPolicy.self,
            RemovePolicy.self,
            ApplyPolicy.self,
            ValidatePolicy.self,
            CompliancePolicy.self,
            ExportPolicy.self,
            CreatePolicy.self
        ],
        defaultSubcommand: ListPolicy.self
    )
}

// MARK: - List Subcommand

extension PolicyCommand {
    struct ListPolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all installed policies"
        )

        @Option(name: .shortAndLong, help: "Filter by tag")
        var tag: String?

        @Flag(name: .shortAndLong, help: "Show only enabled policies")
        var enabled: Bool = false

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            var policies = try store.list()

            if enabled {
                policies = policies.filter { $0.enabled }
            }

            if let tag = tag {
                policies = policies.filter { $0.tags.contains(tag) }
            }

            if policies.isEmpty {
                progressView.display(message: "No policies found")
                return
            }

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(policies)
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else {
                printPolicyTable(policies, progressView: progressView)
            }
        }

        private func printPolicyTable(_ policies: [Policy], progressView: ProgressView) {
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

        private func priorityLabel(_ priority: PolicyPriority) -> String {
            switch priority {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
}

// MARK: - Show Subcommand

extension PolicyCommand {
    struct ShowPolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show detailed information about a policy"
        )

        @Argument(help: "Policy name to show")
        var name: String

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            let policy = try store.get(name)

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(policy)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                printPolicyDetails(policy, progressView: progressView)
            }
        }

        private func printPolicyDetails(_ policy: Policy, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                     POLICY DETAILS                        ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
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
                let enabledIcon = rule.enabled ? "●" : "○"
                progressView.display(message: "    \(enabledIcon) \(rule.id)")
                progressView.display(message: "      Target:   \(rule.target.rawValue)")
                progressView.display(message: "      Action:   \(rule.action.rawValue)")
                progressView.display(message: "      Schedule: \(rule.schedule.rawValue)")
                if let desc = rule.description {
                    progressView.display(message: "      Info:     \(desc)")
                }
                if let conditions = rule.conditions {
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

            if !policy.exclusions.isEmpty {
                progressView.display(message: "")
                progressView.display(message: "  Exclusions:")
                for exclusion in policy.exclusions {
                    progressView.display(message: "    - \(exclusion)")
                }
            }

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }
    }
}

// MARK: - Add Subcommand

extension PolicyCommand {
    struct AddPolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add a policy from a JSON file"
        )

        @Argument(help: "Path to policy JSON file")
        var path: String

        @Flag(name: .long, help: "Overwrite if policy already exists")
        var overwrite: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            let fileURL = URL(fileURLWithPath: path)

            progressView.display(message: "Importing policy from \(path)...")

            let policy = try store.importPolicy(from: fileURL, overwrite: overwrite)

            progressView.display(message: "")
            progressView.display(message: "✓ Policy '\(policy.name)' imported successfully")
            progressView.display(message: "  Rules: \(policy.rules.count)")
            progressView.display(message: "  Exclusions: \(policy.exclusions.count)")
        }
    }
}

// MARK: - Remove Subcommand

extension PolicyCommand {
    struct RemovePolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove an installed policy"
        )

        @Argument(help: "Policy name to remove")
        var name: String

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            if !force {
                progressView.display(message: "This will remove policy '\(name)'.")
                progressView.display(message: "Use --force to confirm.")
                return
            }

            try store.delete(name)

            progressView.display(message: "✓ Policy '\(name)' removed successfully")
        }
    }
}

// MARK: - Apply Subcommand

extension PolicyCommand {
    struct ApplyPolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "apply",
            abstract: "Apply a policy to clean up the system"
        )

        @Argument(help: "Policy name to apply (or 'all' for all enabled policies)")
        var name: String

        @Flag(name: .long, help: "Dry run - show what would be cleaned without making changes")
        var dryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            let engineConfig = PolicyEngineConfig(dryRun: dryRun)
            let engine = PolicyEngine(store: store, config: engineConfig)

            progressView.display(message: dryRun ? "Running in dry-run mode..." : "Applying policy...")
            progressView.display(message: "")

            let results: [PolicyExecutionResult]
            let showProgress = !json

            if name == "all" {
                results = try await engine.executeAll { progress in
                    if showProgress {
                        print("\r  [\(progress.rulesCompleted)/\(progress.totalRules)] \(progress.currentRule)...", terminator: "")
                        fflush(stdout)
                    }
                }
            } else {
                let result = try await engine.execute(policyName: name) { progress in
                    if showProgress {
                        print("\r  [\(progress.rulesCompleted)/\(progress.totalRules)] \(progress.currentRule)...", terminator: "")
                        fflush(stdout)
                    }
                }
                results = [result]
            }

            print("")  // New line after progress

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(results)
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else {
                printResults(results, progressView: progressView, dryRun: dryRun)
            }
        }

        private func printResults(_ results: [PolicyExecutionResult], progressView: ProgressView, dryRun: Bool) {
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
    }
}

// MARK: - Validate Subcommand

extension PolicyCommand {
    struct ValidatePolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "Validate a policy file"
        )

        @Argument(help: "Path to policy JSON file")
        var path: String

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let validator = PolicyValidator()

            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let policy = try decoder.decode(Policy.self, from: data)
                let result = validator.validate(policy)

                if json {
                    let output: [String: Any] = [
                        "valid": result.isValid,
                        "errors": result.errors.map { $0.errorDescription ?? "" },
                        "warnings": result.warnings
                    ]
                    let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    printValidationResult(result, policy: policy, progressView: progressView)
                }
            } catch {
                progressView.display(message: "✗ Invalid JSON: \(error.localizedDescription)")
            }
        }

        private func printValidationResult(_ result: PolicyValidationResult, policy: Policy, progressView: ProgressView) {
            progressView.display(message: "")

            if result.isValid {
                progressView.display(message: "✓ Policy '\(policy.name)' is valid")
            } else {
                progressView.display(message: "✗ Policy '\(policy.name)' has validation errors:")
                for error in result.errors {
                    progressView.display(message: "  - \(error.errorDescription ?? "Unknown error")")
                }
            }

            if !result.warnings.isEmpty {
                progressView.display(message: "")
                progressView.display(message: "Warnings:")
                for warning in result.warnings {
                    progressView.display(message: "  ⚠ \(warning)")
                }
            }

            progressView.display(message: "")
        }
    }
}

// MARK: - Compliance Subcommand

extension PolicyCommand {
    struct CompliancePolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compliance",
            abstract: "Check compliance status for policies"
        )

        @Argument(help: "Policy name to check (or 'all' for all enabled policies)")
        var name: String = "all"

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()
            let engine = PolicyEngine(store: store)

            var reports: [PolicyComplianceReport] = []

            if name == "all" {
                let policies = try store.enabledPolicies()
                for policy in policies {
                    let report = try await engine.checkCompliance(policy: policy)
                    reports.append(report)
                }
            } else {
                let report = try await engine.checkCompliance(policyName: name)
                reports.append(report)
            }

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(reports)
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else {
                printComplianceReports(reports, progressView: progressView)
            }
        }

        private func printComplianceReports(_ reports: [PolicyComplianceReport], progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            for report in reports {
                progressView.display(message: "")
                progressView.display(message: "═══════════════════════════════════════════════════════════")
                progressView.display(message: "  Policy: \(report.policyName)")
                progressView.display(message: "  Status: \(statusIcon(report.status)) \(report.status.rawValue.capitalized)")
                progressView.display(message: "  Checked: \(formatter.string(from: report.checkedAt))")

                if !report.issues.isEmpty {
                    progressView.display(message: "")
                    progressView.display(message: "  Issues:")
                    for issue in report.issues {
                        progressView.display(message: "    ✗ \(issue)")
                    }
                }

                if !report.recommendations.isEmpty {
                    progressView.display(message: "")
                    progressView.display(message: "  Recommendations:")
                    for rec in report.recommendations {
                        progressView.display(message: "    → \(rec)")
                    }
                }

                progressView.display(message: "═══════════════════════════════════════════════════════════")
            }

            // Summary
            let compliant = reports.filter { $0.status == .compliant }.count
            let nonCompliant = reports.filter { $0.status == .nonCompliant }.count

            progressView.display(message: "")
            progressView.display(message: "Summary: \(compliant) compliant, \(nonCompliant) non-compliant")
        }

        private func statusIcon(_ status: ComplianceStatus) -> String {
            switch status {
            case .compliant: return "✓"
            case .nonCompliant: return "✗"
            case .pending: return "○"
            case .error: return "⚠"
            }
        }
    }
}

// MARK: - Export Subcommand

extension PolicyCommand {
    struct ExportPolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export a policy to a file"
        )

        @Argument(help: "Policy name to export")
        var name: String

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            let outputPath: URL
            if let output = output {
                outputPath = URL(fileURLWithPath: output)
            } else {
                outputPath = URL(fileURLWithPath: "\(name).json")
            }

            try store.exportPolicy(name, to: outputPath)

            progressView.display(message: "✓ Policy '\(name)' exported to \(outputPath.path)")
        }
    }
}

// MARK: - Create Subcommand

extension PolicyCommand {
    struct CreatePolicy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a new policy from a template"
        )

        @Argument(help: "Name for the new policy")
        var name: String

        @Option(name: .shortAndLong, help: "Template to use (personal, developer, aggressive, enterprise)")
        var template: String = "personal"

        mutating func run() async throws {
            let progressView = ProgressView()
            let store = try PolicyStore()

            // Check if already exists
            if store.exists(name) {
                progressView.display(message: "✗ Policy '\(name)' already exists")
                return
            }

            // Create from template
            var policy: Policy
            switch template.lowercased() {
            case "personal":
                policy = .personalDefault
            case "developer":
                policy = .developerStandard
            case "aggressive":
                policy = .aggressiveCleanup
            case "enterprise":
                policy = .enterpriseCompliance
            default:
                progressView.display(message: "Unknown template: \(template)")
                progressView.display(message: "Available templates: personal, developer, aggressive, enterprise")
                return
            }

            // Update name
            policy = Policy(
                version: policy.version,
                name: name,
                displayName: policy.displayName,
                description: policy.description,
                rules: policy.rules,
                exclusions: policy.exclusions,
                notifications: policy.notifications,
                priority: policy.priority,
                enabled: policy.enabled,
                tags: policy.tags,
                metadata: policy.metadata
            )

            try store.save(policy)

            progressView.display(message: "✓ Policy '\(name)' created from '\(template)' template")
            progressView.display(message: "  Rules: \(policy.rules.count)")
            progressView.display(message: "")
            progressView.display(message: "Edit the policy at: \(store.getPolicyDirectory().appendingPathComponent("\(name).json").path)")
        }
    }
}

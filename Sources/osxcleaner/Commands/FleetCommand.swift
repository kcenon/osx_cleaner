// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct FleetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fleet",
        abstract: "Manage fleet of agents from the management server",
        discussion: """
            Fleet management commands for administrators to monitor and control
            connected agents, deploy policies, and generate compliance reports.

            Note: These commands require server-side access. For local agent
            operations, use 'osxcleaner server' commands instead.

            Examples:
              osxcleaner fleet agents                     # List all agents
              osxcleaner fleet status                     # Show fleet statistics
              osxcleaner fleet deploy my-policy --all    # Deploy policy to all agents
              osxcleaner fleet compliance                 # Generate compliance report
            """,
        subcommands: [
            Agents.self,
            FleetStatus.self,
            Deploy.self,
            Compliance.self,
            Audit.self
        ],
        defaultSubcommand: FleetStatus.self
    )
}

// MARK: - Agents Subcommand

extension FleetCommand {
    struct Agents: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "agents",
            abstract: "List all registered agents"
        )

        @Option(name: .shortAndLong, help: "Filter by connection state (active, offline, pending)")
        var state: String?

        @Option(name: .long, help: "Filter by tag")
        var tag: String?

        @Option(name: .long, help: "Filter by capability")
        var capability: String?

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let registry = AgentRegistry()

            var agents = await registry.allAgents()

            // Apply filters
            if let stateFilter = state {
                if let connectionState = AgentConnectionState(rawValue: stateFilter) {
                    agents = agents.filter { $0.connectionState == connectionState }
                }
            }

            if let tagFilter = tag {
                agents = agents.filter { $0.identity.tags.contains(tagFilter) }
            }

            if let capFilter = capability {
                agents = agents.filter { $0.capabilities.contains(capFilter) }
            }

            if agents.isEmpty {
                progressView.display(message: "No agents found")
                return
            }

            if json {
                let output = agents.map { AgentSummary(from: $0) }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(output)
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else {
                printAgentTable(agents, progressView: progressView)
            }
        }

        private func printAgentTable(_ agents: [RegisteredAgent], progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"

            progressView.display(message: "")
            progressView.display(message: "╔══════════════════════════════════════╤══════════╤══════════════════╤═══════════════╗")
            progressView.display(message: "║               Agent ID               │  Status  │     Hostname     │  Last Seen    ║")
            progressView.display(message: "╠══════════════════════════════════════╪══════════╪══════════════════╪═══════════════╣")

            for agent in agents {
                let id = agent.identity.id.uuidString.prefix(36).padding(toLength: 36, withPad: " ", startingAt: 0)
                let status = statusIcon(agent.connectionState).padding(toLength: 8, withPad: " ", startingAt: 0)
                let hostname = String(agent.identity.hostname.prefix(16)).padding(toLength: 16, withPad: " ", startingAt: 0)
                let lastSeen: String
                if let heartbeat = agent.lastHeartbeat {
                    lastSeen = formatter.string(from: heartbeat)
                } else {
                    lastSeen = "Never"
                }
                let lastSeenPadded = lastSeen.padding(toLength: 13, withPad: " ", startingAt: 0)

                progressView.display(message: "║ \(id) │ \(status) │ \(hostname) │ \(lastSeenPadded) ║")
            }

            progressView.display(message: "╚══════════════════════════════════════╧══════════╧══════════════════╧═══════════════╝")
            progressView.display(message: "")
            progressView.display(message: "Legend: ● active, ○ pending, ◌ offline, ✗ rejected")
            progressView.display(message: "Showing \(agents.count) agent(s)")
        }

        private func statusIcon(_ state: AgentConnectionState) -> String {
            switch state {
            case .active: return "● active"
            case .pending: return "○ pending"
            case .offline: return "◌ offline"
            case .rejected: return "✗ reject"
            case .disconnected: return "◌ discon"
            }
        }
    }
}

// MARK: - FleetStatus Subcommand

extension FleetCommand {
    struct FleetStatus: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show fleet-wide status and statistics"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let registry = AgentRegistry()
            let stats = await registry.statistics()

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(stats)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                printFleetStatus(stats, progressView: progressView)
            }
        }

        private func printFleetStatus(_ stats: RegistryStatistics, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                     FLEET STATUS                          ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
            progressView.display(message: "  Connection Status")
            progressView.display(message: "  ─────────────────────────────────────────────────────────")
            progressView.display(message: "    Total Agents:     \(stats.totalAgents)")
            progressView.display(message: "    Active:           \(stats.activeAgents) ●")
            progressView.display(message: "    Offline:          \(stats.offlineAgents) ◌")
            progressView.display(message: "    Pending:          \(stats.pendingAgents) ○")
            progressView.display(message: "")
            progressView.display(message: "  Health Status")
            progressView.display(message: "  ─────────────────────────────────────────────────────────")
            progressView.display(message: "    Healthy:          \(stats.healthyAgents) ✓")
            progressView.display(message: "    Warning:          \(stats.warningAgents) ⚠")
            progressView.display(message: "    Critical:         \(stats.criticalAgents) ✗")
            progressView.display(message: "")
            progressView.display(message: "  Timestamp:          \(formatter.string(from: stats.timestamp))")
            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }
    }
}

// MARK: - Deploy Subcommand

extension FleetCommand {
    struct Deploy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "deploy",
            abstract: "Deploy a policy to agents"
        )

        @Argument(help: "Policy name to deploy")
        var policyName: String

        @Flag(name: .long, help: "Deploy to all registered agents")
        var all: Bool = false

        @Option(name: .long, help: "Deploy to agents with specific tag")
        var tag: String?

        @Option(name: .long, help: "Deploy to specific agent IDs (comma-separated)")
        var agents: String?

        @Flag(name: .long, help: "Dry run - show what would be deployed")
        var dryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()

            // Validate target selection
            if !all && tag == nil && agents == nil {
                progressView.display(message: "✗ Please specify a target: --all, --tag, or --agents")
                return
            }

            // Load policy
            let store = try PolicyStore()
            let policy: Policy
            do {
                policy = try store.get(policyName)
            } catch {
                progressView.display(message: "✗ Policy '\(policyName)' not found")
                return
            }

            // Determine target
            let target: DistributionTarget
            if all {
                target = .all
            } else if let tagValue = tag {
                target = .tags([tagValue])
            } else if let agentIds = agents {
                let ids = agentIds.split(separator: ",").compactMap { UUID(uuidString: String($0.trimmingCharacters(in: .whitespaces))) }
                target = .agents(ids)
            } else {
                target = .all
            }

            let registry = AgentRegistry()
            let distributor = PolicyDistributor(registry: registry)

            if dryRun {
                progressView.display(message: "Dry run - would deploy policy '\(policyName)' to:")

                let targetAgents = await getTargetAgents(target: target, registry: registry)
                for agent in targetAgents {
                    progressView.display(message: "  - \(agent.identity.hostname) (\(agent.identity.id))")
                }
                progressView.display(message: "")
                progressView.display(message: "Total: \(targetAgents.count) agent(s)")
                return
            }

            progressView.display(message: "Deploying policy '\(policyName)'...")

            do {
                let status = try await distributor.distribute(policy: policy, to: target)

                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(status)
                    print(String(data: data, encoding: .utf8) ?? "{}")
                } else {
                    progressView.display(message: "")
                    progressView.displaySuccess("Policy deployment initiated")
                    progressView.display(message: "  Distribution ID:  \(status.id)")
                    progressView.display(message: "  Target Agents:    \(status.totalAgents)")
                    progressView.display(message: "  Status:           \(status.state.rawValue)")
                }
            } catch {
                progressView.display(message: "✗ Deployment failed: \(error.localizedDescription)")
            }
        }

        private func getTargetAgents(target: DistributionTarget, registry: AgentRegistry) async -> [RegisteredAgent] {
            switch target {
            case .all:
                return await registry.allAgents()
            case .agents(let ids):
                var result: [RegisteredAgent] = []
                for id in ids {
                    if let agent = await registry.agent(byId: id) {
                        result.append(agent)
                    }
                }
                return result
            case .tags(let tags):
                return await registry.agents(withTags: Array(tags))
            case .capabilities(let caps):
                var result: [RegisteredAgent] = []
                for cap in caps {
                    result.append(contentsOf: await registry.agents(withCapability: cap))
                }
                return Array(Set(result.map { $0.identity.id })).compactMap { id in
                    result.first { $0.identity.id == id }
                }
            case .filter, .combined:
                return await registry.allAgents()
            }
        }
    }
}

// MARK: - Compliance Subcommand

extension FleetCommand {
    struct Compliance: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compliance",
            abstract: "Generate fleet compliance report"
        )

        @Option(name: .shortAndLong, help: "Export format (json, csv)")
        var format: String = "text"

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        mutating func run() async throws {
            let progressView = ProgressView()
            let registry = AgentRegistry()
            let distributor = PolicyDistributor(registry: registry)
            let reporter = ComplianceReporter(registry: registry, distributor: distributor)

            progressView.display(message: "Generating compliance report...")

            do {
                let report = try await reporter.generateFleetOverview()

                switch format.lowercased() {
                case "json":
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(report)
                    let jsonString = String(data: data, encoding: .utf8) ?? "{}"

                    if let outputPath = output {
                        try jsonString.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                        progressView.displaySuccess("Report exported to \(outputPath)")
                    } else {
                        print(jsonString)
                    }

                case "csv":
                    let csv = generateCSV(from: report)
                    if let outputPath = output {
                        try csv.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                        progressView.displaySuccess("Report exported to \(outputPath)")
                    } else {
                        print(csv)
                    }

                default:
                    printComplianceReport(report, progressView: progressView)
                }
            } catch {
                progressView.display(message: "✗ Failed to generate report: \(error.localizedDescription)")
            }
        }

        private func printComplianceReport(_ report: FleetOverviewReport, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            let complianceRate = report.totalAgents > 0
                ? Double(report.compliantAgents) / Double(report.totalAgents) * 100
                : 0.0
            let partiallyCompliant = report.complianceLevelBreakdown[.partiallyCompliant] ?? 0

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                  FLEET COMPLIANCE REPORT                  ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
            progressView.display(message: "  Generated:        \(formatter.string(from: report.generatedAt))")
            progressView.display(message: "")
            progressView.display(message: "  Fleet Overview")
            progressView.display(message: "  ─────────────────────────────────────────────────────────")
            progressView.display(message: "    Total Agents:         \(report.totalAgents)")
            progressView.display(message: "    Compliant:            \(report.compliantAgents) ✓")
            progressView.display(message: "    Partially Compliant:  \(partiallyCompliant) ⚠")
            progressView.display(message: "    Non-Compliant:        \(report.nonCompliantAgents) ✗")
            progressView.display(message: "    Critical:             \(report.criticalAgents) ✗✗")
            progressView.display(message: "")
            progressView.display(message: "  Compliance Rate:        \(String(format: "%.1f", complianceRate))%")
            progressView.display(message: "  Average Score:          \(String(format: "%.2f", report.averageComplianceScore))")
            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }

        private func generateCSV(from report: FleetOverviewReport) -> String {
            let complianceRate = report.totalAgents > 0
                ? Double(report.compliantAgents) / Double(report.totalAgents) * 100
                : 0.0
            let partiallyCompliant = report.complianceLevelBreakdown[.partiallyCompliant] ?? 0

            var lines = ["Metric,Value"]
            lines.append("Total Agents,\(report.totalAgents)")
            lines.append("Compliant,\(report.compliantAgents)")
            lines.append("Partially Compliant,\(partiallyCompliant)")
            lines.append("Non-Compliant,\(report.nonCompliantAgents)")
            lines.append("Critical,\(report.criticalAgents)")
            lines.append("Compliance Rate,\(String(format: "%.2f", complianceRate))%")
            lines.append("Average Score,\(String(format: "%.2f", report.averageComplianceScore))")
            return lines.joined(separator: "\n")
        }
    }
}

// MARK: - Audit Subcommand

extension FleetCommand {
    struct Audit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "audit",
            abstract: "Show fleet audit log summary"
        )

        @Option(name: .shortAndLong, help: "Number of days to include (default: 7)")
        var days: Int = 7

        @Option(name: .long, help: "Filter by category (cleanup, policy, security, system)")
        var category: String?

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let registry = AgentRegistry()
            let distributor = PolicyDistributor(registry: registry)
            let reporter = ComplianceReporter(registry: registry, distributor: distributor)

            let periodEnd = Date()
            let periodStart = Calendar.current.date(byAdding: .day, value: -days, to: periodEnd) ?? periodEnd

            progressView.display(message: "Generating audit log summary...")

            do {
                let summary = try await reporter.generateAuditLogSummary(
                    periodStart: periodStart,
                    periodEnd: periodEnd
                )

                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(summary)
                    print(String(data: data, encoding: .utf8) ?? "{}")
                } else {
                    printAuditSummary(summary, progressView: progressView)
                }
            } catch {
                progressView.display(message: "✗ Failed to generate audit summary: \(error.localizedDescription)")
            }
        }

        private func printAuditSummary(_ summary: AuditLogSummary, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                    FLEET AUDIT SUMMARY                    ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")
            progressView.display(message: "  Period: \(formatter.string(from: summary.periodStart)) - \(formatter.string(from: summary.periodEnd))")
            progressView.display(message: "  Total Entries: \(summary.totalEntries)")
            progressView.display(message: "")
            progressView.display(message: "  Entries by Category")
            progressView.display(message: "  ─────────────────────────────────────────────────────────")

            for (category, count) in summary.entriesByCategory.sorted(by: { $0.value > $1.value }) {
                progressView.display(message: "    \(category.padding(toLength: 12, withPad: " ", startingAt: 0)): \(count)")
            }

            progressView.display(message: "")
            progressView.display(message: "  Entries by Severity")
            progressView.display(message: "  ─────────────────────────────────────────────────────────")

            for (severity, count) in summary.entriesBySeverity.sorted(by: { $0.value > $1.value }) {
                let icon: String
                switch severity {
                case .critical: icon = "✗✗"
                case .error: icon = "✗"
                case .warning: icon = "⚠"
                case .info: icon = "ℹ"
                }
                progressView.display(message: "    \(icon) \(severity.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)): \(count)")
            }

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }
    }
}

// MARK: - Helper Types

private struct AgentSummary: Codable {
    let id: UUID
    let hostname: String
    let connectionState: String
    let healthStatus: String?
    let lastHeartbeat: Date?
    let tags: [String]

    init(from agent: RegisteredAgent) {
        self.id = agent.identity.id
        self.hostname = agent.identity.hostname
        self.connectionState = agent.connectionState.rawValue
        self.healthStatus = agent.latestStatus?.healthStatus.rawValue
        self.lastHeartbeat = agent.lastHeartbeat
        self.tags = agent.identity.tags
    }
}

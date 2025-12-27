import XCTest
@testable import OSXCleanerKit

final class ComplianceReporterTests: XCTestCase {

    // MARK: - Test Fixtures

    private var registry: AgentRegistry!
    private var distributor: PolicyDistributor!
    private var reporter: ComplianceReporter!

    override func setUp() async throws {
        registry = AgentRegistry()

        let distributorConfig = PolicyDistributorConfig(
            maxConcurrentDistributions: 10,
            maxRetryAttempts: 3,
            retryDelay: 0.1,
            acknowledgementTimeout: 0.1,
            continueOnFailure: true,
            minimumSuccessRate: 80,
            autoRollbackOnFailure: false
        )
        distributor = PolicyDistributor(configuration: distributorConfig, registry: registry)

        let reporterConfig = ComplianceReporterConfig(
            policyWeight: 0.4,
            healthWeight: 0.3,
            connectivityWeight: 0.3,
            heartbeatTimeout: 300,
            maxAuditLogEntries: 100
        )
        reporter = ComplianceReporter(
            configuration: reporterConfig,
            registry: registry,
            distributor: distributor
        )
    }

    // MARK: - ComplianceScore Tests

    func testComplianceScoreInitialization() {
        let score = ComplianceScore(
            agentId: UUID(),
            overallScore: 85.5,
            policyScore: 90.0,
            healthScore: 80.0,
            connectivityScore: 85.0,
            activePolicies: 3,
            policiesWithIssues: 1
        )

        XCTAssertEqual(score.overallScore, 85.5, accuracy: 0.1)
        XCTAssertEqual(score.policyScore, 90.0, accuracy: 0.1)
        XCTAssertEqual(score.healthScore, 80.0, accuracy: 0.1)
        XCTAssertEqual(score.connectivityScore, 85.0, accuracy: 0.1)
        XCTAssertEqual(score.activePolicies, 3)
        XCTAssertEqual(score.policiesWithIssues, 1)
    }

    func testComplianceScoreClamping() {
        let overScore = ComplianceScore(
            agentId: UUID(),
            overallScore: 150.0,
            policyScore: -10.0,
            healthScore: 100.0,
            connectivityScore: 100.0
        )

        XCTAssertEqual(overScore.overallScore, 100.0, accuracy: 0.1)
        XCTAssertEqual(overScore.policyScore, 0.0, accuracy: 0.1)
    }

    func testComplianceLevels() {
        XCTAssertEqual(ComplianceLevel.from(score: 95), .compliant)
        XCTAssertEqual(ComplianceLevel.from(score: 90), .compliant)
        XCTAssertEqual(ComplianceLevel.from(score: 80), .partiallyCompliant)
        XCTAssertEqual(ComplianceLevel.from(score: 70), .partiallyCompliant)
        XCTAssertEqual(ComplianceLevel.from(score: 60), .nonCompliant)
        XCTAssertEqual(ComplianceLevel.from(score: 50), .nonCompliant)
        XCTAssertEqual(ComplianceLevel.from(score: 40), .critical)
        XCTAssertEqual(ComplianceLevel.from(score: 0), .critical)
    }

    func testComplianceScoreComplianceLevel() {
        let compliantScore = ComplianceScore(
            agentId: UUID(),
            overallScore: 95.0,
            policyScore: 100.0,
            healthScore: 100.0,
            connectivityScore: 100.0
        )
        XCTAssertEqual(compliantScore.complianceLevel, .compliant)
        XCTAssertTrue(compliantScore.isCompliant)

        let criticalScore = ComplianceScore(
            agentId: UUID(),
            overallScore: 30.0,
            policyScore: 30.0,
            healthScore: 30.0,
            connectivityScore: 30.0
        )
        XCTAssertEqual(criticalScore.complianceLevel, .critical)
        XCTAssertFalse(criticalScore.isCompliant)
    }

    // MARK: - Score Calculation Tests

    func testCalculateScoreForAgent() async throws {
        let agent = try await registerTestAgent(name: "TestAgent")
        let score = try await reporter.calculateScore(for: agent.identity.id)

        XCTAssertEqual(score.agentId, agent.identity.id)
        XCTAssertGreaterThanOrEqual(score.overallScore, 0)
        XCTAssertLessThanOrEqual(score.overallScore, 100)
        XCTAssertNotNil(score.calculatedAt)
    }

    func testCalculateScoreForNonexistentAgent() async {
        let randomId = UUID()

        do {
            _ = try await reporter.calculateScore(for: randomId)
            XCTFail("Should have thrown agentNotFound error")
        } catch let error as ComplianceReportError {
            if case .agentNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateAllScores() async throws {
        _ = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")
        _ = try await registerTestAgent(name: "Agent3")

        let scores = try await reporter.calculateAllScores()

        XCTAssertEqual(scores.count, 3)
        for score in scores {
            XCTAssertGreaterThanOrEqual(score.overallScore, 0)
            XCTAssertLessThanOrEqual(score.overallScore, 100)
        }
    }

    func testCalculateAllScoresNoAgents() async {
        do {
            _ = try await reporter.calculateAllScores()
            XCTFail("Should have thrown noAgentsFound error")
        } catch let error as ComplianceReportError {
            if case .noAgentsFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCachedScore() async throws {
        let agent = try await registerTestAgent(name: "CacheTest")

        // Initially no cached score
        var cached = await reporter.cachedScore(for: agent.identity.id)
        XCTAssertNil(cached)

        // Calculate score
        _ = try await reporter.calculateScore(for: agent.identity.id)

        // Now should be cached
        cached = await reporter.cachedScore(for: agent.identity.id)
        XCTAssertNotNil(cached)
    }

    // MARK: - Fleet Overview Report Tests

    func testGenerateFleetOverview() async throws {
        _ = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")
        _ = try await registerTestAgent(name: "Agent3")

        let report = try await reporter.generateFleetOverview()

        XCTAssertEqual(report.totalAgents, 3)
        XCTAssertEqual(report.activeAgents, 3)
        XCTAssertEqual(report.offlineAgents, 0)
        XCTAssertGreaterThanOrEqual(report.averageComplianceScore, 0)
        XCTAssertLessThanOrEqual(report.averageComplianceScore, 100)
        XCTAssertNotNil(report.generatedAt)
        XCTAssertEqual(report.reportType, .fleetOverview)
    }

    func testFleetOverviewWithPeriod() async throws {
        _ = try await registerTestAgent(name: "Agent1")

        let periodStart = Date().addingTimeInterval(-86400)
        let periodEnd = Date()

        let report = try await reporter.generateFleetOverview(
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        XCTAssertEqual(report.periodStart, periodStart)
        XCTAssertEqual(report.periodEnd, periodEnd)
    }

    func testFleetOverviewComputedProperties() async throws {
        _ = try await registerTestAgent(name: "Agent1")
        _ = try await registerTestAgent(name: "Agent2")

        let report = try await reporter.generateFleetOverview()

        XCTAssertGreaterThanOrEqual(report.complianceRate, 0)
        XCTAssertLessThanOrEqual(report.complianceRate, 100)
    }

    // MARK: - Agent Compliance Report Tests

    func testGenerateAgentReport() async throws {
        let agent = try await registerTestAgent(name: "DetailedAgent", tags: ["production"])
        let report = try await reporter.generateAgentReport(for: agent.identity.id)

        XCTAssertEqual(report.agentId, agent.identity.id)
        XCTAssertEqual(report.hostname, agent.identity.hostname)
        XCTAssertEqual(report.tags, ["production"])
        XCTAssertNotNil(report.complianceScore)
        XCTAssertEqual(report.reportType, .agentCompliance)
    }

    func testGenerateAgentReportForNonexistent() async {
        let randomId = UUID()

        do {
            _ = try await reporter.generateAgentReport(for: randomId)
            XCTFail("Should have thrown agentNotFound error")
        } catch let error as ComplianceReportError {
            if case .agentNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Policy Execution Report Tests

    func testGeneratePolicyExecutionReport() async throws {
        _ = try await registerTestAgent(name: "PolicyAgent")
        let policy = createTestPolicy(name: "exec-report-test")

        let distribution = try await distributor.distribute(policy: policy, to: .all)
        let report = try await reporter.generatePolicyExecutionReport(
            distributionId: distribution.id
        )

        XCTAssertEqual(report.policyName, "exec-report-test")
        XCTAssertEqual(report.version, distribution.policyVersion)
        XCTAssertEqual(report.totalTargetedAgents, 1)
        XCTAssertEqual(report.reportType, .policyExecution)
    }

    func testGeneratePolicyExecutionReportNotFound() async {
        let randomId = UUID()

        do {
            _ = try await reporter.generatePolicyExecutionReport(distributionId: randomId)
            XCTFail("Should have thrown distributionNotFound error")
        } catch let error as ComplianceReportError {
            if case .distributionNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Audit Log Tests

    func testRecordAuditLog() async throws {
        let agent = try await registerTestAgent(name: "AuditAgent")

        await reporter.recordAuditLog(
            agentId: agent.identity.id,
            severity: .info,
            category: "cleanup",
            message: "Cleanup completed successfully"
        )

        let logs = await reporter.recentAuditLogs(limit: 10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].agentId, agent.identity.id)
        XCTAssertEqual(logs[0].severity, .info)
        XCTAssertEqual(logs[0].category, "cleanup")
    }

    func testAuditLogSummary() async throws {
        let agent = try await registerTestAgent(name: "SummaryAgent")

        // Record multiple audit logs
        await reporter.recordAuditLog(
            agentId: agent.identity.id,
            severity: .info,
            category: "cleanup",
            message: "Info message 1"
        )
        await reporter.recordAuditLog(
            agentId: agent.identity.id,
            severity: .warning,
            category: "policy",
            message: "Warning message"
        )
        await reporter.recordAuditLog(
            agentId: agent.identity.id,
            severity: .critical,
            category: "system",
            message: "Critical message"
        )

        let periodStart = Date().addingTimeInterval(-3600)
        let periodEnd = Date().addingTimeInterval(3600)

        let summary = try await reporter.generateAuditLogSummary(
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        XCTAssertEqual(summary.totalEntries, 3)
        XCTAssertEqual(summary.entriesBySeverity[.info], 1)
        XCTAssertEqual(summary.entriesBySeverity[.warning], 1)
        XCTAssertEqual(summary.entriesBySeverity[.critical], 1)
        XCTAssertEqual(summary.reportType, .auditLogSummary)
    }

    func testAuditLogSummaryInvalidDateRange() async {
        let periodStart = Date()
        let periodEnd = Date().addingTimeInterval(-3600) // Earlier than start

        do {
            _ = try await reporter.generateAuditLogSummary(
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            XCTFail("Should have thrown invalidDateRange error")
        } catch let error as ComplianceReportError {
            if case .invalidDateRange = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Export Tests

    func testExportFleetOverviewToJSON() async throws {
        _ = try await registerTestAgent(name: "ExportAgent")

        let report = try await reporter.generateFleetOverview()
        let data = try await reporter.exportFleetOverview(report, format: .json)

        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testExportFleetOverviewToCSV() async throws {
        _ = try await registerTestAgent(name: "CSVAgent")

        let report = try await reporter.generateFleetOverview()
        let data = try await reporter.exportFleetOverview(report, format: .csv)

        XCTAssertNotNil(data)
        let csvString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(csvString)
        XCTAssertTrue(csvString!.contains("Metric,Value"))
        XCTAssertTrue(csvString!.contains("Total Agents"))
    }

    func testExportAgentReportToJSON() async throws {
        let agent = try await registerTestAgent(name: "AgentExportTest")

        let report = try await reporter.generateAgentReport(for: agent.identity.id)
        let data = try await reporter.exportAgentReport(report, format: .json)

        XCTAssertNotNil(data)

        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testExportAgentReportToCSV() async throws {
        let agent = try await registerTestAgent(name: "AgentCSVTest")

        let report = try await reporter.generateAgentReport(for: agent.identity.id)
        let data = try await reporter.exportAgentReport(report, format: .csv)

        XCTAssertNotNil(data)
        let csvString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(csvString)
        XCTAssertTrue(csvString!.contains("Metric,Value"))
        XCTAssertTrue(csvString!.contains("Agent ID"))
    }

    func testExportPolicyExecutionToCSV() async throws {
        _ = try await registerTestAgent(name: "PolicyCSVAgent")
        let policy = createTestPolicy(name: "csv-export-test")

        let distribution = try await distributor.distribute(policy: policy, to: .all)
        let report = try await reporter.generatePolicyExecutionReport(
            distributionId: distribution.id
        )

        let data = try await reporter.exportPolicyExecutionReport(report, format: .csv)

        XCTAssertNotNil(data)
        let csvString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(csvString)
        XCTAssertTrue(csvString!.contains("Agent ID,Hostname,Status"))
    }

    // MARK: - Model Tests

    func testAgentCleanupStats() {
        let stats = AgentCleanupStats(
            totalBytesFreed: 1_000_000,
            operationCount: 10,
            lastCleanupAt: Date()
        )

        XCTAssertEqual(stats.totalBytesFreed, 1_000_000)
        XCTAssertEqual(stats.operationCount, 10)
        XCTAssertEqual(stats.averageBytesPerOperation, 100_000)
    }

    func testAgentCleanupStatsZeroOperations() {
        let stats = AgentCleanupStats(
            totalBytesFreed: 1_000_000,
            operationCount: 0
        )

        XCTAssertEqual(stats.averageBytesPerOperation, 0)
    }

    func testPolicyExecutionRecord() {
        let record = PolicyExecutionRecord(
            policyName: "test-policy",
            version: 2,
            status: .completed,
            executedAt: Date()
        )

        XCTAssertEqual(record.policyName, "test-policy")
        XCTAssertEqual(record.version, 2)
        XCTAssertEqual(record.status, .completed)
        XCTAssertNil(record.errorMessage)
    }

    func testAgentPolicyStatus() {
        let status = AgentPolicyStatus(
            agentId: UUID(),
            hostname: "test-host",
            status: .failed,
            errorMessage: "Connection timeout",
            executedAt: Date()
        )

        XCTAssertEqual(status.hostname, "test-host")
        XCTAssertEqual(status.status, .failed)
        XCTAssertEqual(status.errorMessage, "Connection timeout")
    }

    func testAgentLogVolume() {
        let volume = AgentLogVolume(
            agentId: UUID(),
            hostname: "log-host",
            entryCount: 150
        )

        XCTAssertEqual(volume.hostname, "log-host")
        XCTAssertEqual(volume.entryCount, 150)
    }

    func testAuditLogEntry() {
        let entry = AuditLogEntry(
            agentId: UUID(),
            severity: .warning,
            category: "security",
            message: "Suspicious activity detected"
        )

        XCTAssertEqual(entry.severity, .warning)
        XCTAssertEqual(entry.category, "security")
        XCTAssertEqual(entry.message, "Suspicious activity detected")
    }

    // MARK: - Configuration Tests

    func testReporterConfiguration() async {
        let customConfig = ComplianceReporterConfig(
            policyWeight: 0.5,
            healthWeight: 0.25,
            connectivityWeight: 0.25,
            heartbeatTimeout: 600,
            maxAuditLogEntries: 50
        )

        let customReporter = ComplianceReporter(
            configuration: customConfig,
            registry: registry,
            distributor: distributor
        )

        XCTAssertNotNil(customReporter)
    }

    // MARK: - Error Tests

    func testComplianceReportErrorDescriptions() {
        let errors: [ComplianceReportError] = [
            .noAgentsFound,
            .agentNotFound(UUID()),
            .policyNotFound("test-policy"),
            .distributionNotFound(UUID()),
            .invalidDateRange,
            .exportFailed("Test failure")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Report Type Tests

    func testReportTypeRawValues() {
        XCTAssertEqual(ReportType.fleetOverview.rawValue, "fleet-overview")
        XCTAssertEqual(ReportType.agentCompliance.rawValue, "agent-compliance")
        XCTAssertEqual(ReportType.policyExecution.rawValue, "policy-execution")
        XCTAssertEqual(ReportType.auditLogSummary.rawValue, "audit-log-summary")
    }

    func testReportExportFormatRawValues() {
        XCTAssertEqual(ReportExportFormat.json.rawValue, "json")
        XCTAssertEqual(ReportExportFormat.csv.rawValue, "csv")
    }

    // MARK: - Codable Tests

    func testComplianceScoreCodable() throws {
        let score = ComplianceScore(
            agentId: UUID(),
            overallScore: 85.0,
            policyScore: 90.0,
            healthScore: 80.0,
            connectivityScore: 85.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(score)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ComplianceScore.self, from: data)

        XCTAssertEqual(decoded.overallScore, score.overallScore, accuracy: 0.1)
        XCTAssertEqual(decoded.agentId, score.agentId)
    }

    func testFleetOverviewReportCodable() throws {
        let report = FleetOverviewReport(
            totalAgents: 10,
            activeAgents: 8,
            offlineAgents: 2,
            averageComplianceScore: 85.0,
            compliantAgents: 7,
            nonCompliantAgents: 2,
            criticalAgents: 1,
            totalPoliciesDeployed: 5,
            successfulDeployments: 4,
            failedDeployments: 1,
            totalBytesFreed: 1_000_000_000,
            totalCleanupOperations: 50,
            complianceLevelBreakdown: [.compliant: 7, .partiallyCompliant: 2, .critical: 1]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(report)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FleetOverviewReport.self, from: data)

        XCTAssertEqual(decoded.totalAgents, report.totalAgents)
        XCTAssertEqual(decoded.averageComplianceScore, report.averageComplianceScore, accuracy: 0.1)
    }

    // MARK: - Helper Methods

    @discardableResult
    private func registerTestAgent(
        name: String,
        tags: [String] = [],
        capabilities: [String] = ["cleanup"]
    ) async throws -> RegisteredAgent {
        let identity = AgentIdentity(
            name: name,
            appVersion: "1.0.0",
            tags: tags
        )
        return try await registry.register(
            identity: identity,
            capabilities: capabilities
        )
    }

    private func createTestPolicy(name: String) -> Policy {
        Policy(
            name: name,
            displayName: "Test Policy: \(name)",
            description: "A test policy",
            rules: [
                PolicyRule(
                    id: "\(name)-rule",
                    target: .systemCaches,
                    action: .report,
                    schedule: .manual
                )
            ]
        )
    }
}

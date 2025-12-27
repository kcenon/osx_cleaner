// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during policy execution
public enum PolicyEngineError: LocalizedError {
    case policyNotFound(String)
    case ruleExecutionFailed(String, String)
    case conditionCheckFailed(String)
    case targetNotSupported(PolicyTarget)
    case noPoliciesEnabled
    case executionCancelled

    public var errorDescription: String? {
        switch self {
        case .policyNotFound(let name):
            return "Policy not found: '\(name)'"
        case .ruleExecutionFailed(let ruleId, let reason):
            return "Rule '\(ruleId)' failed: \(reason)"
        case .conditionCheckFailed(let reason):
            return "Condition check failed: \(reason)"
        case .targetNotSupported(let target):
            return "Target not supported: '\(target.rawValue)'"
        case .noPoliciesEnabled:
            return "No enabled policies found"
        case .executionCancelled:
            return "Policy execution was cancelled"
        }
    }
}

/// Configuration for policy engine execution
public struct PolicyEngineConfig: Sendable {
    /// Whether to run in dry-run mode (report only, no actual cleanup)
    public let dryRun: Bool

    /// Maximum concurrent rules to execute
    public let maxConcurrentRules: Int

    /// Whether to stop on first error
    public let stopOnError: Bool

    /// Whether to log to audit system
    public let auditLogging: Bool

    public init(
        dryRun: Bool = false,
        maxConcurrentRules: Int = 4,
        stopOnError: Bool = false,
        auditLogging: Bool = true
    ) {
        self.dryRun = dryRun
        self.maxConcurrentRules = maxConcurrentRules
        self.stopOnError = stopOnError
        self.auditLogging = auditLogging
    }

    /// Default configuration for normal execution
    public static let `default` = PolicyEngineConfig()

    /// Configuration for dry-run mode
    public static let dryRun = PolicyEngineConfig(dryRun: true)
}

/// Progress callback for policy execution
public typealias PolicyProgressCallback = (PolicyExecutionProgress) -> Void

/// Progress information during policy execution
public struct PolicyExecutionProgress: Sendable {
    public let policyName: String
    public let currentRule: String
    public let rulesCompleted: Int
    public let totalRules: Int
    public let bytesFreed: UInt64
    public let itemsProcessed: Int

    public var percentComplete: Double {
        guard totalRules > 0 else { return 0 }
        return Double(rulesCompleted) / Double(totalRules) * 100
    }
}

/// Policy execution engine that applies cleanup policies
public actor PolicyEngine {

    // MARK: - Properties

    private let store: PolicyStore
    private let cleanerService: CleanerService
    private let config: PolicyEngineConfig
    private var isCancelled: Bool = false

    // MARK: - Initialization

    public init(
        store: PolicyStore,
        cleanerService: CleanerService = CleanerService(),
        config: PolicyEngineConfig = .default
    ) {
        self.store = store
        self.cleanerService = cleanerService
        self.config = config
    }

    // MARK: - Execution Methods

    /// Execute a single policy by name
    public func execute(
        policyName: String,
        progress: PolicyProgressCallback? = nil
    ) async throws -> PolicyExecutionResult {
        let policy = try store.get(policyName)
        return try await execute(policy: policy, progress: progress)
    }

    /// Execute a single policy
    public func execute(
        policy: Policy,
        progress: PolicyProgressCallback? = nil
    ) async throws -> PolicyExecutionResult {
        isCancelled = false

        guard policy.enabled else {
            return PolicyExecutionResult(
                policyName: policy.name,
                success: true,
                ruleResults: [],
                executedAt: Date()
            )
        }

        let enabledRules = policy.enabledRules
        var ruleResults: [PolicyRuleResult] = []
        var overallSuccess = true

        AppLogger.shared.info("Executing policy: \(policy.name) with \(enabledRules.count) rules")

        // Log policy start to audit
        if config.auditLogging {
            await logAuditEvent(.policy(
                action: "execute_start",
                policyName: policy.name,
                result: .success,
                details: ["rules_count": "\(enabledRules.count)"]
            ))
        }

        for (index, rule) in enabledRules.enumerated() {
            // Check for cancellation
            if isCancelled {
                throw PolicyEngineError.executionCancelled
            }

            // Report progress
            let progressInfo = PolicyExecutionProgress(
                policyName: policy.name,
                currentRule: rule.id,
                rulesCompleted: index,
                totalRules: enabledRules.count,
                bytesFreed: ruleResults.reduce(0) { $0 + $1.bytesFreed },
                itemsProcessed: ruleResults.reduce(0) { $0 + $1.itemsProcessed }
            )
            progress?(progressInfo)

            // Check conditions
            if let conditions = rule.conditions {
                let conditionsMet = try await checkConditions(conditions)
                if !conditionsMet {
                    AppLogger.shared.debug("Rule '\(rule.id)' skipped: conditions not met")
                    ruleResults.append(PolicyRuleResult(
                        ruleId: rule.id,
                        success: true,
                        error: "Conditions not met - skipped"
                    ))
                    continue
                }
            }

            // Execute rule
            let result = await executeRule(rule, policy: policy)
            ruleResults.append(result)

            if !result.success {
                overallSuccess = false
                if config.stopOnError {
                    break
                }
            }
        }

        // Log policy completion to audit
        if config.auditLogging {
            await logAuditEvent(.policy(
                action: "execute_complete",
                policyName: policy.name,
                result: overallSuccess ? .success : .failure,
                details: [
                    "rules_executed": "\(ruleResults.count)",
                    "rules_success": "\(ruleResults.filter { $0.success }.count)",
                    "bytes_freed": "\(ruleResults.reduce(0) { $0 + $1.bytesFreed })"
                ]
            ))
        }

        return PolicyExecutionResult(
            policyName: policy.name,
            success: overallSuccess,
            ruleResults: ruleResults,
            executedAt: Date()
        )
    }

    /// Execute all enabled policies
    public func executeAll(
        progress: PolicyProgressCallback? = nil
    ) async throws -> [PolicyExecutionResult] {
        let policies = try store.enabledPolicies()

        guard !policies.isEmpty else {
            throw PolicyEngineError.noPoliciesEnabled
        }

        var results: [PolicyExecutionResult] = []

        for policy in policies.sorted(by: { $0.priority > $1.priority }) {
            if isCancelled {
                break
            }

            let result = try await execute(policy: policy, progress: progress)
            results.append(result)
        }

        return results
    }

    /// Execute policies for a specific schedule
    public func executeScheduled(
        schedule: PolicySchedule,
        progress: PolicyProgressCallback? = nil
    ) async throws -> [PolicyExecutionResult] {
        let policies = try store.policies(forSchedule: schedule)

        var results: [PolicyExecutionResult] = []

        for policy in policies {
            if isCancelled {
                break
            }

            // Only execute rules matching the schedule
            var filteredPolicy = policy
            filteredPolicy.rules = policy.rules(for: schedule)

            if !filteredPolicy.rules.isEmpty {
                let result = try await execute(policy: filteredPolicy, progress: progress)
                results.append(result)
            }
        }

        return results
    }

    /// Cancel ongoing execution
    public func cancel() {
        isCancelled = true
    }

    // MARK: - Rule Execution

    private func executeRule(
        _ rule: PolicyRule,
        policy: Policy
    ) async -> PolicyRuleResult {
        let startTime = Date()

        AppLogger.shared.debug("Executing rule: \(rule.id) (target: \(rule.target.rawValue))")

        // Handle dry-run mode
        if config.dryRun || rule.action == .report {
            return await simulateRule(rule, policy: policy, startTime: startTime)
        }

        do {
            let cleanerConfig = try mapRuleToCleanerConfig(rule, exclusions: policy.exclusions)
            let result = try await cleanerService.clean(with: cleanerConfig)

            return PolicyRuleResult(
                ruleId: rule.id,
                success: true,
                itemsProcessed: result.filesRemoved + result.directoriesRemoved,
                bytesFreed: result.freedBytes,
                duration: Date().timeIntervalSince(startTime)
            )
        } catch {
            AppLogger.shared.error("Rule '\(rule.id)' failed: \(error)")
            return PolicyRuleResult(
                ruleId: rule.id,
                success: false,
                error: error.localizedDescription,
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    private func simulateRule(
        _ rule: PolicyRule,
        policy: Policy,
        startTime: Date
    ) async -> PolicyRuleResult {
        // Simulate by analyzing without cleaning
        do {
            let analyzer = AnalyzerService()
            let analyzerConfig = AnalyzerConfiguration(
                targetPath: "~",
                minSize: nil,
                verbose: false
            )
            let result = try await analyzer.analyze(with: analyzerConfig)

            // Find matching category
            var estimatedBytes: UInt64 = 0
            var estimatedItems = 0

            for category in result.categories {
                if categoryMatchesTarget(category, target: rule.target) {
                    estimatedBytes += category.size
                    estimatedItems += category.itemCount
                }
            }

            return PolicyRuleResult(
                ruleId: rule.id,
                success: true,
                itemsProcessed: estimatedItems,
                bytesFreed: estimatedBytes,
                error: config.dryRun ? "Dry run - no changes made" : nil,
                duration: Date().timeIntervalSince(startTime)
            )
        } catch {
            return PolicyRuleResult(
                ruleId: rule.id,
                success: false,
                error: "Simulation failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    // MARK: - Condition Checking

    private func checkConditions(_ conditions: PolicyCondition) async throws -> Bool {
        // Check weekdays only
        if let weekdaysOnly = conditions.weekdaysOnly, weekdaysOnly {
            let weekday = Calendar.current.component(.weekday, from: Date())
            if weekday == 1 || weekday == 7 {  // Sunday or Saturday
                return false
            }
        }

        // Check hour range
        if let hourRange = conditions.hourRange {
            let currentHour = Calendar.current.component(.hour, from: Date())
            if hourRange.start <= hourRange.end {
                if currentHour < hourRange.start || currentHour > hourRange.end {
                    return false
                }
            } else {
                // Range wraps around midnight
                if currentHour < hourRange.start && currentHour > hourRange.end {
                    return false
                }
            }
        }

        // Check disk space conditions
        if let minFreeSpaceStr = conditions.minFreeSpace,
           let minFreeSpace = PolicyValidator.parseSize(minFreeSpaceStr) {
            let freeSpace = try await getFreeDiskSpace()
            if freeSpace > minFreeSpace {
                return false  // Enough free space, don't need to run
            }
        }

        if let maxFreeSpaceStr = conditions.maxFreeSpace,
           let maxFreeSpace = PolicyValidator.parseSize(maxFreeSpaceStr) {
            let freeSpace = try await getFreeDiskSpace()
            if freeSpace > maxFreeSpace {
                return false  // Too much free space, condition not met
            }
        }

        return true
    }

    private func getFreeDiskSpace() async throws -> UInt64 {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        do {
            let values = try homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let freeSpace = values.volumeAvailableCapacityForImportantUsage {
                return UInt64(freeSpace)
            }
        } catch {
            AppLogger.shared.warning("Failed to get disk space: \(error)")
        }

        return 0
    }

    // MARK: - Mapping

    private func mapRuleToCleanerConfig(
        _ rule: PolicyRule,
        exclusions: [String]
    ) throws -> CleanerConfiguration {
        let level: CleanupLevel

        // Map target to cleanup level
        switch rule.target {
        case .systemCaches, .appCaches, .browserCaches:
            level = .normal
        case .developerCaches, .packageCaches:
            level = .deep
        case .all:
            level = .system
        default:
            level = .normal
        }

        // Map target to configuration options
        let includeSystemCaches = [.systemCaches, .all].contains(rule.target)
        let includeDeveloperCaches = [.developerCaches, .packageCaches, .all].contains(rule.target)
        let includeBrowserCaches = [.browserCaches, .all].contains(rule.target)
        let includeLogsCaches = [.systemLogs, .appLogs, .all].contains(rule.target)

        return CleanerConfiguration(
            cleanupLevel: level,
            dryRun: false,
            includeSystemCaches: includeSystemCaches,
            includeDeveloperCaches: includeDeveloperCaches,
            includeBrowserCaches: includeBrowserCaches,
            includeLogsCaches: includeLogsCaches
        )
    }

    private func categoryMatchesTarget(_ category: AnalysisCategory, target: PolicyTarget) -> Bool {
        let nameLower = category.name.lowercased()
        switch target {
        case .all:
            return true
        case .systemCaches:
            return nameLower.contains("cache") || nameLower.contains("system")
        case .browserCaches:
            return nameLower.contains("browser") ||
                   nameLower.contains("safari") ||
                   nameLower.contains("chrome")
        case .developerCaches:
            return nameLower.contains("xcode") ||
                   nameLower.contains("developer") ||
                   nameLower.contains("derived")
        case .systemLogs, .appLogs:
            return nameLower.contains("log")
        case .trash:
            return nameLower.contains("trash")
        default:
            return false
        }
    }

    // MARK: - Audit Logging

    private func logAuditEvent(_ event: AuditEvent) async {
        do {
            let logger = try AuditLogger.shared
            try logger.log(event)
        } catch {
            AppLogger.shared.warning("Failed to log audit event: \(error)")
        }
    }
}

// MARK: - Compliance Checking

extension PolicyEngine {
    /// Check compliance status for a policy
    public func checkCompliance(policyName: String) async throws -> PolicyComplianceReport {
        let policy = try store.get(policyName)
        return try await checkCompliance(policy: policy)
    }

    /// Check compliance status for a policy
    public func checkCompliance(policy: Policy) async throws -> PolicyComplianceReport {
        var ruleStatus: [String: ComplianceStatus] = [:]
        var issues: [String] = []
        var recommendations: [String] = []

        for rule in policy.enabledRules {
            // Check if conditions are met
            if let conditions = rule.conditions {
                let conditionsMet = try await checkConditions(conditions)
                if !conditionsMet {
                    ruleStatus[rule.id] = .compliant
                    continue
                }
            }

            // Analyze what would be cleaned
            do {
                let analyzer = AnalyzerService()
                let analyzerConfig = AnalyzerConfiguration(
                    targetPath: "~",
                    minSize: nil,
                    verbose: false
                )
                let result = try await analyzer.analyze(with: analyzerConfig)

                var matchingSize: UInt64 = 0
                for category in result.categories {
                    if categoryMatchesTarget(category, target: rule.target) {
                        matchingSize += category.size
                    }
                }

                // Determine compliance based on size
                if matchingSize > 1024 * 1024 * 100 {  // > 100MB
                    ruleStatus[rule.id] = .nonCompliant
                    issues.append("Rule '\(rule.id)' has \(ByteCountFormatter.string(fromByteCount: Int64(matchingSize), countStyle: .file)) to clean")
                    recommendations.append("Run cleanup for target '\(rule.target.rawValue)'")
                } else {
                    ruleStatus[rule.id] = .compliant
                }
            } catch {
                ruleStatus[rule.id] = .error
                issues.append("Rule '\(rule.id)' analysis failed: \(error.localizedDescription)")
            }
        }

        let overallStatus: ComplianceStatus
        if ruleStatus.values.contains(.error) {
            overallStatus = .error
        } else if ruleStatus.values.contains(.nonCompliant) {
            overallStatus = .nonCompliant
        } else {
            overallStatus = .compliant
        }

        return PolicyComplianceReport(
            policyName: policy.name,
            status: overallStatus,
            ruleStatus: ruleStatus,
            issues: issues,
            recommendations: recommendations
        )
    }
}

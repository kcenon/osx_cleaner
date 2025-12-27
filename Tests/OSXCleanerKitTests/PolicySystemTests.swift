import XCTest
@testable import OSXCleanerKit

final class PolicySystemTests: XCTestCase {

    // MARK: - Setup/Teardown

    var tempPolicyDirectory: URL!

    override func setUp() {
        super.setUp()
        tempPolicyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-policy-test-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempPolicyDirectory)
        super.tearDown()
    }

    // MARK: - PolicyVersion Tests

    func testPolicyVersionInitFromString() {
        let version = PolicyVersion(string: "1.0")
        XCTAssertNotNil(version)
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 0)
    }

    func testPolicyVersionInvalidString() {
        XCTAssertNil(PolicyVersion(string: "invalid"))
        XCTAssertNil(PolicyVersion(string: "1"))
        XCTAssertNil(PolicyVersion(string: "1.2.3"))
    }

    func testPolicyVersionComparison() {
        let v10 = PolicyVersion(major: 1, minor: 0)
        let v11 = PolicyVersion(major: 1, minor: 1)
        let v20 = PolicyVersion(major: 2, minor: 0)

        XCTAssertTrue(v10 < v11)
        XCTAssertTrue(v11 < v20)
        XCTAssertFalse(v20 < v10)
    }

    func testPolicyVersionCurrent() {
        let current = PolicyVersion.current
        XCTAssertEqual(current.major, 1)
        XCTAssertEqual(current.minor, 0)
        XCTAssertEqual(current.string, "1.0")
    }

    // MARK: - PolicyTarget Tests

    func testPolicyTargetAllCases() {
        let targets = PolicyTarget.allCases
        XCTAssertGreaterThan(targets.count, 10)
        XCTAssertTrue(targets.contains(.systemCaches))
        XCTAssertTrue(targets.contains(.developerCaches))
        XCTAssertTrue(targets.contains(.trash))
        XCTAssertTrue(targets.contains(.all))
    }

    func testPolicyTargetCodable() throws {
        let target = PolicyTarget.developerCaches
        let encoded = try JSONEncoder().encode(target)
        let decoded = try JSONDecoder().decode(PolicyTarget.self, from: encoded)
        XCTAssertEqual(target, decoded)
    }

    // MARK: - PolicyCondition Tests

    func testPolicyConditionInitialization() {
        let condition = PolicyCondition(
            olderThan: "7d",
            minFreeSpace: "10GB"
        )
        XCTAssertEqual(condition.olderThan, "7d")
        XCTAssertEqual(condition.minFreeSpace, "10GB")
        XCTAssertNil(condition.maxFreeSpace)
    }

    func testPolicyConditionCodable() throws {
        let condition = PolicyCondition(
            olderThan: "30d",
            minFreeSpace: "50GB",
            maxFileSize: "1GB"
        )
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(condition)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PolicyCondition.self, from: encoded)

        XCTAssertEqual(condition.olderThan, decoded.olderThan)
        XCTAssertEqual(condition.minFreeSpace, decoded.minFreeSpace)
        XCTAssertEqual(condition.maxFileSize, decoded.maxFileSize)
    }

    // MARK: - HourRange Tests

    func testHourRangeValidation() {
        let validRange = HourRange(start: 9, end: 17)
        XCTAssertTrue(validRange.isValid)

        let invalidRange1 = HourRange(start: 25, end: 10)
        XCTAssertFalse(invalidRange1.isValid)

        let invalidRange2 = HourRange(start: 10, end: -1)
        XCTAssertFalse(invalidRange2.isValid)
    }

    // MARK: - PolicyRule Tests

    func testPolicyRuleInitialization() {
        let rule = PolicyRule(
            id: "test-rule",
            target: .systemCaches,
            action: .clean,
            schedule: .weekly,
            conditions: PolicyCondition(olderThan: "7d"),
            enabled: true,
            description: "Test rule"
        )

        XCTAssertEqual(rule.id, "test-rule")
        XCTAssertEqual(rule.target, .systemCaches)
        XCTAssertEqual(rule.action, .clean)
        XCTAssertEqual(rule.schedule, .weekly)
        XCTAssertTrue(rule.enabled)
        XCTAssertEqual(rule.description, "Test rule")
    }

    func testPolicyRuleCodable() throws {
        let rule = PolicyRule(
            id: "cache-cleanup",
            target: .browserCaches,
            action: .clean,
            schedule: .daily
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(rule)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PolicyRule.self, from: encoded)

        XCTAssertEqual(rule.id, decoded.id)
        XCTAssertEqual(rule.target, decoded.target)
        XCTAssertEqual(rule.action, decoded.action)
        XCTAssertEqual(rule.schedule, decoded.schedule)
    }

    // MARK: - Policy Tests

    func testPolicyInitialization() {
        let policy = Policy(
            name: "test-policy",
            displayName: "Test Policy",
            description: "A test policy",
            rules: [
                PolicyRule(id: "rule-1", target: .systemCaches)
            ],
            exclusions: ["~/Documents/*"],
            notifications: true,
            priority: .high
        )

        XCTAssertEqual(policy.name, "test-policy")
        XCTAssertEqual(policy.displayName, "Test Policy")
        XCTAssertEqual(policy.rules.count, 1)
        XCTAssertEqual(policy.exclusions.count, 1)
        XCTAssertTrue(policy.notifications)
        XCTAssertEqual(policy.priority, .high)
        XCTAssertTrue(policy.enabled)
    }

    func testPolicyCodable() throws {
        let policy = Policy.personalDefault

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(policy)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Policy.self, from: encoded)

        XCTAssertEqual(policy.name, decoded.name)
        XCTAssertEqual(policy.rules.count, decoded.rules.count)
        XCTAssertEqual(policy.exclusions.count, decoded.exclusions.count)
    }

    func testPolicyEnabledRules() {
        var policy = Policy(name: "test")
        policy.rules = [
            PolicyRule(id: "rule-1", target: .systemCaches, enabled: true),
            PolicyRule(id: "rule-2", target: .browserCaches, enabled: false),
            PolicyRule(id: "rule-3", target: .trash, enabled: true)
        ]

        XCTAssertEqual(policy.enabledRules.count, 2)
        XCTAssertTrue(policy.enabledRules.contains { $0.id == "rule-1" })
        XCTAssertFalse(policy.enabledRules.contains { $0.id == "rule-2" })
        XCTAssertTrue(policy.enabledRules.contains { $0.id == "rule-3" })
    }

    func testPolicyRulesForSchedule() {
        var policy = Policy(name: "test")
        policy.rules = [
            PolicyRule(id: "daily-1", target: .systemCaches, schedule: .daily),
            PolicyRule(id: "weekly-1", target: .browserCaches, schedule: .weekly),
            PolicyRule(id: "daily-2", target: .trash, schedule: .daily)
        ]

        let dailyRules = policy.rules(for: .daily)
        XCTAssertEqual(dailyRules.count, 2)

        let weeklyRules = policy.rules(for: .weekly)
        XCTAssertEqual(weeklyRules.count, 1)

        let monthlyRules = policy.rules(for: .monthly)
        XCTAssertEqual(monthlyRules.count, 0)
    }

    func testSamplePolicies() {
        XCTAssertFalse(Policy.personalDefault.rules.isEmpty)
        XCTAssertFalse(Policy.developerStandard.rules.isEmpty)
        XCTAssertFalse(Policy.aggressiveCleanup.rules.isEmpty)
        XCTAssertFalse(Policy.enterpriseCompliance.rules.isEmpty)
    }

    // MARK: - PolicyValidator Tests

    func testValidatorValidPolicy() {
        let validator = PolicyValidator()
        let policy = Policy.personalDefault
        let result = validator.validate(policy)

        XCTAssertTrue(result.isValid, "Personal default policy should be valid")
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testValidatorEmptyPolicyName() {
        let validator = PolicyValidator()
        let policy = Policy(name: "")
        let result = validator.validate(policy)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(.emptyPolicyName))
    }

    func testValidatorInvalidPolicyName() {
        let validator = PolicyValidator()
        let policy = Policy(name: "Invalid Name With Spaces")
        let result = validator.validate(policy)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidPolicyName = error { return true }
            return false
        })
    }

    func testValidatorNoRules() {
        let validator = PolicyValidator()
        let policy = Policy(name: "test-policy", rules: [])
        let result = validator.validate(policy)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(.noRulesDefined))
    }

    func testValidatorDuplicateRuleIds() {
        let validator = PolicyValidator()
        let policy = Policy(
            name: "test-policy",
            rules: [
                PolicyRule(id: "same-id", target: .systemCaches),
                PolicyRule(id: "same-id", target: .browserCaches)
            ]
        )
        let result = validator.validate(policy)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { error in
            if case .duplicateRuleId("same-id") = error { return true }
            return false
        })
    }

    func testValidatorInvalidDurationFormat() {
        let validator = PolicyValidator()
        let rule = PolicyRule(
            id: "test-rule",
            target: .systemCaches,
            conditions: PolicyCondition(olderThan: "invalid")
        )
        let result = validator.validate(rule)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidDurationFormat = error { return true }
            return false
        })
    }

    func testValidatorValidDurationFormats() {
        XCTAssertNotNil(PolicyValidator.parseDuration("7d"))
        XCTAssertNotNil(PolicyValidator.parseDuration("2w"))
        XCTAssertNotNil(PolicyValidator.parseDuration("3m"))
        XCTAssertNotNil(PolicyValidator.parseDuration("1y"))

        XCTAssertEqual(PolicyValidator.parseDuration("1d"), 86400)
        XCTAssertEqual(PolicyValidator.parseDuration("1w"), 604800)
    }

    func testValidatorValidSizeFormats() {
        XCTAssertNotNil(PolicyValidator.parseSize("100KB"))
        XCTAssertNotNil(PolicyValidator.parseSize("50MB"))
        XCTAssertNotNil(PolicyValidator.parseSize("10GB"))
        XCTAssertNotNil(PolicyValidator.parseSize("1TB"))

        XCTAssertEqual(PolicyValidator.parseSize("1KB"), 1024)
        XCTAssertEqual(PolicyValidator.parseSize("1MB"), 1024 * 1024)
        XCTAssertEqual(PolicyValidator.parseSize("1GB"), 1024 * 1024 * 1024)
    }

    func testValidatorInvalidSizeFormat() {
        let validator = PolicyValidator()
        let rule = PolicyRule(
            id: "test-rule",
            target: .systemCaches,
            conditions: PolicyCondition(minFreeSpace: "invalid")
        )
        let result = validator.validate(rule)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidSizeFormat = error { return true }
            return false
        })
    }

    // MARK: - PolicyStore Tests

    func testPolicyStoreInitialization() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            validateOnLoad: true,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)
        XCTAssertNotNil(store)
    }

    func testPolicyStoreSaveAndGet() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        let policy = Policy(
            name: "test-save-policy",
            displayName: "Test Save Policy",
            rules: [PolicyRule(id: "rule-1", target: .systemCaches)]
        )

        try store.save(policy)

        let retrieved = try store.get("test-save-policy")
        XCTAssertEqual(retrieved.name, policy.name)
        XCTAssertEqual(retrieved.displayName, policy.displayName)
        XCTAssertEqual(retrieved.rules.count, 1)
    }

    func testPolicyStoreList() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        let policy1 = Policy(
            name: "policy-1",
            rules: [PolicyRule(id: "rule-1", target: .systemCaches)]
        )
        let policy2 = Policy(
            name: "policy-2",
            rules: [PolicyRule(id: "rule-2", target: .browserCaches)]
        )

        try store.save(policy1)
        try store.save(policy2)

        let policies = try store.list()
        XCTAssertEqual(policies.count, 2)
    }

    func testPolicyStoreDelete() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        let policy = Policy(
            name: "delete-me",
            rules: [PolicyRule(id: "rule-1", target: .systemCaches)]
        )

        try store.save(policy)
        XCTAssertTrue(store.exists("delete-me"))

        try store.delete("delete-me")
        XCTAssertFalse(store.exists("delete-me"))
    }

    func testPolicyStoreNotFound() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        XCTAssertThrowsError(try store.get("non-existent")) { error in
            guard case PolicyStoreError.policyNotFound = error else {
                XCTFail("Expected policyNotFound error")
                return
            }
        }
    }

    func testPolicyStoreDuplicateSaveWithoutOverwrite() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        let policy = Policy(
            name: "duplicate-policy",
            rules: [PolicyRule(id: "rule-1", target: .systemCaches)]
        )

        try store.save(policy)

        XCTAssertThrowsError(try store.save(policy, overwrite: false)) { error in
            guard case PolicyStoreError.policyAlreadyExists = error else {
                XCTFail("Expected policyAlreadyExists error")
                return
            }
        }
    }

    func testPolicyStoreSaveWithOverwrite() throws {
        let config = PolicyStoreConfig(
            policyDirectory: tempPolicyDirectory,
            createSamplePolicies: false
        )
        let store = try PolicyStore(config: config)

        var policy = Policy(
            name: "overwrite-policy",
            displayName: "Original Name",
            rules: [PolicyRule(id: "rule-1", target: .systemCaches)]
        )

        try store.save(policy)

        policy.displayName = "Updated Name"
        try store.save(policy, overwrite: true)

        let retrieved = try store.get("overwrite-policy")
        XCTAssertEqual(retrieved.displayName, "Updated Name")
    }

    // MARK: - PolicyRuleResult Tests

    func testPolicyRuleResultSuccess() {
        let result = PolicyRuleResult(
            ruleId: "test-rule",
            success: true,
            itemsProcessed: 10,
            bytesFreed: 1024 * 1024,
            duration: 1.5
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.itemsProcessed, 10)
        XCTAssertEqual(result.bytesFreed, 1024 * 1024)
        XCTAssertNil(result.error)
    }

    func testPolicyRuleResultFailure() {
        let result = PolicyRuleResult(
            ruleId: "test-rule",
            success: false,
            error: "Permission denied"
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "Permission denied")
    }

    // MARK: - PolicyExecutionResult Tests

    func testPolicyExecutionResultTotals() {
        let ruleResults = [
            PolicyRuleResult(ruleId: "rule-1", success: true, itemsProcessed: 5, bytesFreed: 1000, duration: 1.0),
            PolicyRuleResult(ruleId: "rule-2", success: true, itemsProcessed: 10, bytesFreed: 2000, duration: 2.0),
            PolicyRuleResult(ruleId: "rule-3", success: false, error: "Failed")
        ]

        let executionResult = PolicyExecutionResult(
            policyName: "test-policy",
            success: false,
            ruleResults: ruleResults
        )

        XCTAssertEqual(executionResult.totalItemsProcessed, 15)
        XCTAssertEqual(executionResult.totalBytesFreed, 3000)
        XCTAssertEqual(executionResult.totalDuration, 3.0)
        XCTAssertEqual(executionResult.successfulRules, 2)
        XCTAssertEqual(executionResult.failedRules, 1)
    }

    // MARK: - PolicyPriority Tests

    func testPolicyPriorityComparison() {
        XCTAssertTrue(PolicyPriority.low < PolicyPriority.normal)
        XCTAssertTrue(PolicyPriority.normal < PolicyPriority.high)
        XCTAssertTrue(PolicyPriority.high < PolicyPriority.critical)
    }

    // MARK: - ComplianceStatus Tests

    func testComplianceStatusCodable() throws {
        for status in [ComplianceStatus.compliant, .nonCompliant, .pending, .error] {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ComplianceStatus.self, from: encoded)
            XCTAssertEqual(status, decoded)
        }
    }
}

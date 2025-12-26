import XCTest
@testable import OSXCleanerKit

final class TeamConfigServiceTests: XCTestCase {

    // MARK: - Model Tests

    func testTeamConfigDefaults() {
        let config = TeamConfig(team: "Test Team")

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.team, "Test Team")
        XCTAssertEqual(config.policies.cleanupLevel, "normal")
        XCTAssertEqual(config.policies.schedule, "weekly")
        XCTAssertTrue(config.policies.allowOverride)
        XCTAssertEqual(config.policies.maxDiskUsage, 90)
        XCTAssertFalse(config.policies.enforceDryRun)
        XCTAssertTrue(config.exclusions.isEmpty)
        XCTAssertEqual(config.notifications.threshold, 85)
        XCTAssertFalse(config.notifications.autoCleanup)
        XCTAssertNil(config.sync)
    }

    func testTeamPoliciesDefaults() {
        let policies = TeamPolicies.default

        XCTAssertEqual(policies.cleanupLevel, "normal")
        XCTAssertEqual(policies.schedule, "weekly")
        XCTAssertTrue(policies.allowOverride)
        XCTAssertEqual(policies.maxDiskUsage, 90)
        XCTAssertFalse(policies.enforceDryRun)
    }

    func testXcodeTargetConfigDefaults() {
        let config = XcodeTargetConfig.default

        XCTAssertTrue(config.derivedData)
        XCTAssertFalse(config.deviceSupport)
        XCTAssertEqual(config.simulators, "unavailable")
        XCTAssertFalse(config.archives)
    }

    func testDockerTargetConfigDefaults() {
        let config = DockerTargetConfig.default

        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.keepRunning)
        XCTAssertTrue(config.pruneImages)
        XCTAssertFalse(config.pruneBuildCache)
    }

    func testTeamNotificationConfigDefaults() {
        let config = TeamNotificationConfig.default

        XCTAssertEqual(config.threshold, 85)
        XCTAssertFalse(config.autoCleanup)
        XCTAssertTrue(config.enabled)
    }

    func testTeamSyncConfigDefaults() {
        let config = TeamSyncConfig.default

        XCTAssertNil(config.remoteURL)
        XCTAssertEqual(config.intervalSeconds, 3600)
        XCTAssertTrue(config.syncOnStartup)
    }

    // MARK: - Validation Tests

    func testValidConfigPassesValidation() throws {
        let config = TeamConfig.sample
        XCTAssertNoThrow(try config.validate())
    }

    func testEmptyTeamNameFailsValidation() {
        let config = TeamConfig(
            team: "   ",
            policies: .default
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard let configError = error as? TeamConfigError else {
                XCTFail("Expected TeamConfigError")
                return
            }
            if case .invalidField(let field, _) = configError {
                XCTAssertEqual(field, "team")
            } else {
                XCTFail("Expected invalidField error for team")
            }
        }
    }

    func testInvalidCleanupLevelFailsValidation() {
        let config = TeamConfig(
            team: "Test",
            policies: TeamPolicies(
                cleanupLevel: "invalid_level",
                schedule: "weekly"
            )
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard let configError = error as? TeamConfigError else {
                XCTFail("Expected TeamConfigError")
                return
            }
            if case .invalidField(let field, _) = configError {
                XCTAssertEqual(field, "policies.cleanup_level")
            } else {
                XCTFail("Expected invalidField error for cleanup_level")
            }
        }
    }

    func testInvalidScheduleFailsValidation() {
        let config = TeamConfig(
            team: "Test",
            policies: TeamPolicies(
                cleanupLevel: "normal",
                schedule: "invalid_schedule"
            )
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard let configError = error as? TeamConfigError else {
                XCTFail("Expected TeamConfigError")
                return
            }
            if case .invalidField(let field, _) = configError {
                XCTAssertEqual(field, "policies.schedule")
            } else {
                XCTFail("Expected invalidField error for schedule")
            }
        }
    }

    func testInvalidThresholdFailsValidation() {
        let config = TeamConfig(
            team: "Test",
            notifications: TeamNotificationConfig(threshold: 150)
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard let configError = error as? TeamConfigError else {
                XCTFail("Expected TeamConfigError")
                return
            }
            if case .invalidField(let field, _) = configError {
                XCTAssertEqual(field, "notifications.threshold")
            } else {
                XCTFail("Expected invalidField error for threshold")
            }
        }
    }

    func testInvalidSimulatorModeFailsValidation() {
        let config = TeamConfig(
            team: "Test",
            targets: TeamTargetConfigs(
                xcode: XcodeTargetConfig(
                    derivedData: true,
                    deviceSupport: false,
                    simulators: "invalid_mode",
                    archives: false
                )
            )
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard let configError = error as? TeamConfigError else {
                XCTFail("Expected TeamConfigError")
                return
            }
            if case .invalidField(let field, _) = configError {
                XCTAssertEqual(field, "targets.xcode.simulators")
            } else {
                XCTFail("Expected invalidField error for simulators")
            }
        }
    }

    // MARK: - Codable Tests

    func testTeamConfigJSONEncodeDecode() throws {
        let original = TeamConfig.sample

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TeamConfig.self, from: jsonData)

        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.team, original.team)
        XCTAssertEqual(decoded.policies.cleanupLevel, original.policies.cleanupLevel)
        XCTAssertEqual(decoded.policies.schedule, original.policies.schedule)
        XCTAssertEqual(decoded.exclusions, original.exclusions)
        XCTAssertEqual(decoded.notifications.threshold, original.notifications.threshold)
    }

    func testTeamConfigYAMLEncodeDecode() throws {
        let service = TeamConfigService()
        let yamlString = try service.generateSampleYAML()

        XCTAssertFalse(yamlString.isEmpty)
        XCTAssertTrue(yamlString.contains("team:"))
        XCTAssertTrue(yamlString.contains("version:"))
        XCTAssertTrue(yamlString.contains("policies:"))
    }

    // MARK: - Service Tests

    func testServiceSingleton() {
        let service1 = TeamConfigService.shared
        let service2 = TeamConfigService.shared

        XCTAssertTrue(service1 === service2)
    }

    func testGetStatusWithNoConfig() {
        let service = TeamConfigService()
        let status = service.getStatus()

        XCTAssertFalse(status.isActive)
        XCTAssertNil(status.teamName)
        XCTAssertNil(status.version)
        XCTAssertEqual(status.exclusionsCount, 0)
    }

    func testCreateCleanerConfigurationLight() {
        let teamConfig = TeamConfig(
            team: "Test",
            policies: TeamPolicies(cleanupLevel: "light", enforceDryRun: true)
        )

        let service = TeamConfigService()
        let cleanerConfig = service.createCleanerConfiguration(from: teamConfig)

        XCTAssertEqual(cleanerConfig.cleanupLevel, .light)
        XCTAssertTrue(cleanerConfig.dryRun)
    }

    func testCreateCleanerConfigurationDeep() {
        let teamConfig = TeamConfig(
            team: "Test",
            policies: TeamPolicies(cleanupLevel: "deep", enforceDryRun: false)
        )

        let service = TeamConfigService()
        let cleanerConfig = service.createCleanerConfiguration(from: teamConfig)

        XCTAssertEqual(cleanerConfig.cleanupLevel, .deep)
        XCTAssertFalse(cleanerConfig.dryRun)
    }

    func testCreateCleanerConfigurationSystem() {
        let teamConfig = TeamConfig(
            team: "Test",
            policies: TeamPolicies(cleanupLevel: "system")
        )

        let service = TeamConfigService()
        let cleanerConfig = service.createCleanerConfiguration(from: teamConfig)

        XCTAssertEqual(cleanerConfig.cleanupLevel, .system)
    }

    func testApplyExclusionsEmpty() {
        let teamConfig = TeamConfig(
            team: "Test",
            exclusions: []
        )

        let service = TeamConfigService()
        let paths = ["/path/one", "/path/two"]
        let filtered = service.applyExclusions(to: paths, using: teamConfig)

        XCTAssertEqual(filtered, paths)
    }

    func testApplyExclusionsExactMatch() {
        let teamConfig = TeamConfig(
            team: "Test",
            exclusions: ["/path/one"]
        )

        let service = TeamConfigService()
        let paths = ["/path/one", "/path/two"]
        let filtered = service.applyExclusions(to: paths, using: teamConfig)

        XCTAssertEqual(filtered, ["/path/two"])
    }

    // MARK: - Error Tests

    func testTeamConfigErrorDescriptions() {
        let errors: [TeamConfigError] = [
            .fileNotFound("/test/path"),
            .parseError("Invalid YAML"),
            .unsupportedVersion("2.0"),
            .invalidField("team", reason: "Cannot be empty"),
            .networkError("Connection refused"),
            .syncFailed("Timeout")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testTeamConfigErrorEquality() {
        let error1 = TeamConfigError.fileNotFound("/path")
        let error2 = TeamConfigError.fileNotFound("/path")
        let error3 = TeamConfigError.fileNotFound("/other")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - Sample Configuration Tests

    func testSampleConfigurationIsValid() throws {
        let sample = TeamConfig.sample
        XCTAssertNoThrow(try sample.validate())

        XCTAssertEqual(sample.version, "1.0")
        XCTAssertEqual(sample.team, "iOS Development")
        XCTAssertFalse(sample.exclusions.isEmpty)
        XCTAssertNotNil(sample.targets.xcode)
        XCTAssertNotNil(sample.targets.docker)
        XCTAssertNotNil(sample.sync)
    }
}

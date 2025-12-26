import XCTest
@testable import OSXCleanerKit

final class DiskMonitoringServiceTests: XCTestCase {
    var service: DiskMonitoringService!

    override func setUp() {
        super.setUp()
        service = DiskMonitoringService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - DiskThreshold Tests

    func testDiskThresholdValues() {
        XCTAssertEqual(DiskThreshold.warning.rawValue, 85)
        XCTAssertEqual(DiskThreshold.critical.rawValue, 90)
        XCTAssertEqual(DiskThreshold.emergency.rawValue, 95)
    }

    func testDiskThresholdComparable() {
        XCTAssertLessThan(DiskThreshold.warning, DiskThreshold.critical)
        XCTAssertLessThan(DiskThreshold.critical, DiskThreshold.emergency)
    }

    func testDiskThresholdMessages() {
        XCTAssertFalse(DiskThreshold.warning.message.isEmpty)
        XCTAssertFalse(DiskThreshold.critical.message.isEmpty)
        XCTAssertFalse(DiskThreshold.emergency.message.isEmpty)
    }

    func testDiskThresholdRecommendations() {
        XCTAssertFalse(DiskThreshold.warning.recommendation.isEmpty)
        XCTAssertFalse(DiskThreshold.critical.recommendation.isEmpty)
        XCTAssertFalse(DiskThreshold.emergency.recommendation.isEmpty)
    }

    // MARK: - MonitoringConfig Tests

    func testMonitoringConfigDefaults() {
        let config = MonitoringConfig()

        XCTAssertFalse(config.autoCleanupEnabled)
        XCTAssertEqual(config.autoCleanupLevel, "light")
        XCTAssertEqual(config.checkIntervalSeconds, 3600)
        XCTAssertTrue(config.notificationsEnabled)
        XCTAssertNil(config.warningThreshold)
        XCTAssertNil(config.criticalThreshold)
        XCTAssertNil(config.emergencyThreshold)
    }

    func testMonitoringConfigCustomValues() {
        let config = MonitoringConfig(
            autoCleanupEnabled: true,
            autoCleanupLevel: "normal",
            checkIntervalSeconds: 1800,
            notificationsEnabled: false,
            warningThreshold: 80,
            criticalThreshold: 88,
            emergencyThreshold: 93
        )

        XCTAssertTrue(config.autoCleanupEnabled)
        XCTAssertEqual(config.autoCleanupLevel, "normal")
        XCTAssertEqual(config.checkIntervalSeconds, 1800)
        XCTAssertFalse(config.notificationsEnabled)
        XCTAssertEqual(config.warningThreshold, 80)
        XCTAssertEqual(config.criticalThreshold, 88)
        XCTAssertEqual(config.emergencyThreshold, 93)
    }

    func testMonitoringConfigEffectiveThresholds() {
        let configWithDefaults = MonitoringConfig()
        XCTAssertEqual(configWithDefaults.effectiveWarningThreshold, 85)
        XCTAssertEqual(configWithDefaults.effectiveCriticalThreshold, 90)
        XCTAssertEqual(configWithDefaults.effectiveEmergencyThreshold, 95)

        let configWithCustom = MonitoringConfig(
            warningThreshold: 75,
            criticalThreshold: 85,
            emergencyThreshold: 92
        )
        XCTAssertEqual(configWithCustom.effectiveWarningThreshold, 75)
        XCTAssertEqual(configWithCustom.effectiveCriticalThreshold, 85)
        XCTAssertEqual(configWithCustom.effectiveEmergencyThreshold, 92)
    }

    func testMonitoringConfigCodable() throws {
        let original = MonitoringConfig(
            autoCleanupEnabled: true,
            autoCleanupLevel: "deep",
            checkIntervalSeconds: 7200,
            notificationsEnabled: true,
            warningThreshold: 80,
            criticalThreshold: 88,
            emergencyThreshold: 94
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MonitoringConfig.self, from: data)

        XCTAssertEqual(decoded.autoCleanupEnabled, original.autoCleanupEnabled)
        XCTAssertEqual(decoded.autoCleanupLevel, original.autoCleanupLevel)
        XCTAssertEqual(decoded.checkIntervalSeconds, original.checkIntervalSeconds)
        XCTAssertEqual(decoded.warningThreshold, original.warningThreshold)
    }

    // MARK: - DiskSpaceInfo Tests

    func testDiskSpaceInfoFormatting() {
        let info = DiskSpaceInfo(
            totalSpace: 500 * 1024 * 1024 * 1024,  // 500 GB
            availableSpace: 100 * 1024 * 1024 * 1024,  // 100 GB
            usedSpace: 400 * 1024 * 1024 * 1024,  // 400 GB
            usagePercent: 80.0,
            volumePath: "/"
        )

        XCTAssertFalse(info.formattedTotal.isEmpty)
        XCTAssertFalse(info.formattedAvailable.isEmpty)
        XCTAssertFalse(info.formattedUsed.isEmpty)
        XCTAssertEqual(info.usagePercent, 80.0)
        XCTAssertEqual(info.volumePath, "/")
    }

    // MARK: - MonitoringStatus Tests

    func testMonitoringStatusDisabled() {
        let status = MonitoringStatus(isEnabled: false)

        XCTAssertFalse(status.isEnabled)
        XCTAssertNil(status.lastCheckTime)
        XCTAssertNil(status.lastUsagePercent)
        XCTAssertNil(status.config)
        XCTAssertNil(status.plistPath)
    }

    func testMonitoringStatusEnabled() {
        let config = MonitoringConfig()
        let status = MonitoringStatus(
            isEnabled: true,
            lastCheckTime: Date(),
            lastUsagePercent: 75.5,
            config: config,
            plistPath: "~/Library/LaunchAgents/com.osxcleaner.monitor.plist"
        )

        XCTAssertTrue(status.isEnabled)
        XCTAssertNotNil(status.lastCheckTime)
        XCTAssertEqual(status.lastUsagePercent, 75.5)
        XCTAssertNotNil(status.config)
        XCTAssertNotNil(status.plistPath)
    }

    func testMonitoringStatusCodable() throws {
        let status = MonitoringStatus(
            isEnabled: true,
            lastCheckTime: Date(),
            lastUsagePercent: 82.3,
            config: MonitoringConfig(),
            plistPath: "/path/to/plist"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MonitoringStatus.self, from: data)

        XCTAssertEqual(decoded.isEnabled, status.isEnabled)
        XCTAssertEqual(decoded.lastUsagePercent, status.lastUsagePercent)
    }

    // MARK: - DiskMonitoringService Tests

    func testServiceCreation() {
        let service = DiskMonitoringService()
        XCTAssertNotNil(service)
    }

    func testSharedInstance() {
        let shared1 = DiskMonitoringService.shared
        let shared2 = DiskMonitoringService.shared
        XCTAssertTrue(shared1 === shared2)
    }

    func testGetDiskSpace() throws {
        let diskInfo = try service.getDiskSpace()

        XCTAssertGreaterThan(diskInfo.totalSpace, 0)
        XCTAssertGreaterThan(diskInfo.availableSpace, 0)
        XCTAssertGreaterThan(diskInfo.usedSpace, 0)
        XCTAssertGreaterThan(diskInfo.usagePercent, 0)
        XCTAssertLessThanOrEqual(diskInfo.usagePercent, 100)
        XCTAssertEqual(diskInfo.volumePath, "/")
    }

    func testGetDiskSpaceCalculation() throws {
        let diskInfo = try service.getDiskSpace()

        // Verify that used + available approximately equals total
        let calculatedTotal = diskInfo.usedSpace + diskInfo.availableSpace
        let tolerance = diskInfo.totalSpace / 100  // 1% tolerance
        XCTAssertLessThan(abs(Int64(calculatedTotal) - Int64(diskInfo.totalSpace)), Int64(tolerance))
    }

    func testGetStatus() {
        let status = service.getStatus()

        // Status should be valid (monitoring may or may not be enabled)
        XCTAssertNotNil(status)
        // If not enabled, config and plistPath should be nil
        if !status.isEnabled {
            XCTAssertNil(status.plistPath)
        }
    }

    func testCheckDiskUsageNoThreshold() async throws {
        // Use high thresholds that won't be triggered
        let config = MonitoringConfig(
            notificationsEnabled: false,
            warningThreshold: 99,
            criticalThreshold: 99,
            emergencyThreshold: 99
        )

        let (diskInfo, threshold) = try await service.checkDiskUsage(config: config)

        XCTAssertNotNil(diskInfo)
        XCTAssertGreaterThan(diskInfo.usagePercent, 0)
        // With 99% thresholds, most systems won't exceed
        if diskInfo.usagePercent < 99 {
            XCTAssertNil(threshold)
        }
    }

    func testCheckDiskUsageWithLowThreshold() async throws {
        // Use very low thresholds that will definitely trigger
        let config = MonitoringConfig(
            notificationsEnabled: false,  // Disable notifications for test
            warningThreshold: 1,
            criticalThreshold: 2,
            emergencyThreshold: 3
        )

        let (diskInfo, threshold) = try await service.checkDiskUsage(config: config)

        XCTAssertNotNil(diskInfo)
        XCTAssertGreaterThan(diskInfo.usagePercent, 3)  // Should exceed all thresholds
        XCTAssertNotNil(threshold)
        XCTAssertEqual(threshold, .emergency)  // Should be highest threshold
    }

    // MARK: - MonitoringError Tests

    func testMonitoringErrorDescriptions() {
        let diskSpaceError = MonitoringError.failedToGetDiskSpace
        XCTAssertFalse(diskSpaceError.errorDescription?.isEmpty ?? true)

        let launchctlError = MonitoringError.launchctlFailed("load")
        XCTAssertTrue(launchctlError.errorDescription?.contains("launchctl") ?? false)

        let configError = MonitoringError.configurationError("test error")
        XCTAssertTrue(configError.errorDescription?.contains("test error") ?? false)
    }
}

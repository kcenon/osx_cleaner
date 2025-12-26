// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class SchedulerServiceTests: XCTestCase {
    var service: SchedulerService!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()

        // Create a test directory to simulate LaunchAgents
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-test-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)

        // Use custom service with test bundle identifier
        service = SchedulerService(
            fileManager: .default,
            bundleIdentifier: "com.osxcleaner.test"
        )
    }

    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        service = nil
        testDirectory = nil
        super.tearDown()
    }

    // MARK: - ScheduleFrequency Tests

    func testScheduleFrequencyRawValues() {
        XCTAssertEqual(ScheduleFrequency.daily.rawValue, "daily")
        XCTAssertEqual(ScheduleFrequency.weekly.rawValue, "weekly")
        XCTAssertEqual(ScheduleFrequency.monthly.rawValue, "monthly")
    }

    func testScheduleFrequencyAllCases() {
        XCTAssertEqual(ScheduleFrequency.allCases.count, 3)
        XCTAssertTrue(ScheduleFrequency.allCases.contains(.daily))
        XCTAssertTrue(ScheduleFrequency.allCases.contains(.weekly))
        XCTAssertTrue(ScheduleFrequency.allCases.contains(.monthly))
    }

    func testScheduleFrequencyCodable() throws {
        let original = ScheduleFrequency.weekly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduleFrequency.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - ScheduleConfig Tests

    func testScheduleConfigCreation() {
        let config = ScheduleConfig(
            frequency: .daily,
            level: .light,
            hour: 3,
            minute: 0
        )

        XCTAssertEqual(config.frequency, .daily)
        XCTAssertEqual(config.level, .light)
        XCTAssertEqual(config.hour, 3)
        XCTAssertEqual(config.minute, 0)
        XCTAssertNil(config.weekday)
        XCTAssertNil(config.day)
    }

    func testScheduleConfigWeekly() {
        let config = ScheduleConfig(
            frequency: .weekly,
            level: .normal,
            hour: 4,
            minute: 30,
            weekday: 1  // Monday
        )

        XCTAssertEqual(config.frequency, .weekly)
        XCTAssertEqual(config.level, .normal)
        XCTAssertEqual(config.weekday, 1)
    }

    func testScheduleConfigMonthly() {
        let config = ScheduleConfig(
            frequency: .monthly,
            level: .deep,
            hour: 2,
            minute: 15,
            day: 15
        )

        XCTAssertEqual(config.frequency, .monthly)
        XCTAssertEqual(config.level, .deep)
        XCTAssertEqual(config.day, 15)
    }

    func testScheduleConfigPlistName() {
        let dailyConfig = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        XCTAssertEqual(dailyConfig.plistName, "com.osxcleaner.daily.plist")

        let weeklyConfig = ScheduleConfig(frequency: .weekly, level: .normal, hour: 3, minute: 0)
        XCTAssertEqual(weeklyConfig.plistName, "com.osxcleaner.weekly.plist")

        let monthlyConfig = ScheduleConfig(frequency: .monthly, level: .deep, hour: 3, minute: 0)
        XCTAssertEqual(monthlyConfig.plistName, "com.osxcleaner.monthly.plist")
    }

    func testScheduleConfigLabel() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        XCTAssertEqual(config.label, "com.osxcleaner.daily")
    }

    func testScheduleConfigTimeDescription() {
        let dailyConfig = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        XCTAssertEqual(dailyConfig.timeDescription, "03:00")

        let weeklyConfig = ScheduleConfig(frequency: .weekly, level: .normal, hour: 14, minute: 30, weekday: 1)
        XCTAssertEqual(weeklyConfig.timeDescription, "14:30 on Monday")

        let monthlyConfig = ScheduleConfig(frequency: .monthly, level: .deep, hour: 22, minute: 45, day: 15)
        XCTAssertEqual(monthlyConfig.timeDescription, "22:45 on day 15")
    }

    func testScheduleConfigCodable() throws {
        let original = ScheduleConfig(
            frequency: .weekly,
            level: .normal,
            hour: 5,
            minute: 30,
            weekday: 3
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScheduleConfig.self, from: data)

        XCTAssertEqual(decoded.frequency, original.frequency)
        XCTAssertEqual(decoded.level, original.level)
        XCTAssertEqual(decoded.hour, original.hour)
        XCTAssertEqual(decoded.minute, original.minute)
        XCTAssertEqual(decoded.weekday, original.weekday)
    }

    // MARK: - ScheduleInfo Tests

    func testScheduleInfoCreation() {
        let info = ScheduleInfo(
            frequency: "daily",
            level: "light",
            enabled: true,
            timeDescription: "03:00",
            plistPath: "/path/to/plist"
        )

        XCTAssertEqual(info.frequency, "daily")
        XCTAssertEqual(info.level, "light")
        XCTAssertTrue(info.enabled)
        XCTAssertEqual(info.timeDescription, "03:00")
        XCTAssertEqual(info.plistPath, "/path/to/plist")
    }

    func testScheduleInfoCodable() throws {
        let original = ScheduleInfo(
            frequency: "weekly",
            level: "normal",
            enabled: false,
            timeDescription: "04:00 on Monday",
            plistPath: "/test/path"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScheduleInfo.self, from: data)

        XCTAssertEqual(decoded.frequency, original.frequency)
        XCTAssertEqual(decoded.level, original.level)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.timeDescription, original.timeDescription)
    }

    // MARK: - ScheduleError Tests

    func testScheduleErrorInvalidHour() {
        let error = ScheduleError.invalidHour(25)
        XCTAssertTrue(error.errorDescription?.contains("25") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("0-23") ?? false)
    }

    func testScheduleErrorInvalidMinute() {
        let error = ScheduleError.invalidMinute(60)
        XCTAssertTrue(error.errorDescription?.contains("60") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("0-59") ?? false)
    }

    func testScheduleErrorInvalidWeekday() {
        let error = ScheduleError.invalidWeekday(7)
        XCTAssertTrue(error.errorDescription?.contains("7") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("0-6") ?? false)
    }

    func testScheduleErrorInvalidDay() {
        let error = ScheduleError.invalidDay(32)
        XCTAssertTrue(error.errorDescription?.contains("32") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("1-31") ?? false)
    }

    func testScheduleErrorScheduleNotFound() {
        let error = ScheduleError.scheduleNotFound("daily")
        XCTAssertTrue(error.errorDescription?.contains("daily") ?? false)
    }

    func testScheduleErrorLaunchctlFailed() {
        let error = ScheduleError.launchctlFailed("load")
        XCTAssertTrue(error.errorDescription?.contains("launchctl") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("load") ?? false)
    }

    // MARK: - Validation Tests

    func testValidateConfigValidDaily() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        XCTAssertNoThrow(try service.validateConfig(config))
    }

    func testValidateConfigValidWeekly() {
        let config = ScheduleConfig(frequency: .weekly, level: .normal, hour: 12, minute: 30, weekday: 3)
        XCTAssertNoThrow(try service.validateConfig(config))
    }

    func testValidateConfigValidMonthly() {
        let config = ScheduleConfig(frequency: .monthly, level: .deep, hour: 23, minute: 59, day: 15)
        XCTAssertNoThrow(try service.validateConfig(config))
    }

    func testValidateConfigInvalidHour() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 24, minute: 0)
        XCTAssertThrowsError(try service.validateConfig(config)) { error in
            guard case ScheduleError.invalidHour(24) = error else {
                XCTFail("Expected invalidHour error")
                return
            }
        }
    }

    func testValidateConfigInvalidMinute() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 60)
        XCTAssertThrowsError(try service.validateConfig(config)) { error in
            guard case ScheduleError.invalidMinute(60) = error else {
                XCTFail("Expected invalidMinute error")
                return
            }
        }
    }

    func testValidateConfigInvalidWeekday() {
        let config = ScheduleConfig(frequency: .weekly, level: .normal, hour: 3, minute: 0, weekday: 7)
        XCTAssertThrowsError(try service.validateConfig(config)) { error in
            guard case ScheduleError.invalidWeekday(7) = error else {
                XCTFail("Expected invalidWeekday error")
                return
            }
        }
    }

    func testValidateConfigInvalidDay() {
        let config = ScheduleConfig(frequency: .monthly, level: .deep, hour: 3, minute: 0, day: 32)
        XCTAssertThrowsError(try service.validateConfig(config)) { error in
            guard case ScheduleError.invalidDay(32) = error else {
                XCTFail("Expected invalidDay error")
                return
            }
        }
    }

    // MARK: - Plist Generation Tests

    func testGeneratePlistContentDaily() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        let content = service.generatePlistContent(for: config)

        XCTAssertTrue(content.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(content.contains("<key>Label</key>"))
        XCTAssertTrue(content.contains("com.osxcleaner.test.daily"))
        XCTAssertTrue(content.contains("<key>Hour</key>"))
        XCTAssertTrue(content.contains("<integer>3</integer>"))
        XCTAssertTrue(content.contains("<key>Minute</key>"))
        XCTAssertTrue(content.contains("<integer>0</integer>"))
        XCTAssertTrue(content.contains("--level"))
        XCTAssertTrue(content.contains("light"))
        XCTAssertTrue(content.contains("--non-interactive"))
    }

    func testGeneratePlistContentWeekly() {
        let config = ScheduleConfig(frequency: .weekly, level: .normal, hour: 4, minute: 30, weekday: 1)
        let content = service.generatePlistContent(for: config)

        XCTAssertTrue(content.contains("com.osxcleaner.test.weekly"))
        XCTAssertTrue(content.contains("<key>Weekday</key>"))
        XCTAssertTrue(content.contains("<integer>1</integer>"))
        XCTAssertTrue(content.contains("normal"))
    }

    func testGeneratePlistContentMonthly() {
        let config = ScheduleConfig(frequency: .monthly, level: .deep, hour: 2, minute: 15, day: 15)
        let content = service.generatePlistContent(for: config)

        XCTAssertTrue(content.contains("com.osxcleaner.test.monthly"))
        XCTAssertTrue(content.contains("<key>Day</key>"))
        XCTAssertTrue(content.contains("<integer>15</integer>"))
        XCTAssertTrue(content.contains("deep"))
    }

    func testGeneratePlistContainsRequiredKeys() {
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        let content = service.generatePlistContent(for: config)

        // Required plist keys
        XCTAssertTrue(content.contains("<key>ProgramArguments</key>"))
        XCTAssertTrue(content.contains("<key>StartCalendarInterval</key>"))
        XCTAssertTrue(content.contains("<key>StandardOutPath</key>"))
        XCTAssertTrue(content.contains("<key>StandardErrorPath</key>"))
        XCTAssertTrue(content.contains("<key>RunAtLoad</key>"))
        XCTAssertTrue(content.contains("<false/>"))  // RunAtLoad should be false
    }

    // MARK: - Service Tests

    func testServiceCreation() {
        let service = SchedulerService()
        XCTAssertNotNil(service)
    }

    func testServiceWithCustomBundleIdentifier() {
        let service = SchedulerService(bundleIdentifier: "com.test.app")
        let config = ScheduleConfig(frequency: .daily, level: .light, hour: 3, minute: 0)
        let content = service.generatePlistContent(for: config)

        XCTAssertTrue(content.contains("com.test.app.daily"))
    }

    func testLaunchAgentsPath() {
        let expectedSuffix = "Library/LaunchAgents"
        XCTAssertTrue(service.launchAgentsPath.path.hasSuffix(expectedSuffix))
    }

    func testListSchedulesEmpty() {
        // With test bundle identifier, no schedules should exist
        let schedules = service.listSchedules()
        XCTAssertTrue(schedules.isEmpty)
    }

    // MARK: - CleanupLevel Extension Tests

    func testCleanupLevelStringValue() {
        XCTAssertEqual(CleanupLevel.light.stringValue, "light")
        XCTAssertEqual(CleanupLevel.normal.stringValue, "normal")
        XCTAssertEqual(CleanupLevel.deep.stringValue, "deep")
        XCTAssertEqual(CleanupLevel.system.stringValue, "system")
    }

    func testCleanupLevelFromString() {
        XCTAssertEqual(CleanupLevel.from(string: "light"), .light)
        XCTAssertEqual(CleanupLevel.from(string: "LIGHT"), .light)
        XCTAssertEqual(CleanupLevel.from(string: "Light"), .light)
        XCTAssertEqual(CleanupLevel.from(string: "normal"), .normal)
        XCTAssertEqual(CleanupLevel.from(string: "deep"), .deep)
        XCTAssertEqual(CleanupLevel.from(string: "system"), .system)
        XCTAssertNil(CleanupLevel.from(string: "invalid"))
    }
}

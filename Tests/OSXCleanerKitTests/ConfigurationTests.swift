import XCTest
@testable import OSXCleanerKit

final class ConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = AppConfiguration.default

        XCTAssertEqual(config.defaultSafetyLevel, 2) // Normal cleanup level
        XCTAssertTrue(config.autoBackup)
        XCTAssertEqual(config.logLevel, "info")
        XCTAssertFalse(config.excludedPaths.isEmpty)
    }

    func testCleanerConfigurationDefaults() {
        let config = CleanerConfiguration()

        XCTAssertEqual(config.cleanupLevel, .normal)
        XCTAssertFalse(config.dryRun)
        XCTAssertFalse(config.includeSystemCaches)
        XCTAssertFalse(config.includeDeveloperCaches)
        XCTAssertFalse(config.includeBrowserCaches)
        XCTAssertTrue(config.specificPaths.isEmpty)
    }

    func testAnalyzerConfigurationDefaults() {
        let config = AnalyzerConfiguration(targetPath: "/test/path")

        XCTAssertEqual(config.targetPath, "/test/path")
        XCTAssertNil(config.minSize)
        XCTAssertFalse(config.verbose)
        XCTAssertFalse(config.includeHidden)
    }

    func testConfigurationCodable() throws {
        let original = AppConfiguration(
            defaultSafetyLevel: 4,
            autoBackup: false,
            logLevel: "debug",
            excludedPaths: ["/test/path"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded.defaultSafetyLevel, original.defaultSafetyLevel)
        XCTAssertEqual(decoded.autoBackup, original.autoBackup)
        XCTAssertEqual(decoded.logLevel, original.logLevel)
        XCTAssertEqual(decoded.excludedPaths, original.excludedPaths)
    }
}

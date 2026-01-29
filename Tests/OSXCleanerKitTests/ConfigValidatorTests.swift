// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

final class ConfigValidatorTests: XCTestCase {
    // MARK: - Cleanup Level Validation Tests

    func testValidateConfig_ValidLightLevel_Succeeds() throws {
        // Given: Valid configuration with light cleanup level
        let config = CleanerConfiguration(
            cleanupLevel: .light,
            dryRun: false
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateConfig_ValidNormalLevel_Succeeds() throws {
        // Given: Valid configuration with normal cleanup level
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: false
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateConfig_ValidDeepLevel_Succeeds() throws {
        // Given: Valid configuration with deep cleanup level
        let config = CleanerConfiguration(
            cleanupLevel: .deep,
            dryRun: false
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateConfig_ValidSystemLevel_Succeeds() throws {
        // Given: Valid configuration with system cleanup level (not dry-run)
        let config = CleanerConfiguration(
            cleanupLevel: .system,
            dryRun: false
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    // MARK: - Path Validation Tests

    func testValidateConfig_EmptyPaths_Succeeds() throws {
        // Given: Configuration with no specific paths
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            specificPaths: []
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateConfig_ValidPaths_Succeeds() throws {
        // Given: Configuration with valid specific paths
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            specificPaths: [
                "~/Library/Caches",
                "/tmp"
            ]
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateConfig_InvalidPath_ThrowsError() throws {
        // Given: Configuration with invalid path (empty)
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            specificPaths: [""]
        )

        // When/Then: Validation should throw emptyPath error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .emptyPath = validationError {
                // Expected error
            } else {
                XCTFail("Expected emptyPath error, got \(validationError)")
            }
        }
    }

    func testValidateConfig_PathWithNullByte_ThrowsError() throws {
        // Given: Configuration with path containing null byte
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            specificPaths: ["/tmp/test\0"]
        )

        // When/Then: Validation should throw nullByteInPath error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .nullByteInPath = validationError {
                // Expected error
            } else {
                XCTFail("Expected nullByteInPath error, got \(validationError)")
            }
        }
    }

    func testValidateConfig_TooLongPath_ThrowsError() throws {
        // Given: Configuration with path exceeding maximum length
        let longPath = String(repeating: "a", count: PathValidator.maximumPathLength + 1)
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            specificPaths: [longPath]
        )

        // When/Then: Validation should throw pathTooLong error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .pathTooLong = validationError {
                // Expected error
            } else {
                XCTFail("Expected pathTooLong error, got \(validationError)")
            }
        }
    }

    // MARK: - Conflicting Options Tests

    func testValidateConfig_SystemLevelWithDryRun_ThrowsError() throws {
        // Given: Configuration with system level and dry-run (conflicting)
        let config = CleanerConfiguration(
            cleanupLevel: .system,
            dryRun: true
        )

        // When/Then: Validation should throw conflictingOptions error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .conflictingOptions = validationError {
                // Expected error
            } else {
                XCTFail("Expected conflictingOptions error, got \(validationError)")
            }
        }
    }

    func testValidateConfig_NormalLevelWithDryRun_Succeeds() throws {
        // Given: Configuration with normal level and dry-run (allowed)
        let config = CleanerConfiguration(
            cleanupLevel: .normal,
            dryRun: true
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    // MARK: - MDM Configuration Tests

    func testValidateMDMConfig_ValidHTTPS_Succeeds() throws {
        // Given: Valid MDM configuration with HTTPS URL
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://example.com")!,
            requestTimeout: 30,
            syncInterval: 300,
            autoSync: true,
            autoReportStatus: true
        )

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validate(config))
    }

    func testValidateMDMConfig_InsecureHTTP_ThrowsError() throws {
        // Given: MDM configuration with HTTP URL (insecure)
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "http://example.com")!,
            requestTimeout: 30,
            syncInterval: 300,
            autoSync: true,
            autoReportStatus: true
        )

        // When/Then: Validation should throw insecureMDMURL error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .insecureMDMURL = validationError {
                // Expected error
            } else {
                XCTFail("Expected insecureMDMURL error, got \(validationError)")
            }
        }
    }

    func testValidateMDMConfig_NegativeSyncInterval_ThrowsError() throws {
        // Given: MDM configuration with negative sync interval
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://example.com")!,
            requestTimeout: 30,
            syncInterval: -1,
            autoSync: true,
            autoReportStatus: true
        )

        // When/Then: Validation should throw invalidCheckInterval error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .invalidCheckInterval = validationError {
                // Expected error
            } else {
                XCTFail("Expected invalidCheckInterval error, got \(validationError)")
            }
        }
    }

    func testValidateMDMConfig_ZeroSyncInterval_ThrowsError() throws {
        // Given: MDM configuration with zero sync interval
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://example.com")!,
            requestTimeout: 30,
            syncInterval: 0,
            autoSync: true,
            autoReportStatus: true
        )

        // When/Then: Validation should throw invalidCheckInterval error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .invalidCheckInterval = validationError {
                // Expected error
            } else {
                XCTFail("Expected invalidCheckInterval error, got \(validationError)")
            }
        }
    }

    func testValidateMDMConfig_NegativeRequestTimeout_ThrowsError() throws {
        // Given: MDM configuration with negative request timeout
        let config = MDMConfiguration(
            provider: .jamf,
            serverURL: URL(string: "https://example.com")!,
            requestTimeout: -1,
            syncInterval: 300,
            autoSync: true,
            autoReportStatus: true
        )

        // When/Then: Validation should throw invalidCheckInterval error
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Expected ValidationError")
                return
            }
            if case .invalidCheckInterval = validationError {
                // Expected error
            } else {
                XCTFail("Expected invalidCheckInterval error, got \(validationError)")
            }
        }
    }

    // MARK: - Batch Validation Tests

    func testValidateAll_AllValid_Succeeds() throws {
        // Given: Array of all valid configurations
        let configs = [
            CleanerConfiguration(cleanupLevel: .light, dryRun: false),
            CleanerConfiguration(cleanupLevel: .normal, dryRun: true),
            CleanerConfiguration(cleanupLevel: .deep, dryRun: false)
        ]

        // When/Then: Validation should succeed
        XCTAssertNoThrow(try ConfigValidator.validateAll(configs))
    }

    func testValidateAll_OneInvalid_ThrowsError() throws {
        // Given: Array with one invalid configuration
        let configs = [
            CleanerConfiguration(cleanupLevel: .light, dryRun: false),
            CleanerConfiguration(cleanupLevel: .system, dryRun: true),  // Invalid
            CleanerConfiguration(cleanupLevel: .deep, dryRun: false)
        ]

        // When/Then: Validation should throw error for first invalid config
        XCTAssertThrowsError(try ConfigValidator.validateAll(configs))
    }

    func testValidateAllWithErrors_CollectsAllErrors() throws {
        // Given: Array with multiple invalid configurations
        let configs = [
            CleanerConfiguration(cleanupLevel: .light, dryRun: false),  // Valid
            CleanerConfiguration(cleanupLevel: .system, dryRun: true),  // Invalid
            CleanerConfiguration(
                cleanupLevel: .normal,
                specificPaths: [""]  // Invalid path
            )
        ]

        // When: Validate all with error collection
        let errors = ConfigValidator.validateAllWithErrors(configs)

        // Then: Should collect 2 errors
        XCTAssertEqual(errors.count, 2)

        // First error should be conflictingOptions
        if case .conflictingOptions = errors[0] {
            // Expected
        } else {
            XCTFail("Expected conflictingOptions as first error")
        }

        // Second error should be emptyPath
        if case .emptyPath = errors[1] {
            // Expected
        } else {
            XCTFail("Expected emptyPath as second error")
        }
    }

    func testValidateAllWithErrors_NoErrors_ReturnsEmpty() throws {
        // Given: Array of all valid configurations
        let configs = [
            CleanerConfiguration(cleanupLevel: .light, dryRun: false),
            CleanerConfiguration(cleanupLevel: .normal, dryRun: true),
            CleanerConfiguration(cleanupLevel: .deep, dryRun: false)
        ]

        // When: Validate all with error collection
        let errors = ConfigValidator.validateAllWithErrors(configs)

        // Then: Should have no errors
        XCTAssertTrue(errors.isEmpty)
    }
}

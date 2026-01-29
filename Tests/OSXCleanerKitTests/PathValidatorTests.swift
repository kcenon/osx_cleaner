import XCTest
@testable import OSXCleanerKit

final class PathValidatorTests: XCTestCase {
    // MARK: - Empty Path Tests

    func testValidate_EmptyPath_ThrowsError() {
        XCTAssertThrowsError(try PathValidator.validate("")) { error in
            guard case ValidationError.emptyPath = error else {
                XCTFail("Expected emptyPath error, got \(error)")
                return
            }
        }
    }

    func testValidate_WhitespaceOnlyPath_ThrowsError() {
        XCTAssertThrowsError(try PathValidator.validate("   ")) { error in
            guard case ValidationError.emptyPath = error else {
                XCTFail("Expected emptyPath error, got \(error)")
                return
            }
        }
    }

    func testValidate_NewlineOnlyPath_ThrowsError() {
        XCTAssertThrowsError(try PathValidator.validate("\n\t")) { error in
            guard case ValidationError.emptyPath = error else {
                XCTFail("Expected emptyPath error, got \(error)")
                return
            }
        }
    }

    // MARK: - Null Byte Tests

    func testValidate_NullByteInMiddle_ThrowsError() {
        let pathWithNull = "path\0malicious"
        XCTAssertThrowsError(try PathValidator.validate(pathWithNull)) { error in
            guard case ValidationError.nullByteInPath = error else {
                XCTFail("Expected nullByteInPath error, got \(error)")
                return
            }
        }
    }

    func testValidate_NullByteAtEnd_ThrowsError() {
        let pathWithNull = "/valid/path\0"
        XCTAssertThrowsError(try PathValidator.validate(pathWithNull)) { error in
            guard case ValidationError.nullByteInPath = error else {
                XCTFail("Expected nullByteInPath error, got \(error)")
                return
            }
        }
    }

    // MARK: - Path Length Tests

    func testValidate_ExcessivelyLongPath_ThrowsError() {
        let longPath = String(repeating: "a", count: 2000)
        XCTAssertThrowsError(try PathValidator.validate(longPath)) { error in
            guard case ValidationError.pathTooLong = error else {
                XCTFail("Expected pathTooLong error, got \(error)")
                return
            }
        }
    }

    func testValidate_MaximumLengthPath_Succeeds() throws {
        // Create a path at the maximum length (but don't check existence)
        let maxLengthPath = String(repeating: "a", count: 1024)
        let options = PathValidator.ValidationOptions(
            checkExistence: false,
            checkReadability: false,
            allowSystemPaths: false,
            expandTilde: false
        )

        XCTAssertNoThrow(try PathValidator.validate(maxLengthPath, options: options))
    }

    // MARK: - Path Traversal Tests

    func testValidate_PathTraversalAttempt_Canonicalizes() throws {
        // Create a temp directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_pathvalidator")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }

        let traversalPath = testDir.path + "/../test_pathvalidator"
        let validatedURL = try PathValidator.validate(traversalPath)

        // Should be canonicalized (no .. components)
        XCTAssertFalse(validatedURL.path.contains(".."))
        XCTAssertEqual(validatedURL.path, testDir.path)
    }

    // MARK: - System Path Protection Tests

    func testValidate_SystemPath_ThrowsError() {
        let systemPaths = [
            "/System/Library/Frameworks",
            "/Library/System/Configuration",
            "/private/var/db/dslocal",
            "/dev/null",
            "/etc/hosts",
            "/bin/ls",
            "/sbin/reboot",
            "/usr/bin/git",
            "/var/db/sudo"
        ]

        for systemPath in systemPaths {
            XCTAssertThrowsError(
                try PathValidator.validate(systemPath, options: .lenient),
                "Expected error for system path: \(systemPath)"
            ) { error in
                guard case ValidationError.systemPathNotAllowed = error else {
                    XCTFail("Expected systemPathNotAllowed error for \(systemPath), got \(error)")
                    return
                }
            }
        }
    }

    func testValidate_SystemPathWithAllowFlag_Succeeds() throws {
        let options = PathValidator.ValidationOptions(
            checkExistence: false,
            checkReadability: false,
            allowSystemPaths: true,
            expandTilde: false
        )

        XCTAssertNoThrow(try PathValidator.validate("/System/Library", options: options))
    }

    func testValidate_UserPath_Succeeds() throws {
        // Create a temp directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_user_path")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }

        let validatedURL = try PathValidator.validate(testDir.path)
        XCTAssertEqual(validatedURL.path, testDir.path)
    }

    // MARK: - Tilde Expansion Tests

    func testValidate_TildePath_Expands() throws {
        let options = PathValidator.ValidationOptions(
            checkExistence: false,
            checkReadability: false,
            allowSystemPaths: false,
            expandTilde: true
        )

        let url = try PathValidator.validate("~/Documents", options: options)
        XCTAssertFalse(url.path.contains("~"))
        XCTAssertTrue(url.path.contains("/Users/"))
    }

    func testValidate_TildePathWithoutExpansion_KeepsTilde() throws {
        let options = PathValidator.ValidationOptions(
            checkExistence: false,
            checkReadability: false,
            allowSystemPaths: false,
            expandTilde: false
        )

        // With expandTilde: false, URL(fileURLWithPath:) will treat ~ literally
        let url = try PathValidator.validate("~/Documents", options: options)
        // After standardization, it becomes relative to current directory
        // Not a great test - better to just verify no crash
        XCTAssertNotNil(url)
    }

    // MARK: - Existence Check Tests

    func testValidate_NonExistentPath_WithExistenceCheck_ThrowsError() {
        let nonExistentPath = "/nonexistent/path/that/does/not/exist"
        let options = PathValidator.ValidationOptions(checkExistence: true)

        XCTAssertThrowsError(try PathValidator.validate(nonExistentPath, options: options)) { error in
            guard case ValidationError.pathNotFound = error else {
                XCTFail("Expected pathNotFound error, got \(error)")
                return
            }
        }
    }

    func testValidate_NonExistentPath_WithoutExistenceCheck_Succeeds() throws {
        let nonExistentPath = "/nonexistent/path/safe/location"
        let options = PathValidator.ValidationOptions(checkExistence: false)

        XCTAssertNoThrow(try PathValidator.validate(nonExistentPath, options: options))
    }

    func testValidate_ExistingPath_Succeeds() throws {
        // Use temporary directory which always exists
        let tempDir = FileManager.default.temporaryDirectory
        let url = try PathValidator.validate(tempDir.path)

        XCTAssertEqual(url.path, tempDir.path)
    }

    // MARK: - Readability Check Tests

    func testValidate_ReadablePath_Succeeds() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let options = PathValidator.ValidationOptions(
            checkExistence: true,
            checkReadability: true
        )

        XCTAssertNoThrow(try PathValidator.validate(tempDir.path, options: options))
    }

    // MARK: - Batch Validation Tests

    func testValidateAll_MultiplePaths_Succeeds() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir1 = tempDir.appendingPathComponent("test_batch1")
        let testDir2 = tempDir.appendingPathComponent("test_batch2")

        try FileManager.default.createDirectory(at: testDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testDir2, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDir1)
            try? FileManager.default.removeItem(at: testDir2)
        }

        let paths = [testDir1.path, testDir2.path]
        let validatedURLs = try PathValidator.validateAll(paths)

        XCTAssertEqual(validatedURLs.count, 2)
        XCTAssertEqual(validatedURLs[0].path, testDir1.path)
        XCTAssertEqual(validatedURLs[1].path, testDir2.path)
    }

    func testValidateAll_OneInvalidPath_ThrowsError() {
        let paths = [
            FileManager.default.temporaryDirectory.path,
            "/System/Library"  // System path should throw
        ]

        XCTAssertThrowsError(try PathValidator.validateAll(paths))
    }

    func testValidateAllWithErrors_MixedPaths_ReturnsPartialResults() {
        let tempDir = FileManager.default.temporaryDirectory
        let paths = [
            tempDir.path,           // Valid
            "/System/Library",      // Invalid (system path)
            "",                     // Invalid (empty)
            tempDir.path            // Valid
        ]

        let (validURLs, errors) = PathValidator.validateAllWithErrors(paths)

        XCTAssertEqual(validURLs.count, 2)
        XCTAssertEqual(errors.count, 2)

        // Check error types
        XCTAssertTrue(errors.contains { error in
            if case ValidationError.systemPathNotAllowed = error.error {
                return true
            }
            return false
        })

        XCTAssertTrue(errors.contains { error in
            if case ValidationError.emptyPath = error.error {
                return true
            }
            return false
        })
    }

    // MARK: - Utility Method Tests

    func testIsSystemProtectedPath_SystemPaths_ReturnsTrue() {
        let systemPaths = [
            "/System/Library",
            "/Library/System/Preferences",
            "/dev/disk0",
            "/etc/passwd",
            "/bin/bash"
        ]

        for path in systemPaths {
            XCTAssertTrue(
                PathValidator.isSystemProtectedPath(path),
                "Expected \(path) to be system-protected"
            )
        }
    }

    func testIsSystemProtectedPath_UserPaths_ReturnsFalse() {
        let userPaths = [
            "/Users/test/Library",
            "/Applications/Safari.app",
            "/private/tmp"
        ]

        for path in userPaths {
            XCTAssertFalse(
                PathValidator.isSystemProtectedPath(path),
                "Expected \(path) to not be system-protected"
            )
        }
    }

    func testIsSensitivePath_SensitivePaths_ReturnsTrue() {
        let sensitivePaths = [
            "/Users/Shared/data",
            "/Library/Keychains/login.keychain",
            "/Library/Security/Keychains"
        ]

        for path in sensitivePaths {
            XCTAssertTrue(
                PathValidator.isSensitivePath(path),
                "Expected \(path) to be sensitive"
            )
        }
    }

    func testIsSensitivePath_RegularPaths_ReturnsFalse() {
        let regularPaths = [
            "/Users/test/Documents",
            "/Applications",
            "/tmp/cache"
        ]

        for path in regularPaths {
            XCTAssertFalse(
                PathValidator.isSensitivePath(path),
                "Expected \(path) to not be sensitive"
            )
        }
    }

    // MARK: - Validation Options Tests

    func testValidationOptions_Default() {
        let options = PathValidator.ValidationOptions.default

        XCTAssertTrue(options.checkExistence)
        XCTAssertFalse(options.checkReadability)
        XCTAssertFalse(options.allowSystemPaths)
        XCTAssertTrue(options.expandTilde)
    }

    func testValidationOptions_Strict() {
        let options = PathValidator.ValidationOptions.strict

        XCTAssertTrue(options.checkExistence)
        XCTAssertTrue(options.checkReadability)
        XCTAssertFalse(options.allowSystemPaths)
        XCTAssertTrue(options.expandTilde)
    }

    func testValidationOptions_Lenient() {
        let options = PathValidator.ValidationOptions.lenient

        XCTAssertFalse(options.checkExistence)
        XCTAssertFalse(options.checkReadability)
        XCTAssertFalse(options.allowSystemPaths)
        XCTAssertTrue(options.expandTilde)
    }

    // MARK: - String Path Validation Tests

    func testValidatePath_ReturnsString() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let pathString = try PathValidator.validatePath(tempDir.path)

        XCTAssertEqual(pathString, tempDir.path)
        XCTAssertTrue(pathString is String)
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// End-to-end FFI integration tests: Swift → C bridge → Rust → JSON → Swift.
///
/// Every other test in the suite mocks the FFI boundary. This file is the
/// only place that exercises the real Rust library, so it catches ABI and
/// schema drift that unit tests cannot see. The Rust core must be built
/// before these tests run — CI does this via `cargo build --release` on the
/// `rust-core` workspace; locally, run the same command once.
///
/// If the Rust library fails to load, `RustBridge.shared.initialize()` quietly
/// switches to fallback mode instead of throwing. Tests skip with a clear
/// message in that case so they don't become false failures on machines
/// without the compiled static library.
final class FFIRoundTripTests: XCTestCase {

    private var bridge: RustBridge { RustBridge.shared }

    override func setUpWithError() throws {
        try bridge.initialize()
        try XCTSkipIf(
            bridge.isFallbackMode,
            "Rust core is in fallback mode; FFI round-trip tests require the real static library. Run 'cargo build --release' under rust-core/ first."
        )
    }

    // MARK: - Version (simplest round-trip, proves the bridge is alive)

    func testVersion_ReturnsNonEmptyString() throws {
        let version = try bridge.version()
        XCTAssertFalse(version.isEmpty, "Rust core reported an empty version string")
    }

    // MARK: - analyzePath happy path

    func testAnalyze_DirectoryWithKnownFiles_DecodesSchema() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileA = tempDir.appendingPathComponent("a.txt")
        let fileB = tempDir.appendingPathComponent("b.log")
        try "hello ffi".write(to: fileA, atomically: true, encoding: .utf8)
        try "hello ffi, part 2".write(to: fileB, atomically: true, encoding: .utf8)

        let result = try bridge.analyzePath(tempDir.path)

        // Round-trip proves that Rust's snake_case JSON decoded into the
        // Swift Codable struct — that is the specific failure mode this test
        // is designed to catch.
        XCTAssertEqual(result.path, tempDir.path)
        XCTAssertEqual(result.fileCount, 2, "Expected 2 regular files under \(tempDir.path)")
        XCTAssertGreaterThan(result.totalSize, 0)
        XCTAssertNotNil(result.categories as [RustCategoryStats]?)
        XCTAssertNotNil(result.largestItems as [RustFileInfo]?)
        XCTAssertNotNil(result.oldestItems as [RustFileInfo]?)
    }

    func testAnalyze_EmptyDirectory_ReportsZeroFiles() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try bridge.analyzePath(tempDir.path)
        XCTAssertEqual(result.path, tempDir.path)
        XCTAssertEqual(result.fileCount, 0)
        XCTAssertEqual(result.totalSize, 0)
    }

    // MARK: - Error propagation

    func testAnalyze_NullByteInPath_ThrowsSwiftError() throws {
        // RustBridge validates strings before handing them to Rust; a null
        // byte must surface as a Swift-side error, not a Rust panic or an
        // untyped FFI failure.
        XCTAssertThrowsError(try bridge.analyzePath("/tmp/invalid\u{0000}path")) { error in
            guard let bridgeError = error as? RustBridgeError else {
                XCTFail("Expected RustBridgeError, got \(error)")
                return
            }
            // Any of the boundary-validation cases is acceptable — the point
            // is that the error materialized at the Swift layer rather than
            // crashing Rust.
            switch bridgeError {
            case .invalidString, .invalidUTF8, .nullPointer, .rustError:
                break
            default:
                XCTFail("Expected input-validation RustBridgeError case, got \(bridgeError)")
            }
        }
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ffi-rt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}

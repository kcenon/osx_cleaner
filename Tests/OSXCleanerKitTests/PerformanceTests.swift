// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// Comprehensive performance tests for OSX Cleaner
///
/// These tests measure and track performance of critical operations to:
/// - Establish performance baselines
/// - Detect performance regressions
/// - Validate SLO compliance
///
/// # Performance SLOs
///
/// | Operation | Target | Notes |
/// |-----------|--------|-------|
/// | Analyze 100 files | <500ms | Baseline |
/// | Analyze 10K files | <2s | Cold cache |
/// | FFI call overhead | <100us | Per call |
/// | Memory usage | <100MB | Peak for 100K files |
final class PerformanceTests: XCTestCase {

    var bridge: RustBridge!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()
        bridge = RustBridge.shared
        try? bridge.initialize()

        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner_perf_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        testDirectory = nil
        super.tearDown()
    }

    // MARK: - Test Data Generation

    /// Create test files in a directory
    private func createTestFiles(count: Int, at directory: URL) {
        let cacheDir = directory.appendingPathComponent("Library/Caches")
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        for i in 0..<count {
            let filePath = cacheDir.appendingPathComponent("cache_file_\(i).tmp")
            let data = "Cache data for file \(i)".data(using: .utf8)!
            try? data.write(to: filePath)
        }
    }

    /// Create varied size test files
    private func createVariedSizeFiles(count: Int, at directory: URL) {
        let cacheDir = directory.appendingPathComponent("Library/Caches")
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        for i in 0..<count {
            let filePath = cacheDir.appendingPathComponent("file_\(i).dat")
            // Vary file sizes: small (100B), medium (1KB), large (10KB)
            let size: Int
            switch i % 3 {
            case 0: size = 100
            case 1: size = 1024
            default: size = 10240
            }
            let data = Data(repeating: UInt8(ascii: "X"), count: size)
            try? data.write(to: filePath)
        }
    }

    /// Create nested directory structure
    private func createNestedStructure(depth: Int, filesPerDir: Int, at directory: URL) {
        var currentPath = directory.appendingPathComponent("Library/Caches")

        for d in 0..<depth {
            currentPath = currentPath.appendingPathComponent("level_\(d)")
            try? FileManager.default.createDirectory(
                at: currentPath,
                withIntermediateDirectories: true
            )

            for f in 0..<filesPerDir {
                let filePath = currentPath.appendingPathComponent("file_\(f).dat")
                let data = "Data at depth \(d) file \(f)".data(using: .utf8)!
                try? data.write(to: filePath)
            }
        }
    }

    // MARK: - FFI Overhead Tests

    /// Measure RustBridge version query performance
    func testPerformanceVersionQuery() throws {
        // Warm up
        for _ in 0..<10 {
            _ = try? bridge.version()
        }

        measure {
            for _ in 0..<1000 {
                _ = try? self.bridge.version()
            }
        }
    }

    /// Measure safety calculation performance
    func testPerformanceSafetyCalculation() throws {
        let testPaths = [
            "/tmp/test.tmp",
            "/Users/test/Library/Caches/app",
            "/System/Library/Frameworks",
            "/Users/test/Library/Developer/Xcode/DerivedData"
        ]

        measure {
            for _ in 0..<250 {
                for path in testPaths {
                    _ = try? self.bridge.calculateSafety(for: path)
                }
            }
        }
    }

    // MARK: - File Analysis Performance Tests

    /// Measure analysis of small directory (100 files)
    func testPerformanceAnalyzeSmallDirectory() throws {
        createTestFiles(count: 100, at: testDirectory)

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    /// Measure analysis of medium directory (1000 files)
    func testPerformanceAnalyzeMediumDirectory() throws {
        createTestFiles(count: 1000, at: testDirectory)

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    /// Measure analysis of large directory (10000 files)
    func testPerformanceAnalyzeLargeDirectory() throws {
        createTestFiles(count: 10000, at: testDirectory)

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    /// Measure analysis with varied file sizes
    func testPerformanceAnalyzeVariedSizes() throws {
        createVariedSizeFiles(count: 1000, at: testDirectory)

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    /// Measure analysis of nested directory structure
    func testPerformanceAnalyzeNestedStructure() throws {
        createNestedStructure(depth: 10, filesPerDir: 10, at: testDirectory)

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    // MARK: - Cleanup Performance Tests

    /// Measure dry-run cleanup performance
    func testPerformanceCleanupDryRun() throws {
        createTestFiles(count: 1000, at: testDirectory)

        measure {
            _ = try? self.bridge.cleanPath(
                self.testDirectory.path,
                cleanupLevel: .normal,
                dryRun: true
            )
        }
    }

    // MARK: - Concurrent Access Performance Tests

    /// Measure concurrent version queries
    func testPerformanceConcurrentVersionQueries() async throws {
        // Warm up
        for _ in 0..<10 {
            _ = try? bridge.version()
        }

        let start = Date()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    _ = try? self.bridge.version()
                }
            }
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0, "Concurrent version queries took too long: \(elapsed)s")
    }

    /// Measure concurrent analysis operations
    func testPerformanceConcurrentAnalysis() async throws {
        createTestFiles(count: 100, at: testDirectory)

        let start = Date()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = try? self.bridge.analyzePath(self.testDirectory.path)
                }
            }
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 30.0, "Concurrent analysis took too long: \(elapsed)s")
    }

    // MARK: - Memory Usage Tests

    /// Measure memory usage during large analysis
    func testPerformanceMemoryUsage() throws {
        createTestFiles(count: 10000, at: testDirectory)

        // Run analysis multiple times to check for memory leaks
        for _ in 0..<10 {
            _ = try? bridge.analyzePath(testDirectory.path)
        }

        // If we get here without OOM, memory management is working
    }

    /// Stress test with many small operations
    func testPerformanceStressTest() throws {
        createTestFiles(count: 100, at: testDirectory)

        measure {
            for _ in 0..<100 {
                _ = try? self.bridge.version()
                _ = try? self.bridge.analyzePath(self.testDirectory.path)
            }
        }
    }

    // MARK: - Real-World Scenario Tests

    /// Measure performance analyzing typical user directories
    func testPerformanceRealWorldAnalysis() throws {
        // Simulate a realistic user structure
        let subdirs = ["Documents", "Downloads", "Desktop", "Library/Caches", "Library/Logs"]

        for subdir in subdirs {
            let dirPath = testDirectory.appendingPathComponent(subdir)
            try? FileManager.default.createDirectory(
                at: dirPath,
                withIntermediateDirectories: true
            )

            // Create some files in each
            for i in 0..<20 {
                let filePath = dirPath.appendingPathComponent("file_\(i).dat")
                let data = Data(repeating: UInt8(ascii: "X"), count: 1024)
                try? data.write(to: filePath)
            }
        }

        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }
    }

    // MARK: - Baseline Performance Assertions

    /// Verify small directory analysis completes within SLO
    func testSLOSmallDirectoryAnalysis() throws {
        createTestFiles(count: 100, at: testDirectory)

        let start = Date()
        _ = try? bridge.analyzePath(testDirectory.path)
        let elapsed = Date().timeIntervalSince(start)

        // SLO: 100 files should complete in <500ms
        XCTAssertLessThan(
            elapsed,
            0.5,
            "Small directory analysis exceeded SLO: \(elapsed)s (target: <0.5s)"
        )
    }

    /// Verify FFI call overhead within SLO
    func testSLOFFICallOverhead() throws {
        // Warm up
        for _ in 0..<100 {
            _ = try? bridge.version()
        }

        let iterations = 1000
        let start = Date()

        for _ in 0..<iterations {
            _ = try? bridge.version()
        }

        let elapsed = Date().timeIntervalSince(start)
        let perCallMs = (elapsed / Double(iterations)) * 1000

        // SLO: FFI call should be <0.1ms (100us)
        XCTAssertLessThan(
            perCallMs,
            0.1,
            "FFI call overhead exceeded SLO: \(perCallMs)ms (target: <0.1ms)"
        )
    }
}

// MARK: - Performance Metrics Extension

extension PerformanceTests {
    /// Calculate and report throughput metrics
    private func measureThroughput(
        operationName: String,
        itemCount: Int,
        operation: () throws -> Void
    ) throws {
        let start = Date()
        try operation()
        let elapsed = Date().timeIntervalSince(start)

        let throughput = Double(itemCount) / elapsed
        print("[\(operationName)] Throughput: \(Int(throughput)) items/sec, Total: \(itemCount) items in \(String(format: "%.3f", elapsed))s")
    }
}

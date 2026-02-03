// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025

import XCTest
@testable import OSXCleanerKit

/// Swift layer performance tests measuring end-to-end operations including FFI overhead
///
/// These tests complement Rust benchmarks (#174.1) by measuring integration-level metrics
/// including Swift-Rust FFI boundary overhead, complete analysis pipeline, and memory usage.
///
/// # Performance SLOs
///
/// | Test | Target | Notes |
/// |------|--------|-------|
/// | Small directory (100 files) | <500ms | Cold cache |
/// | Large directory (10K files) | <2s | Cold cache |
/// | Parallel cleanup (1K files) | <5s | Concurrent operations |
/// | Single FFI call | <100us | Overhead only |
/// | Memory usage (100K files) | <100MB | Peak usage |
///
/// Run with: `swift test --filter Performance`
final class AnalyzerPerformanceTests: XCTestCase {

    var bridge: RustBridge!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()
        bridge = RustBridge.shared
        try? bridge.initialize()

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner_analyzer_perf_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        testDirectory = nil
        super.tearDown()
    }

    // MARK: - Test Data Helpers

    /// Create a temporary directory with specified number of files
    ///
    /// - Parameters:
    ///   - fileCount: Number of files to create
    ///   - directory: Optional base directory (uses testDirectory if nil)
    /// - Returns: URL of the created directory
    private func createTempDirectory(fileCount: Int, at directory: URL? = nil) -> URL {
        let baseDir = directory ?? testDirectory!
        let cacheDir = baseDir.appendingPathComponent("Library/Caches")
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        for i in 0..<fileCount {
            let filePath = cacheDir.appendingPathComponent("cache_\(i).tmp")
            // Create files with varied sizes (100B to 1KB)
            let size = 100 + (i % 10) * 100
            let data = Data(repeating: UInt8(ascii: "X"), count: size)
            try? data.write(to: filePath)
        }

        return baseDir
    }

    /// Create multiple subdirectories with files for parallel testing
    private func createParallelTestStructure(
        subdirectoryCount: Int,
        filesPerDirectory: Int,
        at directory: URL
    ) {
        for i in 0..<subdirectoryCount {
            let subDir = directory.appendingPathComponent("subdir_\(i)/Library/Caches")
            try? FileManager.default.createDirectory(
                at: subDir,
                withIntermediateDirectories: true
            )

            for j in 0..<filesPerDirectory {
                let filePath = subDir.appendingPathComponent("file_\(j).dat")
                let data = Data(repeating: UInt8(ascii: "D"), count: 512)
                try? data.write(to: filePath)
            }
        }
    }

    // MARK: - Analysis Performance Tests

    /// Test analysis performance with small directory (100 files)
    ///
    /// SLO: < 500ms cold cache
    func testAnalyzePerformance_SmallDirectory() throws {
        _ = createTempDirectory(fileCount: 100)

        // Measure using XCTest measure block
        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }

        // Explicit SLO verification
        let start = Date()
        _ = try? bridge.analyzePath(testDirectory.path)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            0.5,
            "Small directory (100 files) analysis exceeded SLO: \(String(format: "%.3f", elapsed))s (target: <0.5s)"
        )
    }

    /// Test analysis performance with large directory (10K files)
    ///
    /// SLO: < 2s cold cache
    func testAnalyzePerformance_LargeDirectory() throws {
        _ = createTempDirectory(fileCount: 10000)

        // Use measure for baseline metrics
        measure {
            _ = try? self.bridge.analyzePath(self.testDirectory.path)
        }

        // Explicit SLO verification
        let start = Date()
        _ = try? bridge.analyzePath(testDirectory.path)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            2.0,
            "Large directory (10K files) analysis exceeded SLO: \(String(format: "%.3f", elapsed))s (target: <2s)"
        )
    }

    /// Test parallel cleanup performance (1K files)
    ///
    /// SLO: < 5s parallel cleanup
    func testCleanPerformance_ParallelCleanup() async throws {
        // Create 10 subdirectories with 100 files each = 1000 files total
        createParallelTestStructure(
            subdirectoryCount: 10,
            filesPerDirectory: 100,
            at: testDirectory
        )

        let cleanerService = CleanerService()
        let subdirs = try FileManager.default.contentsOfDirectory(
            at: testDirectory,
            includingPropertiesForKeys: nil
        )

        let start = Date()

        // Parallel cleanup using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for subdir in subdirs {
                group.addTask {
                    let config = CleanerConfiguration(
                        cleanupLevel: .normal,
                        dryRun: true,  // Dry run to measure speed without actual deletion
                        specificPaths: [subdir.path]
                    )
                    _ = try? await cleanerService.clean(with: config)
                }
            }
        }

        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            5.0,
            "Parallel cleanup (1K files) exceeded SLO: \(String(format: "%.3f", elapsed))s (target: <5s)"
        )
    }

    /// Test FFI call overhead for single call
    ///
    /// SLO: < 100us per call
    func testFFIOverhead_SingleCall() throws {
        // Warm up
        for _ in 0..<100 {
            _ = try? bridge.version()
        }

        let iterations = 10000
        let start = Date()

        for _ in 0..<iterations {
            _ = try? bridge.version()
        }

        let totalElapsed = Date().timeIntervalSince(start)
        let perCallMicroseconds = (totalElapsed / Double(iterations)) * 1_000_000

        XCTAssertLessThan(
            perCallMicroseconds,
            100.0,
            "FFI call overhead exceeded SLO: \(String(format: "%.2f", perCallMicroseconds))us (target: <100us)"
        )

        // Also use measure for XCTest metrics
        measure {
            for _ in 0..<1000 {
                _ = try? self.bridge.version()
            }
        }
    }

    /// Test memory usage during large analysis (100K files)
    ///
    /// SLO: < 100MB peak memory usage
    ///
    /// Note: Uses automaticallyStartMeasuring = false for accurate memory measurement
    func testMemoryUsage_LargeAnalysis() throws {
        // Create test data (100K files would take too long, use 50K for reasonable test time)
        // Scale down but still meaningful for memory testing
        _ = createTempDirectory(fileCount: 50000)

        // Capture initial memory
        let initialMemory = getMemoryUsage()

        // Perform analysis
        _ = try? bridge.analyzePath(testDirectory.path)

        // Capture peak memory
        let peakMemory = getMemoryUsage()
        let memoryUsedMB = Double(peakMemory - initialMemory) / (1024 * 1024)

        // Scaled SLO: 50K files should use < 50MB (proportional to 100MB for 100K)
        XCTAssertLessThan(
            memoryUsedMB,
            50.0,
            "Memory usage for 50K files exceeded scaled SLO: \(String(format: "%.2f", memoryUsedMB))MB (target: <50MB)"
        )

        // Run multiple times to check for memory leaks
        for _ in 0..<5 {
            _ = try? bridge.analyzePath(testDirectory.path)
        }

        let finalMemory = getMemoryUsage()
        let leakCheck = Double(finalMemory - peakMemory) / (1024 * 1024)

        // Memory growth between iterations should be minimal (< 25MB)
        // CI environments may have higher memory variance due to GC timing differences
        XCTAssertLessThan(
            leakCheck,
            25.0,
            "Potential memory leak detected: \(String(format: "%.2f", leakCheck))MB growth after 5 iterations"
        )
    }

    // MARK: - Additional Performance Tests

    /// Test AnalyzerService end-to-end performance
    func testAnalyzerServicePerformance() async throws {
        _ = createTempDirectory(fileCount: 1000)

        let analyzer = AnalyzerService()
        let config = AnalyzerConfiguration(targetPath: testDirectory.path)

        let start = Date()
        _ = try? await analyzer.analyze(with: config)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            1.0,
            "AnalyzerService analysis (1K files) took too long: \(String(format: "%.3f", elapsed))s"
        )
    }

    /// Test concurrent analysis operations
    func testConcurrentAnalysis() async throws {
        _ = createTempDirectory(fileCount: 100)

        let start = Date()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    _ = try? self.bridge.analyzePath(self.testDirectory.path)
                }
            }
        }

        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed,
            10.0,
            "50 concurrent analyses took too long: \(String(format: "%.3f", elapsed))s"
        )
    }

    /// Test safety calculation performance
    func testSafetyCalculationPerformance() throws {
        let testPaths = [
            "/tmp/test.tmp",
            "/Users/test/Library/Caches/app",
            "/System/Library/Frameworks",
            "/Users/test/Library/Developer/Xcode/DerivedData"
        ]

        measure {
            for _ in 0..<500 {
                for path in testPaths {
                    _ = try? self.bridge.calculateSafety(for: path)
                }
            }
        }
    }

    // MARK: - Memory Helpers

    /// Get current memory usage in bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}


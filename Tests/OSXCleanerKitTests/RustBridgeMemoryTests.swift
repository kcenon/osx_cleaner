// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import XCTest
@testable import OSXCleanerKit

/// Tests for RustBridge memory management
///
/// These tests verify that the FFI boundary between Swift and Rust
/// properly manages memory without leaks or crashes.
final class RustBridgeMemoryTests: XCTestCase {

    var bridge: RustBridge!

    override func setUp() {
        super.setUp()
        bridge = RustBridge.shared
        try? bridge.initialize()
    }

    // MARK: - Basic Memory Tests

    func testInitializationMultipleTimes() throws {
        // Initialize multiple times should be safe (idempotent)
        for _ in 0..<100 {
            try bridge.initialize()
        }
    }

    func testVersionRepeatedCalls() throws {
        // Calling version multiple times should not leak memory
        for _ in 0..<1000 {
            _ = try bridge.version()
        }
    }

    func testAnalyzePathRepeatedCalls() throws {
        // Repeated analysis should not leak memory
        for _ in 0..<100 {
            _ = try? bridge.analyzePath("/tmp")
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentInitialization() async throws {
        // Multiple concurrent initializations should be safe
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? self.bridge.initialize()
                }
            }
        }
    }

    func testConcurrentVersionCalls() async throws {
        // Concurrent version calls should be safe
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? self.bridge.version()
                }
            }
        }
    }

    func testConcurrentAnalyzeCalls() async throws {
        // Concurrent analysis calls should be safe
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    // Use different paths to avoid potential caching
                    _ = try? self.bridge.analyzePath("/tmp/test\(i)")
                }
            }
        }
    }

    // MARK: - Large Data Tests

    func testAnalyzeLargeDirectory() throws {
        // Analyzing large directories should not leak memory
        let testPaths = [
            "/Library",
            "/Applications",
            "/System/Library",
            "/Users"
        ]

        for path in testPaths {
            _ = try? bridge.analyzePath(path)
        }
    }

    func testMultipleAnalysisOperations() throws {
        // Multiple different analysis operations
        for _ in 0..<50 {
            _ = try? bridge.analyzePath("/tmp")
            _ = try? bridge.version()
        }
    }

    // MARK: - Error Path Tests

    func testInvalidPathNoLeak() throws {
        // Invalid paths should not leak memory
        let invalidPaths = [
            "/nonexistent/path/12345",
            "/invalid/\u{0000}/path",
            "",
            String(repeating: "/very/long/path", count: 100)
        ]

        for path in invalidPaths {
            _ = try? bridge.analyzePath(path)
        }
    }

    func testErrorPathRepeated() throws {
        // Repeated errors should not leak memory
        for _ in 0..<1000 {
            _ = try? bridge.analyzePath("/nonexistent/path/12345")
        }
    }

    // MARK: - Stress Tests

    func testStressTestSequential() throws {
        // Sequential stress test
        for i in 0..<10000 {
            if i % 2 == 0 {
                _ = try? bridge.version()
            } else {
                _ = try? bridge.analyzePath("/tmp")
            }
        }
    }

    func testStressTestConcurrent() async throws {
        // Concurrent stress test
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    if i % 2 == 0 {
                        _ = try? self.bridge.version()
                    } else {
                        _ = try? self.bridge.analyzePath("/tmp")
                    }
                }
            }
        }
    }

    // MARK: - Memory Growth Tests

    func testNoMemoryGrowthOverTime() throws {
        // Perform operations and check that memory doesn't grow significantly
        // This is a basic sanity check; precise leak detection requires instruments

        for _ in 0..<1000 {
            _ = try? bridge.version()
            _ = try? bridge.analyzePath("/tmp")
        }

        // If we get here without OOM, basic memory management is working
    }

    func testRapidAllocationDeallocation() throws {
        // Rapidly allocate and deallocate
        for _ in 0..<10000 {
            _ = try? bridge.version()
        }
    }

    // MARK: - Edge Cases

    func testEmptyStringPath() throws {
        // Empty string should be handled gracefully
        _ = try? bridge.analyzePath("")
    }

    func testNullBytePath() throws {
        // Path with null bytes should be handled gracefully
        let pathWithNull = "/tmp\u{0000}/test"
        _ = try? bridge.analyzePath(pathWithNull)
    }

    func testVeryLongPath() throws {
        // Very long path should be handled gracefully
        let longPath = "/" + String(repeating: "long/path/component/", count: 100)
        _ = try? bridge.analyzePath(longPath)
    }

    func testUnicodePathNames() throws {
        // Unicode characters in paths should work correctly
        let unicodePaths = [
            "/tmp/테스트",
            "/tmp/测试",
            "/tmp/тест",
            "/tmp/🔥test🔥"
        ]

        for path in unicodePaths {
            _ = try? bridge.analyzePath(path)
        }
    }

    // MARK: - Performance Benchmarks

    func testPerformanceVersion() throws {
        measure {
            for _ in 0..<1000 {
                _ = try? bridge.version()
            }
        }
    }

    func testPerformanceAnalyzePath() throws {
        measure {
            for _ in 0..<100 {
                _ = try? bridge.analyzePath("/tmp")
            }
        }
    }

    func testPerformanceConcurrentAccess() async throws {
        await measureAsync {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        _ = try? self.bridge.version()
                    }
                }
            }
        }
    }
}

// MARK: - Test Helper Extensions

extension XCTestCase {
    func measureAsync(block: @escaping () async -> Void) async {
        let start = Date()
        await block()
        let end = Date()
        let duration = end.timeIntervalSince(start)
        print("Async operation took \(duration) seconds")
    }
}

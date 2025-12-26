import XCTest
@testable import OSXCleanerKit

final class AutomatedCleanupLoggingServiceTests: XCTestCase {
    var service: AutomatedCleanupLoggingService!
    var testLogDirectory: URL!

    override func setUp() {
        super.setUp()
        // Use a temporary directory for testing
        testLogDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-test-logs-\(UUID().uuidString)")

        let config = CleanupLoggingConfig(
            maxLogFileSize: 1024 * 10,  // 10 KB for testing rotation
            maxRotatedFiles: 3,
            includeDetailedLogs: true
        )
        service = AutomatedCleanupLoggingService(config: config)
    }

    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: testLogDirectory)
        service = nil
        super.tearDown()
    }

    // MARK: - CleanupLoggingConfig Tests

    func testCleanupLoggingConfigDefaults() {
        let config = CleanupLoggingConfig()

        XCTAssertEqual(config.maxLogFileSize, 10 * 1024 * 1024)  // 10 MB
        XCTAssertEqual(config.maxRotatedFiles, 5)
        XCTAssertFalse(config.includeDetailedLogs)
    }

    func testCleanupLoggingConfigCustomValues() {
        let config = CleanupLoggingConfig(
            maxLogFileSize: 5 * 1024 * 1024,
            maxRotatedFiles: 10,
            includeDetailedLogs: true
        )

        XCTAssertEqual(config.maxLogFileSize, 5 * 1024 * 1024)
        XCTAssertEqual(config.maxRotatedFiles, 10)
        XCTAssertTrue(config.includeDetailedLogs)
    }

    // MARK: - CleanupSession Tests

    func testCleanupSessionCreation() {
        let session = CleanupSession(
            triggerType: .scheduled,
            cleanupLevel: "light"
        )

        XCTAssertFalse(session.sessionId.isEmpty)
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.triggerType, .scheduled)
        XCTAssertEqual(session.cleanupLevel, "light")
        XCTAssertNil(session.result)
    }

    func testCleanupSessionTriggerTypes() {
        let manual = CleanupSession(triggerType: .manual, cleanupLevel: "normal")
        XCTAssertEqual(manual.triggerType, .manual)
        XCTAssertEqual(manual.triggerType.rawValue, "manual")

        let scheduled = CleanupSession(triggerType: .scheduled, cleanupLevel: "normal")
        XCTAssertEqual(scheduled.triggerType, .scheduled)
        XCTAssertEqual(scheduled.triggerType.rawValue, "scheduled")

        let autoCleanup = CleanupSession(triggerType: .autoCleanup, cleanupLevel: "normal")
        XCTAssertEqual(autoCleanup.triggerType, .autoCleanup)
        XCTAssertEqual(autoCleanup.triggerType.rawValue, "auto_cleanup")

        let diskMonitor = CleanupSession(triggerType: .diskMonitor, cleanupLevel: "normal")
        XCTAssertEqual(diskMonitor.triggerType, .diskMonitor)
        XCTAssertEqual(diskMonitor.triggerType.rawValue, "disk_monitor")
    }

    func testCleanupSessionCodable() throws {
        var session = CleanupSession(
            sessionId: "test-session-123",
            triggerType: .scheduled,
            cleanupLevel: "deep"
        )
        session.endTime = Date()
        session.result = CleanupSessionResult(
            freedBytes: 1024 * 1024 * 100,
            filesRemoved: 50,
            directoriesRemoved: 5,
            errorsCount: 2,
            durationSeconds: 45.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CleanupSession.self, from: data)

        XCTAssertEqual(decoded.sessionId, session.sessionId)
        XCTAssertEqual(decoded.triggerType, session.triggerType)
        XCTAssertEqual(decoded.cleanupLevel, session.cleanupLevel)
        XCTAssertNotNil(decoded.endTime)
        XCTAssertNotNil(decoded.result)
    }

    // MARK: - CleanupSessionResult Tests

    func testCleanupSessionResultCreation() {
        let result = CleanupSessionResult(
            freedBytes: 1024 * 1024 * 500,  // 500 MB
            filesRemoved: 100,
            directoriesRemoved: 10,
            errorsCount: 5,
            durationSeconds: 30.5
        )

        XCTAssertEqual(result.freedBytes, 1024 * 1024 * 500)
        XCTAssertEqual(result.filesRemoved, 100)
        XCTAssertEqual(result.directoriesRemoved, 10)
        XCTAssertEqual(result.errorsCount, 5)
        XCTAssertEqual(result.durationSeconds, 30.5)
    }

    func testCleanupSessionResultFormattedSpace() {
        let result = CleanupSessionResult(
            freedBytes: 1024 * 1024 * 100,  // 100 MB
            filesRemoved: 50,
            directoriesRemoved: 5,
            errorsCount: 0,
            durationSeconds: 10.0
        )

        XCTAssertFalse(result.formattedFreedSpace.isEmpty)
        XCTAssertTrue(result.formattedFreedSpace.contains("MB") || result.formattedFreedSpace.contains("100"))
    }

    func testCleanupSessionResultCodable() throws {
        let original = CleanupSessionResult(
            freedBytes: 2048,
            filesRemoved: 10,
            directoriesRemoved: 2,
            errorsCount: 1,
            durationSeconds: 5.25
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CleanupSessionResult.self, from: data)

        XCTAssertEqual(decoded.freedBytes, original.freedBytes)
        XCTAssertEqual(decoded.filesRemoved, original.filesRemoved)
        XCTAssertEqual(decoded.directoriesRemoved, original.directoriesRemoved)
        XCTAssertEqual(decoded.errorsCount, original.errorsCount)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds)
    }

    // MARK: - AutomatedCleanupLoggingService Tests

    func testServiceCreation() {
        let service = AutomatedCleanupLoggingService()
        XCTAssertNotNil(service)
    }

    func testSharedInstance() {
        let shared1 = AutomatedCleanupLoggingService.shared
        let shared2 = AutomatedCleanupLoggingService.shared
        XCTAssertTrue(shared1 === shared2)
    }

    func testGetLogFilePath() {
        let path = service.getLogFilePath()
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("cleanup.log"))
    }

    func testLogSessionStartEnd() {
        var session = CleanupSession(
            triggerType: .scheduled,
            cleanupLevel: "light"
        )

        // Log session start (should not throw)
        service.logSessionStart(session)

        // Complete the session
        session.endTime = Date()
        session.result = CleanupSessionResult(
            freedBytes: 1024,
            filesRemoved: 5,
            directoriesRemoved: 1,
            errorsCount: 0,
            durationSeconds: 2.0
        )

        // Log session end (should not throw)
        service.logSessionEnd(session)

        // Give async queue time to write
        let expectation = XCTestExpectation(description: "Log write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testLogError() {
        // Log an error (should not throw)
        service.logError(
            sessionId: "test-session",
            path: "/test/path/file.txt",
            error: "Permission denied"
        )

        // Give async queue time to write
        let expectation = XCTestExpectation(description: "Log write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testLogDiskMonitorTrigger() {
        // Log disk monitor trigger (should not throw)
        service.logDiskMonitorTrigger(
            usagePercent: 95.5,
            threshold: "emergency"
        )

        // Give async queue time to write
        let expectation = XCTestExpectation(description: "Log write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetAllLogFiles() {
        let files = service.getAllLogFiles()
        // May be empty if no logs have been written yet
        XCTAssertNotNil(files)
    }

    func testReadRecentEntriesEmpty() {
        // Reading from non-existent or empty log
        let entries = service.readRecentEntries(count: 10)
        // Should return empty array, not crash
        XCTAssertNotNil(entries)
    }

    // MARK: - Integration Tests

    func testFullLoggingWorkflow() {
        // Create a session
        var session = CleanupSession(
            triggerType: .diskMonitor,
            cleanupLevel: "normal"
        )

        // Log session start
        service.logSessionStart(session)

        // Log some errors
        service.logError(
            sessionId: session.sessionId,
            path: "/path/to/file1",
            error: "Access denied"
        )
        service.logError(
            sessionId: session.sessionId,
            path: "/path/to/file2",
            error: "File in use"
        )

        // Complete the session
        session.endTime = Date()
        session.result = CleanupSessionResult(
            freedBytes: 1024 * 1024 * 50,
            filesRemoved: 25,
            directoriesRemoved: 3,
            errorsCount: 2,
            durationSeconds: 15.0
        )

        // Log session end
        service.logSessionEnd(session)

        // Give async queue time to complete all writes
        let expectation = XCTestExpectation(description: "All logs written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}

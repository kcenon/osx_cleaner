import XCTest
@testable import OSXCleanerKit

final class AuditSystemTests: XCTestCase {

    // MARK: - Setup/Teardown

    var tempDatabasePath: URL!

    override func setUp() {
        super.setUp()
        tempDatabasePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("osxcleaner-audit-test-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDatabasePath)
        super.tearDown()
    }

    // MARK: - AuditEventCategory Tests

    func testAuditEventCategoryAllCases() {
        let categories = AuditEventCategory.allCases
        XCTAssertEqual(categories.count, 5)
        XCTAssertTrue(categories.contains(.cleanup))
        XCTAssertTrue(categories.contains(.policy))
        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.system))
        XCTAssertTrue(categories.contains(.user))
    }

    func testAuditEventCategoryCodable() throws {
        let category = AuditEventCategory.cleanup
        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(AuditEventCategory.self, from: encoded)
        XCTAssertEqual(category, decoded)
    }

    // MARK: - AuditEventResult Tests

    func testAuditEventResultCodable() throws {
        for result in [AuditEventResult.success, .failure, .warning, .skipped] {
            let encoded = try JSONEncoder().encode(result)
            let decoded = try JSONDecoder().decode(AuditEventResult.self, from: encoded)
            XCTAssertEqual(result, decoded)
        }
    }

    // MARK: - AuditEventSeverity Tests

    func testAuditEventSeverityCodable() throws {
        for severity in [AuditEventSeverity.info, .warning, .error, .critical] {
            let encoded = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(AuditEventSeverity.self, from: encoded)
            XCTAssertEqual(severity, decoded)
        }
    }

    // MARK: - AuditEvent Tests

    func testAuditEventInitialization() {
        let event = AuditEvent(
            category: .cleanup,
            action: "delete_cache",
            actor: "osxcleaner",
            target: "~/Library/Caches/test",
            result: .success
        )

        XCTAssertEqual(event.category, .cleanup)
        XCTAssertEqual(event.action, "delete_cache")
        XCTAssertEqual(event.actor, "osxcleaner")
        XCTAssertEqual(event.target, "~/Library/Caches/test")
        XCTAssertEqual(event.result, .success)
        XCTAssertEqual(event.severity, .info)
        XCTAssertFalse(event.hostname.isEmpty)
        XCTAssertFalse(event.username.isEmpty)
    }

    func testAuditEventCodable() throws {
        let event = AuditEvent(
            category: .security,
            action: "access_denied",
            actor: "user",
            target: "/System/Library",
            result: .failure,
            severity: .warning,
            metadata: ["reason": "protected_path"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuditEvent.self, from: data)

        XCTAssertEqual(event.id, decoded.id)
        XCTAssertEqual(event.category, decoded.category)
        XCTAssertEqual(event.action, decoded.action)
        XCTAssertEqual(event.result, decoded.result)
        XCTAssertEqual(event.metadata, decoded.metadata)
    }

    func testAuditEventCleanupConvenience() {
        let event = AuditEvent.cleanup(
            action: "delete_file",
            target: "/path/to/file",
            result: .success,
            freedBytes: 1_000_000,
            sessionId: "test-session"
        )

        XCTAssertEqual(event.category, .cleanup)
        XCTAssertEqual(event.action, "delete_file")
        XCTAssertEqual(event.result, .success)
        XCTAssertEqual(event.metadata["freed_bytes"], "1000000")
        XCTAssertNotNil(event.metadata["freed_formatted"])
        XCTAssertEqual(event.sessionId, "test-session")
    }

    func testAuditEventPolicyConvenience() {
        let event = AuditEvent.policy(
            action: "apply",
            policyName: "enterprise-standard",
            result: .success,
            details: ["version": "1.0"]
        )

        XCTAssertEqual(event.category, .policy)
        XCTAssertEqual(event.target, "enterprise-standard")
        XCTAssertEqual(event.metadata["version"], "1.0")
    }

    func testAuditEventSecurityConvenience() {
        let event = AuditEvent.security(
            action: "blocked_access",
            target: "/System",
            result: .failure,
            severity: .critical
        )

        XCTAssertEqual(event.category, .security)
        XCTAssertEqual(event.severity, .critical)
    }

    func testAuditEventSystemConvenience() {
        let event = AuditEvent.system(
            action: "startup",
            details: ["version": "1.0.0"]
        )

        XCTAssertEqual(event.category, .system)
        XCTAssertEqual(event.result, .success)
        XCTAssertEqual(event.metadata["version"], "1.0.0")
    }

    // MARK: - AuditEventQuery Tests

    func testAuditEventQueryLastEvents() {
        let query = AuditEventQuery.lastEvents(50)
        XCTAssertEqual(query.limit, 50)
        XCTAssertFalse(query.ascending)
    }

    func testAuditEventQueryForCategory() {
        let query = AuditEventQuery.forCategory(.cleanup)
        XCTAssertEqual(query.category, .cleanup)
    }

    func testAuditEventQueryForSession() {
        let query = AuditEventQuery.forSession("test-session-id")
        XCTAssertEqual(query.sessionId, "test-session-id")
    }

    func testAuditEventQueryToday() {
        let query = AuditEventQuery.today
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        XCTAssertEqual(query.startDate, startOfToday)
    }

    // MARK: - AuditStatistics Tests

    func testAuditStatisticsFormattedFreedSpace() {
        let stats = AuditStatistics(
            totalEvents: 100,
            byCategory: [.cleanup: 50, .system: 50],
            byResult: [.success: 90, .failure: 10],
            totalFreedBytes: 1_073_741_824,  // 1 GB
            dateRange: nil
        )

        XCTAssertEqual(stats.totalEvents, 100)
        XCTAssertTrue(stats.formattedFreedSpace.contains("GB") || stats.formattedFreedSpace.contains("기가"))
    }

    // MARK: - AuditStoreConfig Tests

    func testAuditStoreConfigDefaults() {
        let config = AuditStoreConfig()

        XCTAssertEqual(config.maxEvents, 100_000)
        XCTAssertEqual(config.retentionDays, 365)
        XCTAssertTrue(config.autoVacuum)
    }

    func testAuditStoreConfigCustom() {
        let config = AuditStoreConfig(
            maxEvents: 50_000,
            retentionDays: 90,
            autoVacuum: false
        )

        XCTAssertEqual(config.maxEvents, 50_000)
        XCTAssertEqual(config.retentionDays, 90)
        XCTAssertFalse(config.autoVacuum)
    }

    // MARK: - AuditEventStore Tests

    func testAuditEventStoreInsertAndQuery() throws {
        let store = try AuditEventStore()

        let event = AuditEvent(
            category: .cleanup,
            action: "test_action",
            actor: "test",
            target: "/test/path",
            result: .success
        )

        try store.insert(event)

        let events = try store.query(.lastEvents(10))
        XCTAssertTrue(events.contains { $0.id == event.id })
    }

    func testAuditEventStoreQueryByCategory() throws {
        let store = try AuditEventStore()

        // Insert events of different categories
        try store.insert(AuditEvent(
            category: .cleanup,
            action: "cleanup1",
            actor: "test",
            target: "/path1",
            result: .success
        ))

        try store.insert(AuditEvent(
            category: .security,
            action: "security1",
            actor: "test",
            target: "/path2",
            result: .failure
        ))

        // Query only cleanup events
        let cleanupEvents = try store.query(.forCategory(.cleanup))
        XCTAssertTrue(cleanupEvents.allSatisfy { $0.category == .cleanup })
    }

    func testAuditEventStoreCount() throws {
        let store = try AuditEventStore()

        let initialCount = try store.count(AuditEventQuery())

        try store.insert(AuditEvent(
            category: .system,
            action: "test",
            actor: "test",
            target: "test",
            result: .success
        ))

        let newCount = try store.count(AuditEventQuery())
        XCTAssertEqual(newCount, initialCount + 1)
    }

    func testAuditEventStoreStatistics() throws {
        let store = try AuditEventStore()

        // Insert test events
        try store.insert(AuditEvent.cleanup(
            action: "delete",
            target: "/path",
            result: .success,
            freedBytes: 1000
        ))

        try store.insert(AuditEvent.cleanup(
            action: "delete",
            target: "/path2",
            result: .failure,
            freedBytes: nil
        ))

        let stats = try store.statistics(AuditEventQuery())
        XCTAssertTrue(stats.totalEvents >= 2)
        XCTAssertNotNil(stats.byCategory[.cleanup])
    }

    // MARK: - AuditLoggerConfig Tests

    func testAuditLoggerConfigDefaults() {
        let config = AuditLoggerConfig()

        XCTAssertFalse(config.consoleLogging)
        XCTAssertTrue(config.autoRetention)
        XCTAssertEqual(config.retentionCheckInterval, 24)
    }

    // MARK: - AuditExporter Tests

    func testAuditExporterJSON() throws {
        let exporter = AuditExporter()
        let events = [
            AuditEvent(
                category: .cleanup,
                action: "test",
                actor: "test",
                target: "/path",
                result: .success
            )
        ]

        let json = try exporter.exportToJSON(events)
        XCTAssertTrue(json.contains("cleanup"))
        XCTAssertTrue(json.contains("test"))
    }

    func testAuditExporterCSV() throws {
        let exporter = AuditExporter()
        let events = [
            AuditEvent(
                category: .security,
                action: "block",
                actor: "system",
                target: "/protected",
                result: .failure
            )
        ]

        let csv = try exporter.exportToCSV(events)
        XCTAssertTrue(csv.contains("id,timestamp,category"))  // Header
        XCTAssertTrue(csv.contains("security"))
        XCTAssertTrue(csv.contains("block"))
    }

    func testAuditExporterJSONLines() throws {
        let exporter = AuditExporter()
        let events = [
            AuditEvent(
                category: .system,
                action: "event1",
                actor: "test",
                target: "target1",
                result: .success
            ),
            AuditEvent(
                category: .user,
                action: "event2",
                actor: "test",
                target: "target2",
                result: .warning
            )
        ]

        let jsonl = try exporter.exportToJSONLines(events)
        let lines = jsonl.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
    }

    func testAuditExporterStatisticsReport() {
        let exporter = AuditExporter()
        let stats = AuditStatistics(
            totalEvents: 1000,
            byCategory: [.cleanup: 500, .system: 300, .security: 200],
            byResult: [.success: 900, .failure: 100],
            totalFreedBytes: 10_737_418_240,  // 10 GB
            dateRange: DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        )

        let report = exporter.exportStatisticsReport(stats)
        XCTAssertTrue(report.contains("AUDIT STATISTICS REPORT"))
        XCTAssertTrue(report.contains("Total Events: 1000"))
        XCTAssertTrue(report.contains("cleanup"))
    }

    // MARK: - AuditExportFormat Tests

    func testAuditExportFormatAllCases() {
        XCTAssertEqual(AuditExportFormat.allCases.count, 3)
        XCTAssertTrue(AuditExportFormat.allCases.contains(.json))
        XCTAssertTrue(AuditExportFormat.allCases.contains(.csv))
        XCTAssertTrue(AuditExportFormat.allCases.contains(.jsonLines))
    }

    func testAuditExportFormatRawValue() {
        XCTAssertEqual(AuditExportFormat.json.rawValue, "json")
        XCTAssertEqual(AuditExportFormat.csv.rawValue, "csv")
        XCTAssertEqual(AuditExportFormat.jsonLines.rawValue, "jsonl")
    }

    // MARK: - AuditEventStore Clear Tests

    func testAuditEventStoreClear() throws {
        let store = try AuditEventStore()

        // Insert some events
        try store.insert(AuditEvent(
            category: .system,
            action: "test_clear",
            actor: "test",
            target: "test",
            result: .success
        ))

        let countBefore = try store.count(AuditEventQuery())
        XCTAssertGreaterThan(countBefore, 0)

        // Clear all events
        try store.clear()

        let countAfter = try store.count(AuditEventQuery())
        XCTAssertEqual(countAfter, 0)
    }

    func testAuditEventStoreDatabasePath() throws {
        let store = try AuditEventStore()
        let path = store.getDatabasePath()

        XCTAssertTrue(path.contains("audit.db"))
        XCTAssertTrue(path.contains("osxcleaner"))
    }

    func testAuditEventStoreDatabaseSize() throws {
        let store = try AuditEventStore()

        // Insert some events to ensure database has content
        try store.insert(AuditEvent(
            category: .cleanup,
            action: "test_size",
            actor: "test",
            target: "test",
            result: .success
        ))

        let size = store.getDatabaseSize()
        XCTAssertGreaterThan(size, 0)
    }
}

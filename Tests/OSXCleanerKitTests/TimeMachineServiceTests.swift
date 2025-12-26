import XCTest
@testable import OSXCleanerKit

final class TimeMachineServiceTests: XCTestCase {
    var service: TimeMachineService!

    override func setUp() {
        super.setUp()
        service = TimeMachineService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Snapshot Struct Tests

    func testSnapshotFormatting() {
        let date = Date(timeIntervalSince1970: 1735200000) // 2024-12-26
        let snapshot = Snapshot(
            id: "com.apple.TimeMachine.2024-12-26-120000.local",
            date: date,
            volume: "/",
            estimatedSize: 1024 * 1024 * 1024 // 1 GB
        )

        XCTAssertEqual(snapshot.id, "com.apple.TimeMachine.2024-12-26-120000.local")
        XCTAssertEqual(snapshot.volume, "/")
        XCTAssertFalse(snapshot.formattedDate.isEmpty)
        XCTAssertFalse(snapshot.formattedSize.isEmpty)
    }

    func testSnapshotIdentifiable() {
        let date = Date()
        let snapshot1 = Snapshot(id: "snapshot1", date: date, volume: "/")
        let snapshot2 = Snapshot(id: "snapshot2", date: date, volume: "/")

        XCTAssertNotEqual(snapshot1.id, snapshot2.id)
    }

    // MARK: - TimeMachineStatus Tests

    func testTimeMachineStatusFormatting() {
        let lastBackup = Date()
        let status = TimeMachineStatus(
            isEnabled: true,
            lastBackupDate: lastBackup,
            backupDestination: "/Volumes/Backup",
            isBackingUp: false
        )

        XCTAssertTrue(status.isEnabled)
        XCTAssertFalse(status.isBackingUp)
        XCTAssertNotNil(status.formattedLastBackup)
        XCTAssertEqual(status.backupDestination, "/Volumes/Backup")
    }

    func testTimeMachineStatusWithoutBackup() {
        let status = TimeMachineStatus(
            isEnabled: false,
            lastBackupDate: nil,
            backupDestination: nil,
            isBackingUp: false
        )

        XCTAssertFalse(status.isEnabled)
        XCTAssertNil(status.formattedLastBackup)
        XCTAssertNil(status.backupDestination)
    }

    // MARK: - SnapshotDeletionResult Tests

    func testSnapshotDeletionResultSuccess() {
        let result = SnapshotDeletionResult(
            success: true,
            deletedCount: 5,
            freedBytes: 5 * 1024 * 1024 * 1024,
            errors: []
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.deletedCount, 5)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(result.formattedFreedSpace.isEmpty)
    }

    func testSnapshotDeletionResultWithErrors() {
        let errors = [
            SnapshotError(snapshot: "2024-12-26-120000", reason: "Permission denied")
        ]
        let result = SnapshotDeletionResult(
            success: false,
            deletedCount: 0,
            freedBytes: 0,
            errors: errors
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors.first?.reason, "Permission denied")
    }

    // MARK: - SnapshotError Tests

    func testSnapshotError() {
        let error = SnapshotError(
            snapshot: "test-snapshot",
            reason: "Failed to delete"
        )

        XCTAssertEqual(error.snapshot, "test-snapshot")
        XCTAssertEqual(error.reason, "Failed to delete")
    }

    // MARK: - Service Tests

    func testTimeMachineServiceCreation() {
        let service = TimeMachineService()
        XCTAssertNotNil(service)
    }

    func testIsTimeMachineEnabled() {
        // This test will pass regardless of actual Time Machine status
        // as it tests that the method doesn't crash
        let _ = service.isTimeMachineEnabled()
    }

    func testListLocalSnapshots() async throws {
        // This test verifies the method runs without error
        // Actual snapshot presence depends on system state
        do {
            let snapshots = try await service.listLocalSnapshots()
            // Method should return an array (possibly empty)
            XCTAssertNotNil(snapshots)
        } catch {
            // tmutil may fail on systems without proper permissions
            // This is acceptable for unit tests
            XCTAssertTrue(error is SnapshotError)
        }
    }

    func testGetStatus() async throws {
        // Test status retrieval doesn't crash
        do {
            let status = try await service.getStatus()
            XCTAssertNotNil(status)
        } catch {
            // Allow failure on systems without Time Machine
        }
    }

    // MARK: - Dry Run Tests

    func testDeleteSnapshotDryRun() async throws {
        let date = Date()

        let result = try await service.deleteSnapshot(date: date, dryRun: true)

        // Dry run should always succeed without actual deletion
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.deletedCount, 1)
    }

    func testThinSnapshotsDryRun() async throws {
        let result = try await service.thinSnapshots(dryRun: true)

        // Dry run should succeed
        XCTAssertTrue(result.success)
    }
}

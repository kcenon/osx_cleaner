import XCTest
@testable import OSXCleanerKit

final class CleanupSelectionTests: XCTestCase {
    func testSummaryCountsOnlySelectedScanItems() {
        let items = [
            ScannedCleanupSelectionItem(path: "/tmp/a", size: 1_024, isSelected: true),
            ScannedCleanupSelectionItem(path: "/tmp/b", size: 2_048, isSelected: false),
            ScannedCleanupSelectionItem(path: "/tmp/c", size: 4_096, isSelected: true)
        ]

        let summary = ScannedCleanupSelection.summary(for: items)

        XCTAssertEqual(summary.selectedItemCount, 2)
        XCTAssertEqual(summary.selectedTotalSize, 5_120)
        XCTAssertEqual(summary.selectedPaths, ["/tmp/a", "/tmp/c"])
        XCTAssertTrue(summary.hasSelection)
    }

    func testConfigurationUsesSelectedScanPathsWithoutBroadTargets() throws {
        let items = [
            ScannedCleanupSelectionItem(path: "/tmp/selected", size: 1_024, isSelected: true),
            ScannedCleanupSelectionItem(path: "/tmp/ignored", size: 2_048, isSelected: false)
        ]

        let config = try XCTUnwrap(ScannedCleanupSelection.makeConfiguration(
            cleanupLevel: .normal,
            items: items
        ))

        XCTAssertEqual(config.cleanupLevel, .normal)
        XCTAssertFalse(config.dryRun)
        XCTAssertFalse(config.includeSystemCaches)
        XCTAssertFalse(config.includeDeveloperCaches)
        XCTAssertFalse(config.includeBrowserCaches)
        XCTAssertFalse(config.includeLogsCaches)
        XCTAssertEqual(config.specificPaths, ["/tmp/selected"])
    }

    func testConfigurationIsNilForEmptySelection() {
        let items = [
            ScannedCleanupSelectionItem(path: "/tmp/a", size: 1_024, isSelected: false),
            ScannedCleanupSelectionItem(path: "/tmp/b", size: 2_048, isSelected: false)
        ]

        XCTAssertNil(ScannedCleanupSelection.makeConfiguration(cleanupLevel: .normal, items: items))
        XCTAssertFalse(ScannedCleanupSelection.summary(for: items).hasSelection)
    }
}

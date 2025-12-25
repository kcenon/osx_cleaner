import XCTest
@testable import OSXCleanerKit

final class AnalyzerServiceTests: XCTestCase {
    func testAnalysisResultFormatting() {
        let result = AnalysisResult(
            totalSize: 1024 * 1024 * 500, // 500 MB
            potentialSavings: 1024 * 1024 * 200, // 200 MB
            categories: []
        )

        XCTAssertFalse(result.formattedTotalSize.isEmpty)
        XCTAssertFalse(result.formattedPotentialSavings.isEmpty)
    }

    func testAnalysisCategoryFormatting() {
        let category = AnalysisCategory(
            name: "Test Category",
            size: 1024 * 1024 * 100, // 100 MB
            itemCount: 10,
            topItems: []
        )

        XCTAssertEqual(category.name, "Test Category")
        XCTAssertEqual(category.itemCount, 10)
        XCTAssertFalse(category.formattedSize.isEmpty)
    }

    func testAnalysisItemFormatting() {
        let item = AnalysisItem(
            path: "/test/path",
            size: 1024 * 1024, // 1 MB
            lastAccessed: Date()
        )

        XCTAssertEqual(item.path, "/test/path")
        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertNotNil(item.lastAccessed)
    }
}

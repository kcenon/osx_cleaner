// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct AnalyzeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze disk usage and find cleanup opportunities",
        discussion: """
            Scans directories to identify cleanup opportunities.
            Results can be filtered by category and sorted by size.

            Examples:
              osxcleaner analyze
              osxcleaner analyze --category xcode --top 10
              osxcleaner analyze --format json
              osxcleaner analyze ~/Library --min-size 100MB
            """
    )

    // MARK: - Options

    @Option(name: .shortAndLong, help: "Filter by category (all, xcode, docker, browser, caches, logs)")
    var category: AnalysisCategoryFilter = .all

    @Option(name: .long, help: "Output format (text, json)")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Show top N items by size")
    var top: Int?

    @Option(name: .shortAndLong, help: "Minimum file size to consider (e.g., 100MB)")
    var minSize: String?

    // MARK: - Flags

    @Flag(name: .shortAndLong, help: "Show detailed analysis")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Minimal output")
    var quiet: Bool = false

    @Flag(name: .long, help: "Include hidden files in analysis")
    var includeHidden: Bool = false

    // MARK: - Arguments

    @Argument(help: "Path to analyze (default: home directory)")
    var path: String?

    // MARK: - Run

    mutating func run() async throws {
        let output = OutputHandler(format: format, quiet: quiet, verbose: verbose)
        let targetPath = path ?? FileManager.default.homeDirectoryForCurrentUser.path

        output.display(message: "Analyzing: \(targetPath)", level: .normal)
        output.display(message: "Category: \(category.description)", level: .verbose)

        let config = AnalyzerConfiguration(
            targetPath: targetPath,
            minSize: parseSize(minSize),
            verbose: verbose,
            includeHidden: includeHidden
        )

        do {
            let service = AnalyzerService()
            let result = try await service.analyze(with: config)
            displayResults(result, output: output)
        } catch {
            output.displayError(error)
            throw ExitCode.generalError
        }
    }

    // MARK: - Private Methods

    private func parseSize(_ sizeString: String?) -> UInt64? {
        guard let sizeString = sizeString else { return nil }

        let units: [(String, UInt64)] = [
            ("TB", 1024 * 1024 * 1024 * 1024),
            ("GB", 1024 * 1024 * 1024),
            ("MB", 1024 * 1024),
            ("KB", 1024)
        ]

        for (unit, multiplier) in units {
            if sizeString.uppercased().hasSuffix(unit) {
                let numberPart = sizeString.dropLast(unit.count)
                if let value = Double(numberPart) {
                    return UInt64(value * Double(multiplier))
                }
            }
        }

        return UInt64(sizeString)
    }

    private func displayResults(_ result: AnalysisResult, output: OutputHandler) {
        switch format {
        case .text:
            displayTextResults(result, output: output)
        case .json:
            displayJSONResults(result)
        }
    }

    private func displayTextResults(_ result: AnalysisResult, output: OutputHandler) {
        output.display(message: "", level: .normal)
        output.display(message: "=== Analysis Results ===", level: .normal)
        output.display(message: "Total size analyzed: \(result.formattedTotalSize)", level: .normal)
        output.display(message: "Potential savings: \(result.formattedPotentialSavings)", level: .normal)

        if result.fileCount > 0 {
            output.display(message: "Files: \(result.fileCount)", level: .verbose)
        }
        if result.directoryCount > 0 {
            output.display(message: "Directories: \(result.directoryCount)", level: .verbose)
        }

        output.display(message: "", level: .normal)

        let filteredCategories = filterCategories(result.categories)

        for categoryResult in filteredCategories {
            output.display(
                message: "[\(categoryResult.name)] \(categoryResult.formattedSize) - \(categoryResult.itemCount) items",
                level: .normal
            )

            if verbose {
                let itemLimit = top ?? 5
                for item in categoryResult.topItems.prefix(itemLimit) {
                    output.display(message: "  - \(item.path): \(item.formattedSize)", level: .normal)
                }
                if categoryResult.topItems.count > itemLimit {
                    output.display(
                        message: "  ... and \(categoryResult.topItems.count - itemLimit) more",
                        level: .normal
                    )
                }
            }
        }

        // Show largest items if --top is specified
        if let topCount = top, !result.largestItems.isEmpty {
            output.display(message: "", level: .normal)
            output.display(message: "=== Top \(topCount) Largest Items ===", level: .normal)
            for item in result.largestItems.prefix(topCount) {
                let categoryInfo = item.category.map { " (\($0))" } ?? ""
                output.display(
                    message: "\(item.formattedSize) - \(item.path)\(categoryInfo)",
                    level: .normal
                )
            }
        }

        output.display(message: "", level: .normal)
        output.display(message: "Run 'osxcleaner clean' to clean up these items", level: .normal)
    }

    private func displayJSONResults(_ result: AnalysisResult) {
        let jsonOutput = AnalysisResultJSON(
            totalSize: result.totalSize,
            totalSizeFormatted: result.formattedTotalSize,
            potentialSavings: result.potentialSavings,
            potentialSavingsFormatted: result.formattedPotentialSavings,
            fileCount: result.fileCount,
            directoryCount: result.directoryCount,
            categories: filterCategories(result.categories).map { cat in
                CategoryJSON(
                    name: cat.name,
                    size: cat.size,
                    sizeFormatted: cat.formattedSize,
                    itemCount: cat.itemCount
                )
            },
            largestItems: result.largestItems.prefix(top ?? 10).map { item in
                ItemJSON(
                    path: item.path,
                    size: item.size,
                    sizeFormatted: item.formattedSize,
                    category: item.category
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let jsonData = try? encoder.encode(jsonOutput),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func filterCategories(_ categories: [AnalysisCategory]) -> [AnalysisCategory] {
        guard category != .all else { return categories }

        let categoryNames: [AnalysisCategoryFilter: [String]] = [
            .xcode: ["Developer Caches", "Xcode"],
            .docker: ["Docker"],
            .browser: ["Browser Caches", "Browser"],
            .caches: ["System Caches", "Caches"],
            .logs: ["Logs"]
        ]

        guard let matchNames = categoryNames[category] else { return categories }

        return categories.filter { cat in
            matchNames.contains { matchName in
                cat.name.lowercased().contains(matchName.lowercased())
            }
        }
    }
}

// MARK: - JSON Output Structures

private struct AnalysisResultJSON: Encodable {
    let totalSize: UInt64
    let totalSizeFormatted: String
    let potentialSavings: UInt64
    let potentialSavingsFormatted: String
    let fileCount: Int
    let directoryCount: Int
    let categories: [CategoryJSON]
    let largestItems: [ItemJSON]

    enum CodingKeys: String, CodingKey {
        case totalSize = "total_size"
        case totalSizeFormatted = "total_size_formatted"
        case potentialSavings = "potential_savings"
        case potentialSavingsFormatted = "potential_savings_formatted"
        case fileCount = "file_count"
        case directoryCount = "directory_count"
        case categories
        case largestItems = "largest_items"
    }
}

private struct CategoryJSON: Encodable {
    let name: String
    let size: UInt64
    let sizeFormatted: String
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case sizeFormatted = "size_formatted"
        case itemCount = "item_count"
    }
}

private struct ItemJSON: Encodable {
    let path: String
    let size: UInt64
    let sizeFormatted: String
    let category: String?

    enum CodingKeys: String, CodingKey {
        case path
        case size
        case sizeFormatted = "size_formatted"
        case category
    }
}

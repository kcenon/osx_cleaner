import ArgumentParser
import Foundation
import OSXCleanerKit

struct AnalyzeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze disk usage and find cleanup opportunities"
    )

    @Option(name: .shortAndLong, help: "Minimum file size to consider (e.g., 100MB)")
    var minSize: String?

    @Flag(name: .shortAndLong, help: "Show detailed analysis")
    var verbose: Bool = false

    @Flag(name: .long, help: "Include hidden files in analysis")
    var includeHidden: Bool = false

    @Argument(help: "Path to analyze (default: home directory)")
    var path: String?

    mutating func run() async throws {
        let progressView = ProgressView()
        let targetPath = path ?? FileManager.default.homeDirectoryForCurrentUser.path

        progressView.display(message: "Analyzing: \(targetPath)")

        let config = AnalyzerConfiguration(
            targetPath: targetPath,
            minSize: parseSize(minSize),
            verbose: verbose,
            includeHidden: includeHidden
        )

        let service = AnalyzerService()
        let result = try await service.analyze(with: config)

        displayResults(result, verbose: verbose, progressView: progressView)
    }

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

    private func displayResults(
        _ result: AnalysisResult,
        verbose: Bool,
        progressView: ProgressView
    ) {
        progressView.display(message: "\n=== Analysis Results ===")
        progressView.display(message: "Total size analyzed: \(result.formattedTotalSize)")
        progressView.display(message: "Potential savings: \(result.formattedPotentialSavings)")
        progressView.display(message: "")

        for category in result.categories {
            progressView.display(
                message: "[\(category.name)] \(category.formattedSize) - \(category.itemCount) items"
            )

            if verbose {
                for item in category.topItems.prefix(5) {
                    progressView.display(message: "  - \(item.path): \(item.formattedSize)")
                }
            }
        }

        progressView.display(message: "")
        progressView.display(message: "Run 'osxcleaner clean' to clean up these items")
    }
}

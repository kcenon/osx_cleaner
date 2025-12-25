import ArgumentParser
import OSXCleanerKit

struct CleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean specified targets with safety checks"
    )

    @Option(name: .shortAndLong, help: "Safety level (1-5, higher is safer)")
    var safetyLevel: Int = 3

    @Flag(name: .shortAndLong, help: "Perform dry run without actual deletion")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Include system caches in cleanup")
    var systemCaches: Bool = false

    @Flag(name: .long, help: "Include developer tool caches")
    var developerCaches: Bool = false

    @Flag(name: .long, help: "Include browser caches")
    var browserCaches: Bool = false

    @Argument(help: "Specific paths to clean (optional)")
    var paths: [String] = []

    mutating func run() async throws {
        let progressView = ProgressView()

        progressView.display(message: "Starting cleanup...")
        progressView.display(message: "Safety level: \(safetyLevel)")

        if dryRun {
            progressView.display(message: "[DRY RUN] No files will be deleted")
        }

        let config = CleanerConfiguration(
            safetyLevel: safetyLevel,
            dryRun: dryRun,
            includeSystemCaches: systemCaches,
            includeDeveloperCaches: developerCaches,
            includeBrowserCaches: browserCaches,
            specificPaths: paths
        )

        let service = CleanerService()
        let result = try await service.clean(with: config)

        progressView.display(message: "Cleanup completed!")
        progressView.display(message: "Freed: \(result.formattedFreedSpace)")
        progressView.display(message: "Files removed: \(result.filesRemoved)")
    }
}

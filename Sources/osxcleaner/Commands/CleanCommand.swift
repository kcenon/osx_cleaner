import ArgumentParser
import OSXCleanerKit

struct CleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean specified targets with safety checks"
    )

    @Option(name: .shortAndLong, help: "Cleanup level (1=light, 2=normal, 3=deep, 4=system)")
    var level: Int = 2

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

        let cleanupLevel = CleanupLevel(rawValue: Int32(level)) ?? .normal

        progressView.display(message: "Starting cleanup...")
        progressView.display(message: "Cleanup level: \(cleanupLevel.description)")

        if dryRun {
            progressView.display(message: "[DRY RUN] No files will be deleted")
        }

        let config = CleanerConfiguration(
            cleanupLevel: cleanupLevel,
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

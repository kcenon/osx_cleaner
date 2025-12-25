import ArgumentParser
import OSXCleanerKit

@main
struct OSXCleaner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "osxcleaner",
        abstract: "A safe and efficient macOS disk cleanup utility",
        version: "0.1.0",
        subcommands: [
            CleanCommand.self,
            AnalyzeCommand.self,
            ConfigCommand.self,
            ScheduleCommand.self
        ],
        defaultSubcommand: AnalyzeCommand.self
    )
}

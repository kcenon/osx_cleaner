import ArgumentParser
import Foundation
import OSXCleanerKit

struct ScheduleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schedule",
        abstract: "Manage automated cleanup schedules",
        discussion: """
            Create, list, and remove automated cleanup schedules using macOS launchd.
            Schedules are installed as LaunchAgents and run in the background.

            Examples:
              osxcleaner schedule list
              osxcleaner schedule add --frequency daily --level light
              osxcleaner schedule add --frequency weekly --level normal --hour 3
              osxcleaner schedule remove daily
            """,
        subcommands: [
            ListSchedules.self,
            AddSchedule.self,
            RemoveSchedule.self,
            EnableSchedule.self,
            DisableSchedule.self
        ],
        defaultSubcommand: ListSchedules.self
    )
}

// MARK: - List Schedules

extension ScheduleCommand {
    struct ListSchedules: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all configured schedules"
        )

        @Option(name: .long, help: "Output format (text, json)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let scheduler = ScheduleManager()
            let schedules = scheduler.listSchedules()

            switch format {
            case .text:
                displayTextSchedules(schedules)
            case .json:
                displayJSONSchedules(schedules)
            }
        }

        private func displayTextSchedules(_ schedules: [ScheduleInfo]) {
            let progressView = ProgressView()

            progressView.display(message: "=== Configured Schedules ===")
            progressView.display(message: "")

            if schedules.isEmpty {
                progressView.display(message: "No schedules configured.")
                progressView.display(message: "")
                progressView.display(message: "Use 'osxcleaner schedule add' to create a schedule.")
                return
            }

            for schedule in schedules {
                let status = schedule.enabled ? "enabled" : "disabled"
                progressView.display(
                    message: "[\(schedule.frequency)] Level: \(schedule.level) - \(status)"
                )
                progressView.display(message: "  Time: \(schedule.timeDescription)")
                progressView.display(message: "  Path: \(schedule.plistPath)")
                progressView.display(message: "")
            }
        }

        private func displayJSONSchedules(_ schedules: [ScheduleInfo]) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let jsonData = try? encoder.encode(schedules),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// MARK: - Add Schedule

extension ScheduleCommand {
    struct AddSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add a new cleanup schedule"
        )

        @Option(name: .shortAndLong, help: "Schedule frequency (daily, weekly, monthly)")
        var frequency: ScheduleFrequency = .daily

        @Option(name: .shortAndLong, help: "Cleanup level (light, normal, deep)")
        var level: CleanupLevel = .light

        @Option(name: .long, help: "Hour to run (0-23, default: 3)")
        var hour: Int = 3

        @Option(name: .long, help: "Minute to run (0-59, default: 0)")
        var minute: Int = 0

        @Option(name: .long, help: "Day of week for weekly schedules (0=Sunday, 1=Monday, etc.)")
        var weekday: Int?

        @Option(name: .long, help: "Day of month for monthly schedules (1-31)")
        var day: Int?

        @Flag(name: .long, help: "Enable schedule immediately after creation")
        var enable: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = ScheduleManager()

            // Validate inputs
            guard (0...23).contains(hour) else {
                progressView.displayError(ScheduleError.invalidHour(hour))
                throw ExitCode.configurationError
            }

            guard (0...59).contains(minute) else {
                progressView.displayError(ScheduleError.invalidMinute(minute))
                throw ExitCode.configurationError
            }

            if frequency == .weekly {
                if let weekday = weekday, !(0...6).contains(weekday) {
                    progressView.displayError(ScheduleError.invalidWeekday(weekday))
                    throw ExitCode.configurationError
                }
            }

            if frequency == .monthly {
                if let day = day, !(1...31).contains(day) {
                    progressView.displayError(ScheduleError.invalidDay(day))
                    throw ExitCode.configurationError
                }
            }

            progressView.display(message: "Creating \(frequency.rawValue) schedule...")

            do {
                let config = ScheduleConfig(
                    frequency: frequency,
                    level: level,
                    hour: hour,
                    minute: minute,
                    weekday: frequency == .weekly ? (weekday ?? 0) : nil,
                    day: frequency == .monthly ? (day ?? 1) : nil
                )

                try scheduler.createSchedule(config)
                progressView.displaySuccess("Schedule created: \(config.plistName)")

                if enable {
                    try scheduler.enableSchedule(frequency)
                    progressView.displaySuccess("Schedule enabled")
                } else {
                    progressView.display(message: "")
                    progressView.display(message: "Run 'osxcleaner schedule enable \(frequency.rawValue)' to activate")
                }
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Remove Schedule

extension ScheduleCommand {
    struct RemoveSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to remove (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = ScheduleManager()

            if !force {
                progressView.display(message: "Are you sure you want to remove the \(frequency.rawValue) schedule?")
                progressView.display(message: "Use --force to skip this prompt.")
                return
            }

            do {
                try scheduler.removeSchedule(frequency)
                progressView.displaySuccess("Schedule removed: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Enable Schedule

extension ScheduleCommand {
    struct EnableSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to enable (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = ScheduleManager()

            do {
                try scheduler.enableSchedule(frequency)
                progressView.displaySuccess("Schedule enabled: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Disable Schedule

extension ScheduleCommand {
    struct DisableSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable a cleanup schedule"
        )

        @Argument(help: "Schedule frequency to disable (daily, weekly, monthly)")
        var frequency: ScheduleFrequency

        mutating func run() async throws {
            let progressView = ProgressView()
            let scheduler = ScheduleManager()

            do {
                try scheduler.disableSchedule(frequency)
                progressView.displaySuccess("Schedule disabled: \(frequency.rawValue)")
            } catch {
                progressView.displayError(error)
                throw ExitCode.generalError
            }
        }
    }
}

// MARK: - Schedule Manager

struct ScheduleManager {
    private let fileManager = FileManager.default
    private let bundleIdentifier = "com.osxcleaner"

    private var launchAgentsPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }

    func listSchedules() -> [ScheduleInfo] {
        var schedules: [ScheduleInfo] = []

        for frequency in ScheduleFrequency.allCases {
            let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
            let plistPath = launchAgentsPath.appendingPathComponent(plistName)

            if fileManager.fileExists(atPath: plistPath.path) {
                if let info = parseScheduleInfo(from: plistPath, frequency: frequency) {
                    schedules.append(info)
                }
            }
        }

        return schedules
    }

    func createSchedule(_ config: ScheduleConfig) throws {
        try fileManager.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)

        let plistPath = launchAgentsPath.appendingPathComponent(config.plistName)
        let plistContent = generatePlistContent(for: config)

        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
    }

    func removeSchedule(_ frequency: ScheduleFrequency) throws {
        try disableSchedule(frequency)

        let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
        let plistPath = launchAgentsPath.appendingPathComponent(plistName)

        if fileManager.fileExists(atPath: plistPath.path) {
            try fileManager.removeItem(at: plistPath)
        }
    }

    func enableSchedule(_ frequency: ScheduleFrequency) throws {
        let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
        let plistPath = launchAgentsPath.appendingPathComponent(plistName)

        guard fileManager.fileExists(atPath: plistPath.path) else {
            throw ScheduleError.scheduleNotFound(frequency.rawValue)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ScheduleError.launchctlFailed("load")
        }
    }

    func disableSchedule(_ frequency: ScheduleFrequency) throws {
        let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
        let plistPath = launchAgentsPath.appendingPathComponent(plistName)

        guard fileManager.fileExists(atPath: plistPath.path) else {
            return // Already disabled or not exists
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]

        try process.run()
        process.waitUntilExit()
        // Ignore exit status for unload - it may fail if not loaded
    }

    private func parseScheduleInfo(from path: URL, frequency: ScheduleFrequency) -> ScheduleInfo? {
        guard let data = fileManager.contents(atPath: path.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? ""
        let isEnabled = isScheduleLoaded(label: label)

        var timeDescription = "Unknown"
        if let calendar = plist["StartCalendarInterval"] as? [String: Any] {
            let hour = calendar["Hour"] as? Int ?? 0
            let minute = calendar["Minute"] as? Int ?? 0
            timeDescription = String(format: "%02d:%02d", hour, minute)

            if let weekday = calendar["Weekday"] as? Int {
                let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                timeDescription += " on \(days[weekday])"
            }

            if let day = calendar["Day"] as? Int {
                timeDescription += " on day \(day)"
            }
        }

        // Parse cleanup level from program arguments
        var level = "normal"
        if let args = plist["ProgramArguments"] as? [String],
           let levelIndex = args.firstIndex(of: "--level"),
           levelIndex + 1 < args.count {
            level = args[levelIndex + 1]
        }

        return ScheduleInfo(
            frequency: frequency.rawValue,
            level: level,
            enabled: isEnabled,
            timeDescription: timeDescription,
            plistPath: path.path
        )
    }

    private func isScheduleLoaded(label: String) -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", label]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func generatePlistContent(for config: ScheduleConfig) -> String {
        var calendarInterval = ""

        switch config.frequency {
        case .daily:
            calendarInterval = """
                <key>StartCalendarInterval</key>
                <dict>
                    <key>Hour</key>
                    <integer>\(config.hour)</integer>
                    <key>Minute</key>
                    <integer>\(config.minute)</integer>
                </dict>
            """

        case .weekly:
            let weekday = config.weekday ?? 0
            calendarInterval = """
                <key>StartCalendarInterval</key>
                <dict>
                    <key>Weekday</key>
                    <integer>\(weekday)</integer>
                    <key>Hour</key>
                    <integer>\(config.hour)</integer>
                    <key>Minute</key>
                    <integer>\(config.minute)</integer>
                </dict>
            """

        case .monthly:
            let day = config.day ?? 1
            calendarInterval = """
                <key>StartCalendarInterval</key>
                <dict>
                    <key>Day</key>
                    <integer>\(day)</integer>
                    <key>Hour</key>
                    <integer>\(config.hour)</integer>
                    <key>Minute</key>
                    <integer>\(config.minute)</integer>
                </dict>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier).\(config.frequency.rawValue)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/osxcleaner</string>
                <string>clean</string>
                <string>--level</string>
                <string>\(config.level.rawValue)</string>
                <string>--non-interactive</string>
            </array>
            \(calendarInterval)
            <key>StandardOutPath</key>
            <string>/tmp/osxcleaner-\(config.frequency.rawValue).log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/osxcleaner-\(config.frequency.rawValue).err</string>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
    }
}

// MARK: - Schedule Types

struct ScheduleConfig {
    let frequency: ScheduleFrequency
    let level: CleanupLevel
    let hour: Int
    let minute: Int
    let weekday: Int?
    let day: Int?

    var plistName: String {
        "com.osxcleaner.\(frequency.rawValue).plist"
    }
}

struct ScheduleInfo: Codable {
    let frequency: String
    let level: String
    let enabled: Bool
    let timeDescription: String
    let plistPath: String

    enum CodingKeys: String, CodingKey {
        case frequency
        case level
        case enabled
        case timeDescription = "time_description"
        case plistPath = "plist_path"
    }
}

// MARK: - Schedule Errors

enum ScheduleError: LocalizedError {
    case invalidHour(Int)
    case invalidMinute(Int)
    case invalidWeekday(Int)
    case invalidDay(Int)
    case scheduleNotFound(String)
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHour(let hour):
            return "Invalid hour: \(hour). Must be 0-23."
        case .invalidMinute(let minute):
            return "Invalid minute: \(minute). Must be 0-59."
        case .invalidWeekday(let weekday):
            return "Invalid weekday: \(weekday). Must be 0-6 (0=Sunday)."
        case .invalidDay(let day):
            return "Invalid day: \(day). Must be 1-31."
        case .scheduleNotFound(let frequency):
            return "Schedule not found: \(frequency)"
        case .launchctlFailed(let operation):
            return "launchctl \(operation) failed"
        }
    }
}

// MARK: - CleanupLevel Extension

extension CleanupLevel {
    var rawValue: String {
        switch self {
        case .light:
            return "light"
        case .normal:
            return "normal"
        case .deep:
            return "deep"
        case .system:
            return "system"
        }
    }
}

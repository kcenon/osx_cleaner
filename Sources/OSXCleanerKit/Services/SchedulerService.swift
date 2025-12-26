// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - Schedule Types

/// Frequency options for scheduled cleanup
public enum ScheduleFrequency: String, CaseIterable, Codable {
    case daily
    case weekly
    case monthly
}

/// Configuration for a scheduled cleanup
public struct ScheduleConfig: Codable {
    public let frequency: ScheduleFrequency
    public let levelString: String
    public let hour: Int
    public let minute: Int
    public let weekday: Int?
    public let day: Int?

    public var level: CleanupLevel {
        CleanupLevel.from(string: levelString) ?? .normal
    }

    public init(
        frequency: ScheduleFrequency,
        level: CleanupLevel,
        hour: Int,
        minute: Int,
        weekday: Int? = nil,
        day: Int? = nil
    ) {
        self.frequency = frequency
        self.levelString = level.stringValue
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.day = day
    }

    public var plistName: String {
        "com.osxcleaner.\(frequency.rawValue).plist"
    }

    public var label: String {
        "com.osxcleaner.\(frequency.rawValue)"
    }

    /// Time description for display
    public var timeDescription: String {
        var description = String(format: "%02d:%02d", hour, minute)

        if frequency == .weekly, let weekday = weekday {
            let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            if (0...6).contains(weekday) {
                description += " on \(days[weekday])"
            }
        }

        if frequency == .monthly, let day = day {
            description += " on day \(day)"
        }

        return description
    }

    enum CodingKeys: String, CodingKey {
        case frequency
        case levelString = "level"
        case hour
        case minute
        case weekday
        case day
    }
}

/// Information about an existing schedule
public struct ScheduleInfo: Codable {
    public let frequency: String
    public let level: String
    public let enabled: Bool
    public let timeDescription: String
    public let plistPath: String

    public init(
        frequency: String,
        level: String,
        enabled: Bool,
        timeDescription: String,
        plistPath: String
    ) {
        self.frequency = frequency
        self.level = level
        self.enabled = enabled
        self.timeDescription = timeDescription
        self.plistPath = plistPath
    }

    enum CodingKeys: String, CodingKey {
        case frequency
        case level
        case enabled
        case timeDescription = "time_description"
        case plistPath = "plist_path"
    }
}

// MARK: - Schedule Errors

public enum ScheduleError: LocalizedError {
    case invalidHour(Int)
    case invalidMinute(Int)
    case invalidWeekday(Int)
    case invalidDay(Int)
    case scheduleNotFound(String)
    case launchctlFailed(String)
    case fileOperationFailed(String)

    public var errorDescription: String? {
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
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        }
    }
}

// MARK: - Scheduler Service

/// Service for managing launchd-based cleanup schedules
///
/// Provides functionality to create, list, enable, disable, and remove
/// scheduled cleanup jobs using macOS launchd.
public final class SchedulerService {

    // MARK: - Properties

    private let fileManager: FileManager
    private let bundleIdentifier: String

    public var launchAgentsPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        bundleIdentifier: String = "com.osxcleaner"
    ) {
        self.fileManager = fileManager
        self.bundleIdentifier = bundleIdentifier
    }

    // MARK: - Schedule Management

    /// List all configured schedules
    public func listSchedules() -> [ScheduleInfo] {
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

    /// Create a new schedule
    public func createSchedule(_ config: ScheduleConfig) throws {
        // Validate configuration
        try validateConfig(config)

        // Ensure LaunchAgents directory exists
        try fileManager.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)

        let plistPath = launchAgentsPath.appendingPathComponent(config.plistName)
        let plistContent = generatePlistContent(for: config)

        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)

        AppLogger.shared.info("Created schedule: \(config.plistName)")
    }

    /// Remove a schedule
    public func removeSchedule(_ frequency: ScheduleFrequency) throws {
        // First disable the schedule
        try disableSchedule(frequency)

        let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
        let plistPath = launchAgentsPath.appendingPathComponent(plistName)

        if fileManager.fileExists(atPath: plistPath.path) {
            try fileManager.removeItem(at: plistPath)
            AppLogger.shared.info("Removed schedule: \(frequency.rawValue)")
        }
    }

    /// Enable a schedule (load with launchctl)
    public func enableSchedule(_ frequency: ScheduleFrequency) throws {
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

        AppLogger.shared.info("Enabled schedule: \(frequency.rawValue)")
    }

    /// Disable a schedule (unload with launchctl)
    public func disableSchedule(_ frequency: ScheduleFrequency) throws {
        let plistName = "\(bundleIdentifier).\(frequency.rawValue).plist"
        let plistPath = launchAgentsPath.appendingPathComponent(plistName)

        guard fileManager.fileExists(atPath: plistPath.path) else {
            return  // Already disabled or not exists
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]

        try process.run()
        process.waitUntilExit()
        // Ignore exit status for unload - it may fail if not loaded

        AppLogger.shared.info("Disabled schedule: \(frequency.rawValue)")
    }

    /// Check if a schedule is currently loaded
    public func isScheduleLoaded(_ frequency: ScheduleFrequency) -> Bool {
        let label = "\(bundleIdentifier).\(frequency.rawValue)"
        return isAgentLoaded(label: label)
    }

    // MARK: - Validation

    /// Validate schedule configuration
    public func validateConfig(_ config: ScheduleConfig) throws {
        guard (0...23).contains(config.hour) else {
            throw ScheduleError.invalidHour(config.hour)
        }

        guard (0...59).contains(config.minute) else {
            throw ScheduleError.invalidMinute(config.minute)
        }

        if config.frequency == .weekly {
            if let weekday = config.weekday, !(0...6).contains(weekday) {
                throw ScheduleError.invalidWeekday(weekday)
            }
        }

        if config.frequency == .monthly {
            if let day = config.day, !(1...31).contains(day) {
                throw ScheduleError.invalidDay(day)
            }
        }
    }

    // MARK: - Private Helpers

    private func parseScheduleInfo(from path: URL, frequency: ScheduleFrequency) -> ScheduleInfo? {
        guard let data = fileManager.contents(atPath: path.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? ""
        let isEnabled = isAgentLoaded(label: label)

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

    private func isAgentLoaded(label: String) -> Bool {
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

    /// Generate launchd plist content for a schedule
    public func generatePlistContent(for config: ScheduleConfig) -> String {
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
                <string>\(config.level.stringValue)</string>
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

// MARK: - CleanupLevel Extension

extension CleanupLevel {
    /// String representation for serialization
    public var stringValue: String {
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

    /// Create from string representation
    public static func from(string: String) -> CleanupLevel? {
        switch string.lowercased() {
        case "light":
            return .light
        case "normal":
            return .normal
        case "deep":
            return .deep
        case "system":
            return .system
        default:
            return nil
        }
    }
}

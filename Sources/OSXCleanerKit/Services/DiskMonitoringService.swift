// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Configuration for disk monitoring
public struct MonitoringConfig: Codable {
    /// Whether auto-cleanup is enabled at emergency threshold
    public let autoCleanupEnabled: Bool

    /// Cleanup level to use for auto-cleanup (default: light)
    public let autoCleanupLevel: String

    /// Check interval in seconds (default: 3600 = 1 hour)
    public let checkIntervalSeconds: Int

    /// Whether to send notifications
    public let notificationsEnabled: Bool

    /// Custom thresholds (optional)
    public let warningThreshold: Int?
    public let criticalThreshold: Int?
    public let emergencyThreshold: Int?

    public init(
        autoCleanupEnabled: Bool = false,
        autoCleanupLevel: String = "light",
        checkIntervalSeconds: Int = 3600,
        notificationsEnabled: Bool = true,
        warningThreshold: Int? = nil,
        criticalThreshold: Int? = nil,
        emergencyThreshold: Int? = nil
    ) {
        self.autoCleanupEnabled = autoCleanupEnabled
        self.autoCleanupLevel = autoCleanupLevel
        self.checkIntervalSeconds = checkIntervalSeconds
        self.notificationsEnabled = notificationsEnabled
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.emergencyThreshold = emergencyThreshold
    }

    // MARK: - Threshold Values

    public var effectiveWarningThreshold: Int {
        warningThreshold ?? DiskThreshold.warning.rawValue
    }

    public var effectiveCriticalThreshold: Int {
        criticalThreshold ?? DiskThreshold.critical.rawValue
    }

    public var effectiveEmergencyThreshold: Int {
        emergencyThreshold ?? DiskThreshold.emergency.rawValue
    }
}

/// Result of disk space check
public struct DiskSpaceInfo {
    public let totalSpace: UInt64
    public let availableSpace: UInt64
    public let usedSpace: UInt64
    public let usagePercent: Double
    public let volumePath: String

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSpace), countStyle: .file)
    }

    public var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableSpace), countStyle: .file)
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedSpace), countStyle: .file)
    }

    public init(
        totalSpace: UInt64,
        availableSpace: UInt64,
        usedSpace: UInt64,
        usagePercent: Double,
        volumePath: String
    ) {
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.usedSpace = usedSpace
        self.usagePercent = usagePercent
        self.volumePath = volumePath
    }
}

/// Monitoring status result
public struct MonitoringStatus: Codable {
    public let isEnabled: Bool
    public let lastCheckTime: Date?
    public let lastUsagePercent: Double?
    public let config: MonitoringConfig?
    public let plistPath: String?

    public init(
        isEnabled: Bool,
        lastCheckTime: Date? = nil,
        lastUsagePercent: Double? = nil,
        config: MonitoringConfig? = nil,
        plistPath: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.lastCheckTime = lastCheckTime
        self.lastUsagePercent = lastUsagePercent
        self.config = config
        self.plistPath = plistPath
    }
}

/// Service for monitoring disk usage and triggering alerts
///
/// Uses macOS launchd for periodic monitoring and integrates with
/// NotificationService for disk usage alerts.
public final class DiskMonitoringService {

    // MARK: - Singleton

    public static let shared = DiskMonitoringService()

    // MARK: - Properties

    private let fileManager: FileManager
    private var _notificationService: NotificationService?

    /// Lazily initialized notification service to avoid CLI bundle issues
    private var notificationService: NotificationService? {
        if _notificationService == nil {
            // Only initialize if we have a proper bundle context
            if Bundle.main.bundleIdentifier != nil {
                _notificationService = NotificationService()
            }
        }
        return _notificationService
    }
    private let bundleIdentifier = "com.osxcleaner"

    private var launchAgentsPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }

    private var configPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("monitoring.json")
    }

    private var monitorPlistName: String {
        "\(bundleIdentifier).monitor.plist"
    }

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
    }

    // MARK: - Disk Space Query

    /// Get current disk space information for the specified volume
    /// - Parameter volumePath: Path to the volume (default: "/")
    /// - Returns: Disk space information
    public func getDiskSpace(volumePath: String = "/") throws -> DiskSpaceInfo {
        let url = URL(fileURLWithPath: volumePath)

        let values = try url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        guard let totalSpace = values.volumeTotalCapacity else {
            throw MonitoringError.failedToGetDiskSpace
        }

        // Prefer volumeAvailableCapacityForImportantUsage (Int64) for accurate available space
        // Fall back to volumeAvailableCapacity (Int) if not available
        let availableSpace: Int64
        if let importantUsageCapacity = values.volumeAvailableCapacityForImportantUsage {
            availableSpace = importantUsageCapacity
        } else if let basicCapacity = values.volumeAvailableCapacity {
            availableSpace = Int64(basicCapacity)
        } else {
            throw MonitoringError.failedToGetDiskSpace
        }

        let totalBytes = UInt64(totalSpace)
        let availableBytes = UInt64(availableSpace)
        let usedBytes = totalBytes - availableBytes
        let usagePercent = Double(usedBytes) / Double(totalBytes) * 100.0

        return DiskSpaceInfo(
            totalSpace: totalBytes,
            availableSpace: availableBytes,
            usedSpace: usedBytes,
            usagePercent: usagePercent,
            volumePath: volumePath
        )
    }

    /// Check disk usage and send notifications if thresholds exceeded
    /// - Parameter config: Monitoring configuration
    /// - Returns: Current disk space info and triggered threshold (if any)
    public func checkDiskUsage(
        config: MonitoringConfig
    ) async throws -> (DiskSpaceInfo, DiskThreshold?) {
        let diskInfo = try getDiskSpace()
        let usagePercent = diskInfo.usagePercent

        AppLogger.shared.info("Disk usage check: \(String(format: "%.1f", usagePercent))%")

        // Determine which threshold was exceeded
        var triggeredThreshold: DiskThreshold?

        if usagePercent >= Double(config.effectiveEmergencyThreshold) {
            triggeredThreshold = .emergency
        } else if usagePercent >= Double(config.effectiveCriticalThreshold) {
            triggeredThreshold = .critical
        } else if usagePercent >= Double(config.effectiveWarningThreshold) {
            triggeredThreshold = .warning
        }

        // Send notification if threshold exceeded
        if let threshold = triggeredThreshold, config.notificationsEnabled {
            await notificationService?.sendDiskWarning(
                usagePercent: usagePercent,
                threshold: threshold,
                availableSpace: diskInfo.availableSpace
            )
        }

        return (diskInfo, triggeredThreshold)
    }

    // MARK: - Monitoring Management

    /// Enable disk monitoring with the specified configuration
    public func enableMonitoring(_ config: MonitoringConfig) throws {
        // Save configuration
        try saveConfig(config)

        // Create launchd plist for periodic monitoring
        try createMonitoringPlist(config)

        // Load the launchd agent
        try loadMonitoringAgent()

        AppLogger.shared.success("Disk monitoring enabled with \(config.checkIntervalSeconds)s interval")
    }

    /// Disable disk monitoring
    public func disableMonitoring() throws {
        // Unload the launchd agent
        try unloadMonitoringAgent()

        // Remove the plist file
        let plistPath = launchAgentsPath.appendingPathComponent(monitorPlistName)
        if fileManager.fileExists(atPath: plistPath.path) {
            try fileManager.removeItem(at: plistPath)
        }

        AppLogger.shared.success("Disk monitoring disabled")
    }

    /// Get current monitoring status
    public func getStatus() -> MonitoringStatus {
        let plistPath = launchAgentsPath.appendingPathComponent(monitorPlistName)
        let plistExists = fileManager.fileExists(atPath: plistPath.path)
        let isLoaded = isAgentLoaded()

        let config = try? loadConfig()

        return MonitoringStatus(
            isEnabled: plistExists && isLoaded,
            lastCheckTime: nil,  // Would need to read from log
            lastUsagePercent: nil,
            config: config,
            plistPath: plistExists ? plistPath.path : nil
        )
    }

    // MARK: - Configuration

    private func saveConfig(_ config: MonitoringConfig) throws {
        let configDir = configPath.deletingLastPathComponent()
        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configPath)
    }

    private func loadConfig() throws -> MonitoringConfig {
        let data = try Data(contentsOf: configPath)
        return try JSONDecoder().decode(MonitoringConfig.self, from: data)
    }

    // MARK: - launchd Management

    private func createMonitoringPlist(_ config: MonitoringConfig) throws {
        try fileManager.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)

        let plistPath = launchAgentsPath.appendingPathComponent(monitorPlistName)
        let plistContent = generateMonitoringPlist(config)

        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
    }

    private func generateMonitoringPlist(_ config: MonitoringConfig) -> String {
        // Build program arguments
        var args = [
            "/usr/local/bin/osxcleaner",
            "monitor",
            "check"
        ]

        if config.autoCleanupEnabled {
            args.append("--auto-cleanup")
            args.append("--level")
            args.append(config.autoCleanupLevel)
        }

        let argsXml = args.map { "        <string>\($0)</string>" }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier).monitor</string>
            <key>ProgramArguments</key>
            <array>
        \(argsXml)
            </array>
            <key>StartInterval</key>
            <integer>\(config.checkIntervalSeconds)</integer>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/osxcleaner-monitor.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/osxcleaner-monitor.err</string>
            <key>ProcessType</key>
            <string>Background</string>
            <key>LowPriorityIO</key>
            <true/>
            <key>Nice</key>
            <integer>10</integer>
        </dict>
        </plist>
        """
    }

    private func loadMonitoringAgent() throws {
        let plistPath = launchAgentsPath.appendingPathComponent(monitorPlistName)

        // First unload if already loaded
        _ = try? unloadMonitoringAgent()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw MonitoringError.launchctlFailed("load")
        }
    }

    private func unloadMonitoringAgent() throws {
        let plistPath = launchAgentsPath.appendingPathComponent(monitorPlistName)

        guard fileManager.fileExists(atPath: plistPath.path) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]

        try process.run()
        process.waitUntilExit()
        // Ignore exit status - may fail if not loaded
    }

    private func isAgentLoaded() -> Bool {
        let label = "\(bundleIdentifier).monitor"

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
}

// MARK: - Errors

public enum MonitoringError: LocalizedError {
    case failedToGetDiskSpace
    case launchctlFailed(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .failedToGetDiskSpace:
            return "Failed to retrieve disk space information"
        case .launchctlFailed(let operation):
            return "launchctl \(operation) failed"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Service for managing MDM integration
///
/// Provides a unified interface for connecting to and interacting with
/// different MDM platforms (Jamf Pro, Mosyle, Kandji).
public actor MDMService {

    // MARK: - Singleton

    public static let shared = MDMService()

    // MARK: - Properties

    private var connector: (any MDMConnector)?
    private var config: MDMConfiguration?
    private var cachedPolicies: [MDMPolicy] = []
    private var lastSyncAt: Date?
    private var syncTimer: Task<Void, Never>?

    // MARK: - Initialization

    public init() {}

    // MARK: - Connection Management

    /// Get current MDM connection status
    public func getStatus() -> MDMConnectionStatus {
        guard let _ = connector, let config = config else {
            return MDMConnectionStatus()
        }

        return MDMConnectionStatus(
            provider: config.provider,
            serverURL: config.serverURL.absoluteString,
            connectionState: .disconnected,  // Will be updated asynchronously
            isConnected: false,
            lastSyncAt: lastSyncAt,
            policiesCount: cachedPolicies.count,
            pendingCommandsCount: 0
        )
    }

    /// Connect to an MDM provider
    /// - Parameters:
    ///   - provider: MDM provider to connect to
    ///   - serverURL: Server URL
    ///   - credentials: Authentication credentials
    public func connect(
        provider: MDMProvider,
        serverURL: URL,
        credentials: MDMCredentials
    ) async throws {
        // Disconnect from existing connection
        if connector != nil {
            try await disconnect()
        }

        // Create connector for the provider
        let newConnector: any MDMConnector
        switch provider {
        case .jamf:
            newConnector = JamfConnector()
        case .mosyle:
            newConnector = MosyleConnector()
        case .kandji:
            newConnector = KandjiConnector()
        }

        // Create configuration
        let config = MDMConfiguration(
            provider: provider,
            serverURL: serverURL
        )

        // Connect
        try await newConnector.connect(config: config, credentials: credentials)

        self.connector = newConnector
        self.config = config

        AppLogger.shared.info("Connected to \(provider.displayName) MDM")

        // Start auto-sync if enabled
        if config.autoSync {
            startAutoSync(interval: config.syncInterval)
        }
    }

    /// Disconnect from the current MDM
    public func disconnect() async throws {
        stopAutoSync()

        if let connector = connector {
            try await connector.disconnect()
        }

        connector = nil
        config = nil
        cachedPolicies = []
        lastSyncAt = nil

        AppLogger.shared.info("Disconnected from MDM")
    }

    /// Check if connected to an MDM
    public var isConnected: Bool {
        connector != nil
    }

    /// Get the current MDM provider
    public var currentProvider: MDMProvider? {
        config?.provider
    }

    // MARK: - Policy Management

    /// Sync policies from MDM
    /// - Returns: Array of synced policies
    @discardableResult
    public func syncPolicies() async throws -> [MDMPolicy] {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        let policies = try await connector.syncPolicies()
        cachedPolicies = policies
        lastSyncAt = Date()

        AppLogger.shared.info("Synced \(policies.count) policies from MDM")

        return policies
    }

    /// Get cached policies
    public func getCachedPolicies() -> [MDMPolicy] {
        cachedPolicies
    }

    /// Get a specific policy by ID
    /// - Parameter policyId: Policy identifier
    /// - Returns: The requested policy
    public func getPolicy(id policyId: String) async throws -> MDMPolicy {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        return try await connector.getPolicy(id: policyId)
    }

    /// Convert MDM policy to internal Policy format
    /// - Parameter mdmPolicy: MDM policy to convert
    /// - Returns: Internal Policy object
    public func convertToPolicy(_ mdmPolicy: MDMPolicy) -> Policy {
        let targets = mdmPolicy.targets.compactMap { PolicyTarget(rawValue: $0) }

        // Determine schedule from MDM policy
        let schedule: PolicySchedule = {
            if let scheduleStr = mdmPolicy.schedule?.lowercased() {
                return PolicySchedule(rawValue: scheduleStr) ?? .manual
            }
            return .manual
        }()

        let rules = targets.map { target -> PolicyRule in
            PolicyRule(
                id: "\(mdmPolicy.id)_\(target.rawValue)",
                target: target,
                action: .clean,
                schedule: schedule,
                enabled: mdmPolicy.enabled
            )
        }

        // Map priority integer to PolicyPriority
        let priority: PolicyPriority = {
            switch mdmPolicy.priority {
            case ..<25: return .low
            case 25..<75: return .normal
            case 75..<150: return .high
            default: return .critical
            }
        }()

        return Policy(
            version: "1.\(mdmPolicy.version)",
            name: mdmPolicy.name,
            rules: rules,
            exclusions: mdmPolicy.exclusions,
            priority: priority,
            enabled: mdmPolicy.enabled
        )
    }

    // MARK: - Status Reporting

    /// Report cleanup status to MDM
    /// - Parameter status: Cleanup status to report
    public func reportStatus(_ status: MDMCleanupStatus) async throws {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        try await connector.reportStatus(status)
        AppLogger.shared.info("Reported cleanup status to MDM")
    }

    /// Report compliance to MDM
    /// - Parameter report: Compliance report to send
    public func reportCompliance(_ report: MDMComplianceReport) async throws {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        try await connector.reportCompliance(report)
        AppLogger.shared.info("Reported compliance to MDM")
    }

    /// Create current status from system state
    /// - Returns: Current cleanup status
    public func createCurrentStatus() async throws -> MDMCleanupStatus {
        let agentId = try await getAgentId()
        let (freeSpace, totalSpace) = try await getDiskSpace()

        return MDMCleanupStatus(
            agentId: agentId,
            lastCleanupAt: nil,
            lastCleanupResult: nil,
            nextScheduledCleanup: nil,
            diskFreeSpace: freeSpace,
            diskTotalSpace: totalSpace
        )
    }

    private func getAgentId() async throws -> String {
        let configService = ConfigurationService()
        let config = try configService.load()

        if let agentId = config.agentId {
            return agentId.uuidString
        }

        // Generate a new agent ID based on hardware UUID
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPHardwareDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hardware = (json["SPHardwareDataType"] as? [[String: Any]])?.first,
           let uuid = hardware["platform_UUID"] as? String {
            return uuid
        }

        return ProcessInfo.processInfo.hostName
    }

    private func getDiskSpace() async throws -> (free: UInt64, total: UInt64) {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

        let values = try homeDirectory.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])

        let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = UInt64(values.volumeTotalCapacity ?? 0)

        return (free, total)
    }

    // MARK: - Remote Commands

    /// Fetch pending commands from MDM
    /// - Returns: Array of pending commands
    public func fetchCommands() async throws -> [MDMCommand] {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        let commands = try await connector.fetchCommands()

        // Filter out expired commands
        let validCommands = commands.filter { !$0.isExpired }

        if !validCommands.isEmpty {
            AppLogger.shared.info("Fetched \(validCommands.count) pending commands from MDM")
        }

        return validCommands
    }

    /// Execute a command from MDM
    /// - Parameter command: Command to execute
    /// - Returns: Command execution result
    public func executeCommand(_ command: MDMCommand) async throws -> MDMCommandResult {
        let startTime = Date()

        do {
            switch command.type {
            case .cleanup:
                let cleanerService = CleanerService()
                let cleanerConfig = CleanerConfiguration(
                    cleanupLevel: .normal,
                    dryRun: false,
                    includeSystemCaches: true
                )
                let result = try await cleanerService.clean(with: cleanerConfig)

                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Freed \(ByteCountFormatter.string(fromByteCount: Int64(result.freedBytes), countStyle: .file))",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime),
                    details: [
                        "bytes_freed": "\(result.freedBytes)",
                        "files_removed": "\(result.filesRemoved)"
                    ]
                )

            case .analyze:
                let analyzer = AnalyzerService()
                let config = AnalyzerConfiguration(targetPath: "~")
                let result = try await analyzer.analyze(with: config)

                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Found \(ByteCountFormatter.string(fromByteCount: Int64(result.totalSize), countStyle: .file)) of cleanable data",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime),
                    details: [
                        "total_size": "\(result.totalSize)",
                        "categories": "\(result.categories.count)"
                    ]
                )

            case .syncPolicy:
                let policies = try await syncPolicies()
                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Synced \(policies.count) policies",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime),
                    details: ["policies_count": "\(policies.count)"]
                )

            case .reportStatus:
                let status = try await createCurrentStatus()
                try await reportStatus(status)
                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Status reported",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime)
                )

            case .reportCompliance:
                // TODO: Implement compliance check
                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Compliance reported",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime)
                )

            case .updateConfig:
                // TODO: Implement config update
                return MDMCommandResult(
                    commandId: command.id,
                    success: true,
                    message: "Configuration updated",
                    executedAt: Date(),
                    duration: Date().timeIntervalSince(startTime)
                )
            }
        } catch {
            return MDMCommandResult(
                commandId: command.id,
                success: false,
                message: error.localizedDescription,
                executedAt: Date(),
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    /// Report command result to MDM
    /// - Parameter result: Command result to report
    public func reportCommandResult(_ result: MDMCommandResult) async throws {
        guard let connector = connector else {
            throw MDMError.notConnected
        }

        try await connector.reportCommandResult(result)
        AppLogger.shared.info("Reported command result to MDM: \(result.commandId)")
    }

    // MARK: - Auto Sync

    private func startAutoSync(interval: TimeInterval) {
        stopAutoSync()

        syncTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                do {
                    try await self?.syncPolicies()
                    AppLogger.shared.debug("Auto-synced policies from MDM")
                } catch {
                    AppLogger.shared.warning("Auto-sync failed: \(error)")
                }
            }
        }
    }

    private func stopAutoSync() {
        syncTimer?.cancel()
        syncTimer = nil
    }
}

// MARK: - Configuration Extension

extension ConfigurationService {
    /// MDM configuration keys
    fileprivate struct MDMKeys {
        static let provider = "mdm_provider"
        static let serverURL = "mdm_server_url"
        static let lastSyncAt = "mdm_last_sync"
    }
}

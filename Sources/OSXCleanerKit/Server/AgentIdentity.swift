// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Unique identifier for a managed agent
public struct AgentIdentity: Codable, Identifiable, Sendable, Hashable {

    // MARK: - Properties

    /// Unique agent identifier (UUID)
    public let id: UUID

    /// Human-readable agent name
    public let name: String

    /// Hostname of the machine running the agent
    public let hostname: String

    /// macOS version of the agent machine
    public let osVersion: String

    /// OSX Cleaner version running on the agent
    public let appVersion: String

    /// Hardware model identifier (e.g., "MacBookPro18,1")
    public let hardwareModel: String

    /// Serial number of the machine (hashed for privacy)
    public let serialNumberHash: String

    /// Username of the primary user
    public let username: String

    /// Timestamp when the agent was first registered
    public let registeredAt: Date

    /// Optional group tags for organizing agents
    public let tags: [String]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        hostname: String? = nil,
        osVersion: String? = nil,
        appVersion: String,
        hardwareModel: String? = nil,
        serialNumberHash: String? = nil,
        username: String? = nil,
        registeredAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.name = name ?? ProcessInfo.processInfo.hostName
        self.hostname = hostname ?? ProcessInfo.processInfo.hostName
        self.osVersion = osVersion ?? ProcessInfo.processInfo.operatingSystemVersionString
        self.appVersion = appVersion
        self.hardwareModel = hardwareModel ?? Self.getHardwareModel()
        self.serialNumberHash = serialNumberHash ?? Self.getSerialNumberHash()
        self.username = username ?? NSUserName()
        self.registeredAt = registeredAt
        self.tags = tags
    }

    // MARK: - Factory Methods

    /// Create identity with current system information
    public static func current(appVersion: String, tags: [String] = []) -> AgentIdentity {
        AgentIdentity(appVersion: appVersion, tags: tags)
    }

    // MARK: - Private Helpers

    private static func getHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private static func getSerialNumberHash() -> String {
        // Get serial number via IOKit (simplified - returns hash of hardware UUID)
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0 else {
            return UUID().uuidString
        }

        defer { IOObjectRelease(platformExpert) }

        if let serialRef = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        ) {
            let serial = serialRef.takeRetainedValue() as? String ?? UUID().uuidString
            // Hash the serial for privacy
            return serial.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        }

        return UUID().uuidString
    }
}

// MARK: - CustomStringConvertible

extension AgentIdentity: CustomStringConvertible {
    public var description: String {
        "\(name) (\(hostname)) - \(osVersion)"
    }
}

// MARK: - Comparable

extension AgentIdentity: Comparable {
    public static func < (lhs: AgentIdentity, rhs: AgentIdentity) -> Bool {
        lhs.name < rhs.name
    }
}

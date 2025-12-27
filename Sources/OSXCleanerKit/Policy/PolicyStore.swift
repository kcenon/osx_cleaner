// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during policy store operations
public enum PolicyStoreError: LocalizedError {
    case policyNotFound(String)
    case policyAlreadyExists(String)
    case invalidPolicyFile(String)
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    case directoryCreationFailed(String)
    case validationFailed([PolicyValidationError])

    public var errorDescription: String? {
        switch self {
        case .policyNotFound(let name):
            return "Policy not found: '\(name)'"
        case .policyAlreadyExists(let name):
            return "Policy already exists: '\(name)'"
        case .invalidPolicyFile(let path):
            return "Invalid policy file: '\(path)'"
        case .saveFailed(let message):
            return "Failed to save policy: \(message)"
        case .loadFailed(let message):
            return "Failed to load policy: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete policy: \(message)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: '\(path)'"
        case .validationFailed(let errors):
            let messages = errors.map { $0.errorDescription ?? "Unknown error" }
            return "Policy validation failed:\n" + messages.joined(separator: "\n")
        }
    }
}

/// Configuration for the policy store
public struct PolicyStoreConfig: Sendable {
    /// Directory to store policies
    public let policyDirectory: URL

    /// Whether to validate policies on load
    public let validateOnLoad: Bool

    /// Whether to create sample policies if none exist
    public let createSamplePolicies: Bool

    public init(
        policyDirectory: URL? = nil,
        validateOnLoad: Bool = true,
        createSamplePolicies: Bool = true
    ) {
        if let dir = policyDirectory {
            self.policyDirectory = dir
        } else {
            self.policyDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config")
                .appendingPathComponent("osxcleaner")
                .appendingPathComponent("policies")
        }
        self.validateOnLoad = validateOnLoad
        self.createSamplePolicies = createSamplePolicies
    }
}

/// File-based policy storage and management
public final class PolicyStore: @unchecked Sendable {

    // MARK: - Properties

    private let config: PolicyStoreConfig
    private let validator: PolicyValidator
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue: DispatchQueue

    /// Cached policies
    private var policyCache: [String: Policy] = [:]
    private var cacheValid: Bool = false

    // MARK: - Initialization

    public init(config: PolicyStoreConfig = PolicyStoreConfig()) throws {
        self.config = config
        self.validator = PolicyValidator()
        self.fileManager = FileManager.default
        self.queue = DispatchQueue(label: "com.osxcleaner.policy-store", qos: .utility)

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        try createDirectoryIfNeeded()

        if config.createSamplePolicies {
            try createSamplePoliciesIfNeeded()
        }
    }

    // MARK: - Directory Management

    private func createDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: config.policyDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: config.policyDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                throw PolicyStoreError.directoryCreationFailed(config.policyDirectory.path)
            }
        }
    }

    private func createSamplePoliciesIfNeeded() throws {
        let existingPolicies = try listPolicyFiles()
        guard existingPolicies.isEmpty else { return }

        // Create sample policies
        let samplePolicies: [Policy] = [
            .personalDefault,
            .developerStandard
        ]

        for policy in samplePolicies {
            try save(policy, overwrite: true)
        }

        AppLogger.shared.info("Created \(samplePolicies.count) sample policies")
    }

    // MARK: - File Path Helpers

    private func policyPath(for name: String) -> URL {
        config.policyDirectory.appendingPathComponent("\(name).json")
    }

    private func listPolicyFiles() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: config.policyDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" }
    }

    // MARK: - CRUD Operations

    /// List all available policies
    public func list() throws -> [Policy] {
        try queue.sync {
            if cacheValid {
                return Array(policyCache.values).sorted { $0.priority > $1.priority }
            }

            let files = try listPolicyFiles()
            var policies: [Policy] = []

            for file in files {
                do {
                    let policy = try loadPolicy(from: file)
                    policyCache[policy.name] = policy
                    policies.append(policy)
                } catch {
                    AppLogger.shared.warning("Failed to load policy from \(file.lastPathComponent): \(error)")
                }
            }

            cacheValid = true
            return policies.sorted { $0.priority > $1.priority }
        }
    }

    /// Get a specific policy by name
    public func get(_ name: String) throws -> Policy {
        try queue.sync {
            if let cached = policyCache[name] {
                return cached
            }

            let path = policyPath(for: name)
            guard fileManager.fileExists(atPath: path.path) else {
                throw PolicyStoreError.policyNotFound(name)
            }

            let policy = try loadPolicy(from: path)
            policyCache[name] = policy
            return policy
        }
    }

    /// Save a policy to disk
    public func save(_ policy: Policy, overwrite: Bool = false) throws {
        try queue.sync {
            let path = policyPath(for: policy.name)

            // Check for existing policy
            if !overwrite && fileManager.fileExists(atPath: path.path) {
                throw PolicyStoreError.policyAlreadyExists(policy.name)
            }

            // Validate policy
            if config.validateOnLoad {
                let result = validator.validate(policy)
                if !result.isValid {
                    throw PolicyStoreError.validationFailed(result.errors)
                }
            }

            // Update timestamp
            var updatedPolicy = policy
            updatedPolicy.updatedAt = Date()

            // Encode and save
            do {
                let data = try encoder.encode(updatedPolicy)
                try data.write(to: path)
                policyCache[policy.name] = updatedPolicy
                AppLogger.shared.info("Saved policy: \(policy.name)")
            } catch let error as EncodingError {
                throw PolicyStoreError.saveFailed("Encoding error: \(error)")
            } catch {
                throw PolicyStoreError.saveFailed(error.localizedDescription)
            }
        }
    }

    /// Delete a policy
    public func delete(_ name: String) throws {
        try queue.sync {
            let path = policyPath(for: name)

            guard fileManager.fileExists(atPath: path.path) else {
                throw PolicyStoreError.policyNotFound(name)
            }

            do {
                try fileManager.removeItem(at: path)
                policyCache.removeValue(forKey: name)
                AppLogger.shared.info("Deleted policy: \(name)")
            } catch {
                throw PolicyStoreError.deleteFailed(error.localizedDescription)
            }
        }
    }

    /// Check if a policy exists
    public func exists(_ name: String) -> Bool {
        let path = policyPath(for: name)
        return fileManager.fileExists(atPath: path.path)
    }

    /// Import a policy from a file path
    public func importPolicy(from path: URL, overwrite: Bool = false) throws -> Policy {
        guard fileManager.fileExists(atPath: path.path) else {
            throw PolicyStoreError.invalidPolicyFile(path.path)
        }

        let policy = try loadPolicy(from: path)
        try save(policy, overwrite: overwrite)
        return policy
    }

    /// Export a policy to a file path
    public func exportPolicy(_ name: String, to path: URL) throws {
        let policy = try get(name)

        do {
            let data = try encoder.encode(policy)
            try data.write(to: path)
            AppLogger.shared.info("Exported policy '\(name)' to \(path.path)")
        } catch {
            throw PolicyStoreError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Query Methods

    /// Get policies with a specific tag
    public func policies(withTag tag: String) throws -> [Policy] {
        try list().filter { $0.tags.contains(tag) }
    }

    /// Get policies with a specific schedule
    public func policies(forSchedule schedule: PolicySchedule) throws -> [Policy] {
        try list().filter { policy in
            policy.enabledRules.contains { $0.schedule == schedule }
        }
    }

    /// Get enabled policies only
    public func enabledPolicies() throws -> [Policy] {
        try list().filter { $0.enabled }
    }

    /// Get the policy directory path
    public func getPolicyDirectory() -> URL {
        config.policyDirectory
    }

    // MARK: - Cache Management

    /// Invalidate the policy cache
    public func invalidateCache() {
        queue.sync {
            policyCache.removeAll()
            cacheValid = false
        }
    }

    /// Reload all policies from disk
    public func reload() throws -> [Policy] {
        invalidateCache()
        return try list()
    }

    // MARK: - Private Methods

    private func loadPolicy(from path: URL) throws -> Policy {
        do {
            let data = try Data(contentsOf: path)
            let policy = try decoder.decode(Policy.self, from: data)

            if config.validateOnLoad {
                let result = validator.validate(policy)
                if !result.isValid {
                    throw PolicyStoreError.validationFailed(result.errors)
                }

                // Log warnings
                for warning in result.warnings {
                    AppLogger.shared.warning("Policy '\(policy.name)': \(warning)")
                }
            }

            return policy
        } catch let error as DecodingError {
            throw PolicyStoreError.loadFailed("Decoding error: \(error)")
        } catch let error as PolicyStoreError {
            throw error
        } catch {
            throw PolicyStoreError.loadFailed(error.localizedDescription)
        }
    }
}

// MARK: - Policy Merge Support

extension PolicyStore {
    /// Merge multiple policies into one
    public func merge(policies: [Policy], name: String) throws -> Policy {
        guard !policies.isEmpty else {
            throw PolicyStoreError.loadFailed("No policies to merge")
        }

        // Sort by priority (highest first)
        let sorted = policies.sorted { $0.priority > $1.priority }

        // Combine rules
        var allRules: [PolicyRule] = []
        var seenRuleIds: Set<String> = []

        for policy in sorted {
            for rule in policy.rules {
                if !seenRuleIds.contains(rule.id) {
                    allRules.append(rule)
                    seenRuleIds.insert(rule.id)
                }
            }
        }

        // Combine exclusions (union)
        let allExclusions = Array(Set(sorted.flatMap { $0.exclusions }))

        // Take highest priority settings
        let merged = Policy(
            name: name,
            displayName: "Merged: " + sorted.map { $0.name }.joined(separator: ", "),
            description: "Merged from: " + sorted.map { $0.name }.joined(separator: ", "),
            rules: allRules,
            exclusions: allExclusions,
            notifications: sorted.first?.notifications ?? true,
            priority: sorted.first?.priority ?? .normal,
            enabled: true,
            tags: Array(Set(sorted.flatMap { $0.tags }))
        )

        return merged
    }
}

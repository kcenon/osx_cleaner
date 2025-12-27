// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Errors that can occur during policy validation
public enum PolicyValidationError: LocalizedError, Equatable {
    case invalidVersion(String)
    case unsupportedVersion(String, required: String)
    case emptyPolicyName
    case invalidPolicyName(String)
    case duplicateRuleId(String)
    case emptyRuleId
    case invalidRuleId(String)
    case invalidDurationFormat(String)
    case invalidSizeFormat(String)
    case invalidHourRange(start: Int, end: Int)
    case invalidExclusionPattern(String)
    case noRulesDefined
    case circularDependency(String)
    case multipleErrors([PolicyValidationError])

    public var errorDescription: String? {
        switch self {
        case .invalidVersion(let version):
            return "Invalid policy version format: '\(version)'. Expected format: 'X.Y'"
        case .unsupportedVersion(let version, let required):
            return "Unsupported policy version: '\(version)'. Required: '\(required)' or higher"
        case .emptyPolicyName:
            return "Policy name cannot be empty"
        case .invalidPolicyName(let name):
            return "Invalid policy name: '\(name)'. Use lowercase letters, numbers, and hyphens only"
        case .duplicateRuleId(let id):
            return "Duplicate rule ID: '\(id)'"
        case .emptyRuleId:
            return "Rule ID cannot be empty"
        case .invalidRuleId(let id):
            return "Invalid rule ID: '\(id)'. Use lowercase letters, numbers, and hyphens only"
        case .invalidDurationFormat(let value):
            return "Invalid duration format: '\(value)'. Expected format: '7d', '30d', '1y'"
        case .invalidSizeFormat(let value):
            return "Invalid size format: '\(value)'. Expected format: '100MB', '10GB'"
        case .invalidHourRange(let start, let end):
            return "Invalid hour range: \(start)-\(end). Hours must be 0-23"
        case .invalidExclusionPattern(let pattern):
            return "Invalid exclusion pattern: '\(pattern)'"
        case .noRulesDefined:
            return "Policy must define at least one rule"
        case .circularDependency(let details):
            return "Circular dependency detected: \(details)"
        case .multipleErrors(let errors):
            return "Multiple validation errors:\n" + errors.map { "  - \($0.errorDescription ?? "")" }.joined(separator: "\n")
        }
    }
}

/// Result of policy validation
public struct PolicyValidationResult: Sendable {
    /// Whether the policy is valid
    public let isValid: Bool

    /// Validation errors (if any)
    public let errors: [PolicyValidationError]

    /// Validation warnings (non-fatal issues)
    public let warnings: [String]

    public init(isValid: Bool, errors: [PolicyValidationError] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }

    public static var valid: PolicyValidationResult {
        PolicyValidationResult(isValid: true)
    }

    public static func invalid(_ errors: [PolicyValidationError]) -> PolicyValidationResult {
        PolicyValidationResult(isValid: false, errors: errors)
    }
}

/// Validates policy structure and content
public struct PolicyValidator: Sendable {

    // MARK: - Validation Patterns

    /// Pattern for valid policy/rule names (lowercase alphanumeric with hyphens)
    private static let namePattern = "^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$"

    /// Pattern for duration strings (e.g., "7d", "30d", "1y")
    private static let durationPattern = "^(\\d+)(d|w|m|y)$"

    /// Pattern for size strings (e.g., "100MB", "10GB")
    private static let sizePattern = "^(\\d+(?:\\.\\d+)?)(KB|MB|GB|TB)$"

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Validate a complete policy
    public func validate(_ policy: Policy) -> PolicyValidationResult {
        var errors: [PolicyValidationError] = []
        var warnings: [String] = []

        // Validate version
        if let versionError = validateVersion(policy.version) {
            errors.append(versionError)
        }

        // Validate policy name
        if let nameError = validatePolicyName(policy.name) {
            errors.append(nameError)
        }

        // Validate rules
        if policy.rules.isEmpty {
            errors.append(.noRulesDefined)
        } else {
            let ruleErrors = validateRules(policy.rules)
            errors.append(contentsOf: ruleErrors)
        }

        // Validate exclusions
        let exclusionErrors = validateExclusions(policy.exclusions)
        errors.append(contentsOf: exclusionErrors)

        // Generate warnings
        warnings.append(contentsOf: generateWarnings(for: policy))

        if errors.isEmpty {
            return PolicyValidationResult(isValid: true, warnings: warnings)
        } else {
            return PolicyValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
    }

    /// Validate a single rule
    public func validate(_ rule: PolicyRule) -> PolicyValidationResult {
        var errors: [PolicyValidationError] = []

        // Validate rule ID
        if rule.id.isEmpty {
            errors.append(.emptyRuleId)
        } else if !isValidName(rule.id) {
            errors.append(.invalidRuleId(rule.id))
        }

        // Validate conditions if present
        if let conditions = rule.conditions {
            let conditionErrors = validateConditions(conditions)
            errors.append(contentsOf: conditionErrors)
        }

        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors)
        }
    }

    // MARK: - Private Validation Methods

    private func validateVersion(_ version: String) -> PolicyValidationError? {
        guard let policyVersion = PolicyVersion(string: version) else {
            return .invalidVersion(version)
        }

        if policyVersion > PolicyVersion.current {
            return .unsupportedVersion(version, required: PolicyVersion.current.string)
        }

        return nil
    }

    private func validatePolicyName(_ name: String) -> PolicyValidationError? {
        if name.isEmpty {
            return .emptyPolicyName
        }

        if !isValidName(name) {
            return .invalidPolicyName(name)
        }

        return nil
    }

    private func validateRules(_ rules: [PolicyRule]) -> [PolicyValidationError] {
        var errors: [PolicyValidationError] = []
        var seenIds: Set<String> = []

        for rule in rules {
            // Check for duplicate IDs
            if seenIds.contains(rule.id) {
                errors.append(.duplicateRuleId(rule.id))
            } else {
                seenIds.insert(rule.id)
            }

            // Validate each rule
            let ruleResult = validate(rule)
            errors.append(contentsOf: ruleResult.errors)
        }

        return errors
    }

    private func validateConditions(_ conditions: PolicyCondition) -> [PolicyValidationError] {
        var errors: [PolicyValidationError] = []

        // Validate duration formats
        if let olderThan = conditions.olderThan, !isValidDuration(olderThan) {
            errors.append(.invalidDurationFormat(olderThan))
        }

        // Validate size formats
        if let minFreeSpace = conditions.minFreeSpace, !isValidSize(minFreeSpace) {
            errors.append(.invalidSizeFormat(minFreeSpace))
        }

        if let maxFreeSpace = conditions.maxFreeSpace, !isValidSize(maxFreeSpace) {
            errors.append(.invalidSizeFormat(maxFreeSpace))
        }

        if let minFileSize = conditions.minFileSize, !isValidSize(minFileSize) {
            errors.append(.invalidSizeFormat(minFileSize))
        }

        if let maxFileSize = conditions.maxFileSize, !isValidSize(maxFileSize) {
            errors.append(.invalidSizeFormat(maxFileSize))
        }

        // Validate hour range
        if let hourRange = conditions.hourRange {
            if !hourRange.isValid {
                errors.append(.invalidHourRange(start: hourRange.start, end: hourRange.end))
            }
        }

        return errors
    }

    private func validateExclusions(_ exclusions: [String]) -> [PolicyValidationError] {
        var errors: [PolicyValidationError] = []

        for pattern in exclusions {
            if !isValidExclusionPattern(pattern) {
                errors.append(.invalidExclusionPattern(pattern))
            }
        }

        return errors
    }

    private func generateWarnings(for policy: Policy) -> [String] {
        var warnings: [String] = []

        // Warn about aggressive settings
        let aggressiveRules = policy.rules.filter {
            $0.target == .all && $0.action == .clean
        }
        if !aggressiveRules.isEmpty {
            warnings.append("Policy contains aggressive cleanup rules targeting 'all' categories")
        }

        // Warn about no exclusions with aggressive targets
        if policy.exclusions.isEmpty && policy.rules.contains(where: { $0.target == .downloads }) {
            warnings.append("Consider adding exclusions for important files when targeting downloads")
        }

        // Warn about disabled notifications for automated policies
        if !policy.notifications && policy.rules.contains(where: { $0.schedule != .manual }) {
            warnings.append("Notifications are disabled for automated cleanup rules")
        }

        // Warn about high priority without conditions
        if policy.priority == .critical && policy.rules.contains(where: { $0.conditions == nil }) {
            warnings.append("Critical priority policy has rules without conditions")
        }

        return warnings
    }

    // MARK: - Helper Methods

    private func isValidName(_ name: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: Self.namePattern, options: [])
        let range = NSRange(location: 0, length: name.utf16.count)
        return regex?.firstMatch(in: name, options: [], range: range) != nil
    }

    private func isValidDuration(_ duration: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: Self.durationPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: duration.utf16.count)
        return regex?.firstMatch(in: duration, options: [], range: range) != nil
    }

    private func isValidSize(_ size: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: Self.sizePattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: size.utf16.count)
        return regex?.firstMatch(in: size, options: [], range: range) != nil
    }

    private func isValidExclusionPattern(_ pattern: String) -> Bool {
        // Basic validation: must start with ~ or / and not be empty after expansion
        guard !pattern.isEmpty else { return false }

        // Allow patterns starting with ~, /, or relative paths with wildcards
        let validStarts = ["~", "/", "*"]
        return validStarts.contains(where: { pattern.hasPrefix($0) }) ||
               pattern.contains("*") ||
               pattern.contains("/")
    }
}

// MARK: - Duration Parsing

extension PolicyValidator {
    /// Parse duration string to TimeInterval
    public static func parseDuration(_ duration: String) -> TimeInterval? {
        let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: duration.utf16.count)

        guard let match = regex?.firstMatch(in: duration, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: duration),
              let unitRange = Range(match.range(at: 2), in: duration),
              let value = Double(duration[valueRange]) else {
            return nil
        }

        let unit = String(duration[unitRange]).lowercased()

        switch unit {
        case "d": return value * 86400        // days
        case "w": return value * 604800       // weeks
        case "m": return value * 2592000      // months (30 days)
        case "y": return value * 31536000     // years
        default: return nil
        }
    }

    /// Parse size string to bytes
    public static func parseSize(_ size: String) -> UInt64? {
        let regex = try? NSRegularExpression(pattern: sizePattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: size.utf16.count)

        guard let match = regex?.firstMatch(in: size, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: size),
              let unitRange = Range(match.range(at: 2), in: size),
              let value = Double(size[valueRange]) else {
            return nil
        }

        let unit = String(size[unitRange]).uppercased()

        switch unit {
        case "KB": return UInt64(value * 1024)
        case "MB": return UInt64(value * 1024 * 1024)
        case "GB": return UInt64(value * 1024 * 1024 * 1024)
        case "TB": return UInt64(value * 1024 * 1024 * 1024 * 1024)
        default: return nil
        }
    }
}

import ArgumentParser
import OSXCleanerKit

// MARK: - CleanupLevel ArgumentParser Extension

extension CleanupLevel: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument.lowercased() {
        case "light", "1":
            self = .light
        case "normal", "2":
            self = .normal
        case "deep", "3":
            self = .deep
        case "system", "4":
            self = .system
        default:
            return nil
        }
    }

    public static var allValueStrings: [String] {
        ["light", "normal", "deep", "system"]
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

// MARK: - CleanupTarget

/// Target category for cleanup operations
public enum CleanupTarget: String, CaseIterable, ExpressibleByArgument {
    case browser
    case developer
    case logs
    case all

    public var description: String {
        switch self {
        case .browser:
            return "Browser caches (Safari, Chrome, Firefox)"
        case .developer:
            return "Developer caches (Xcode, npm, Cargo, etc.)"
        case .logs:
            return "System and application logs"
        case .all:
            return "All cleanup targets"
        }
    }

    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

// MARK: - AnalysisCategory

/// Category for analysis operations
public enum AnalysisCategory: String, CaseIterable, ExpressibleByArgument {
    case all
    case xcode
    case docker
    case browser
    case caches
    case logs

    public var description: String {
        switch self {
        case .all:
            return "All categories"
        case .xcode:
            return "Xcode related (DerivedData, Archives, Device Support)"
        case .docker:
            return "Docker (images, containers, volumes)"
        case .browser:
            return "Browser caches and data"
        case .caches:
            return "Application caches"
        case .logs:
            return "System and application logs"
        }
    }

    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

// MARK: - OutputFormat

/// Output format for CLI results
public enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json

    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

// MARK: - ScheduleFrequency

/// Frequency for scheduled cleanup operations
public enum ScheduleFrequency: String, CaseIterable, ExpressibleByArgument {
    case daily
    case weekly
    case monthly

    public var description: String {
        switch self {
        case .daily:
            return "Run daily at specified time"
        case .weekly:
            return "Run weekly on specified day"
        case .monthly:
            return "Run monthly on specified day"
        }
    }

    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    public static var defaultCompletionKind: CompletionKind {
        .list(allValueStrings)
    }
}

// MARK: - Exit Codes

/// Standard exit codes for CLI operations
public enum ExitCode {
    /// Operation completed successfully
    public static let success: Int32 = 0
    /// General error occurred
    public static let generalError: Int32 = 1
    /// Insufficient disk space or cleanup failed
    public static let insufficientSpace: Int32 = 2
    /// Permission denied
    public static let permissionDenied: Int32 = 3
    /// Configuration error
    public static let configurationError: Int32 = 4
    /// User cancelled operation
    public static let userCancelled: Int32 = 5
}

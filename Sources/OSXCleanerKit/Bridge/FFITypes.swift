import Foundation

// MARK: - Analysis Types (from Rust scanner module)

/// Analysis result from Rust core
public struct RustAnalysisResult: Codable {
    public let path: String
    public let totalSize: UInt64
    public let fileCount: Int
    public let directoryCount: Int
    public let categories: [RustCategoryStats]
    public let largestItems: [RustFileInfo]
    public let oldestItems: [RustFileInfo]

    private enum CodingKeys: String, CodingKey {
        case path
        case totalSize = "total_size"
        case fileCount = "file_count"
        case directoryCount = "directory_count"
        case categories
        case largestItems = "largest_items"
        case oldestItems = "oldest_items"
    }
}

/// Category statistics from Rust
public struct RustCategoryStats: Codable {
    public let category: String
    public let size: UInt64
    public let count: Int
}

/// File information from Rust
public struct RustFileInfo: Codable {
    public let path: String
    public let size: UInt64
    public let modified: Int64?
    public let category: String
}

// MARK: - Clean Types (from Rust cleaner module)

/// Clean result from Rust core
public struct RustCleanResult: Codable {
    public let path: String
    public let freedBytes: UInt64
    public let filesRemoved: Int
    public let directoriesRemoved: Int
    public let errors: [RustCleanErrorInfo]
    public let dryRun: Bool

    private enum CodingKeys: String, CodingKey {
        case path
        case freedBytes = "freed_bytes"
        case filesRemoved = "files_removed"
        case directoriesRemoved = "directories_removed"
        case errors
        case dryRun = "dry_run"
    }
}

/// Clean error information from Rust
public struct RustCleanErrorInfo: Codable {
    public let path: String
    public let reason: String
}

// MARK: - Safety Level

/// Safety level for cleanup operations
public enum SafetyLevel: Int32, CaseIterable {
    case danger = 1
    case risky = 2
    case moderate = 3
    case safe = 4
    case verySafe = 5

    public var description: String {
        switch self {
        case .danger:
            return "Danger (may cause system issues)"
        case .risky:
            return "Risky (may affect applications)"
        case .moderate:
            return "Moderate (generally safe)"
        case .safe:
            return "Safe (caches and temporary files)"
        case .verySafe:
            return "Very Safe (only clearly temporary data)"
        }
    }
}

// MARK: - Bridge Errors

/// Errors from the Rust bridge
public enum RustBridgeError: LocalizedError {
    case initializationFailed
    case nullPointer
    case invalidUTF8
    case rustError(String)
    case jsonParsingError(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize Rust core library"
        case .nullPointer:
            return "Received null pointer from Rust"
        case .invalidUTF8:
            return "Invalid UTF-8 string from Rust"
        case .rustError(let message):
            return "Rust error: \(message)"
        case .jsonParsingError(let message):
            return "JSON parsing error: \(message)"
        }
    }
}

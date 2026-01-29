// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

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

/// Safety level classification for paths (from Rust safety module)
///
/// Higher numbers indicate more danger - DANGER paths should never be deleted.
public enum SafetyLevel: Int32, CaseIterable, Comparable {
    /// Safe to delete immediately, auto-regenerates (e.g., browser cache, Trash)
    case safe = 1
    /// Deletable but requires rebuild time (e.g., user caches, old logs)
    case caution = 2
    /// Deletable but requires re-download (e.g., iOS Device Support, Docker images)
    case warning = 3
    /// Never delete - system damage risk (e.g., /System/*, Keychains)
    case danger = 4

    public var description: String {
        switch self {
        case .safe:
            return "Safe (auto-regenerates)"
        case .caution:
            return "Caution (requires rebuild)"
        case .warning:
            return "Warning (requires re-download)"
        case .danger:
            return "Danger (system damage risk)"
        }
    }

    public var indicator: String {
        switch self {
        case .safe:
            return "\u{2705}"      // Green checkmark
        case .caution:
            return "\u{26A0}"      // Warning sign
        case .warning:
            return "\u{26A0}\u{26A0}"  // Double warning
        case .danger:
            return "\u{274C}"      // Red X
        }
    }

    /// Returns true if deletion is allowed at this level
    public var isDeletable: Bool {
        self != .danger
    }

    /// Returns true if user confirmation is required before deletion
    public var requiresConfirmation: Bool {
        self == .warning || self == .danger
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Cleanup Level

/// Cleanup level that determines which safety levels can be deleted
public enum CleanupLevel: Int32, CaseIterable {
    /// Level 1: Light - Safe only (browser cache, Trash, old downloads)
    case light = 1
    /// Level 2: Normal - Light + Caution (user caches, old logs)
    case normal = 2
    /// Level 3: Deep - Normal + Warning (developer caches)
    case deep = 3
    /// Level 4: System - Deep + restricted system caches (requires root)
    case system = 4

    public var description: String {
        switch self {
        case .light:
            return "Light (safe items only)"
        case .normal:
            return "Normal (includes caches)"
        case .deep:
            return "Deep (includes developer caches)"
        case .system:
            return "System (maximum cleanup)"
        }
    }

    /// Returns the maximum SafetyLevel that can be deleted at this cleanup level
    public var maxDeletableSafety: SafetyLevel {
        switch self {
        case .light:
            return .safe
        case .normal:
            return .caution
        case .deep, .system:
            return .warning
        }
    }

    /// Returns true if the given safety level can be deleted at this cleanup level
    public func canDelete(_ safety: SafetyLevel) -> Bool {
        if safety == .danger {
            return false
        }
        return safety <= maxDeletableSafety
    }
}

// MARK: - Bridge Errors

/// Errors from the Rust bridge
public enum RustBridgeError: LocalizedError {
    case initializationFailed
    case nullPointer
    case invalidUTF8
    case invalidString(String)
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
        case .invalidString(let message):
            return "Invalid string for FFI: \(message)"
        case .rustError(let message):
            return "Rust error: \(message)"
        case .jsonParsingError(let message):
            return "JSON parsing error: \(message)"
        }
    }
}

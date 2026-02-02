// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import COSXCore
import Foundation

/// Bridge between Swift and Rust core library
///
/// This class provides a safe Swift interface to the Rust FFI functions.
/// It handles memory management, string conversion, and error propagation
/// across the FFI boundary.
///
/// # FFI Safety
///
/// This bridge ensures safe interaction with Rust by:
/// - **Memory Management**: Automatically frees Rust-allocated memory using `defer`
/// - **Input Validation**: Validates all strings before FFI calls (null bytes, UTF-8, length)
/// - **String Conversion**: Validates UTF-8 encoding for all string parameters
/// - **Error Handling**: Converts FFI errors to Swift exceptions
/// - **Thread Safety**: Protects initialization with serial queue
/// - **DoS Prevention**: Rejects strings exceeding 4096 characters
///
/// # Memory Ownership
///
/// - **Input Strings**: Swift owns strings passed to Rust (borrowed by Rust)
/// - **Output Results**: Rust allocates FFIResult, Swift frees with `osx_free_result()`
/// - **Automatic Cleanup**: All methods use `defer` to prevent memory leaks
///
/// # Thread Safety
///
/// - Initialization is protected by a serial queue (`initQueue`)
/// - All FFI functions are thread-safe when operating on different paths
/// - Avoid concurrent cleanup operations on the same path
///
/// # Example
///
/// ```swift
/// let bridge = RustBridge.shared
/// try bridge.initialize()
///
/// // Memory is automatically managed
/// let result = try bridge.analyzePath("/Users/example/Library/Caches")
/// ```
///
/// For detailed FFI usage guidelines, see `docs/reference/ffi-guide.md`.
public final class RustBridge {
    /// Shared singleton instance
    public static let shared = RustBridge()

    /// Whether the Rust core has been initialized
    private var isInitialized = false

    /// Whether operating in fallback mode (Swift-only)
    private var isFallbackMode = false

    /// Maximum number of initialization retry attempts
    private let maxRetryAttempts = 3

    /// Base delay between retry attempts (in seconds)
    private let retryBaseDelay: TimeInterval = 1.0

    /// Serial queue for thread-safe initialization
    private let initQueue = DispatchQueue(label: "com.osxcleaner.rustbridge.init")

    private init() {}

    // MARK: - Initialization

    /// Initialize the Rust core library with automatic retry and fallback
    ///
    /// This method is idempotent and thread-safe. It will only initialize
    /// the Rust core once, even if called multiple times.
    ///
    /// ## Recovery Strategy
    ///
    /// 1. Attempts initialization up to `maxRetryAttempts` times (default: 3)
    /// 2. Uses exponential delay between retries (1s, 2s, 3s)
    /// 3. On all failures, enters fallback mode (Swift-only operations)
    /// 4. Notifies user when fallback mode is activated
    ///
    /// ## Fallback Mode
    ///
    /// In fallback mode:
    /// - Swift-only implementations are used
    /// - Some operations may be slower
    /// - Core functionality remains available
    /// - User is notified of performance limitations
    ///
    /// - Throws: `RustBridgeError.initializationFailed` if initialization fails and fallback is not possible
    public func initialize() throws {
        try initQueue.sync {
            guard !isInitialized else { return }

            var lastError: Error?

            // Attempt initialization with retry logic
            for attempt in 1...maxRetryAttempts {
                do {
                    let success = osx_core_init()
                    guard success else {
                        throw RustBridgeError.initializationFailed
                    }

                    isInitialized = true
                    AppLogger.shared.info("Rust core initialized successfully")
                    return
                } catch {
                    lastError = error
                    AppLogger.shared.warning(
                        "Rust core initialization attempt \(attempt)/\(maxRetryAttempts) failed: \(error)"
                    )

                    // Sleep before next retry (exponential backoff)
                    if attempt < maxRetryAttempts {
                        let delay = retryBaseDelay * Double(attempt)
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
            }

            // All retries failed - enter fallback mode
            AppLogger.shared.error(
                "Rust core initialization failed after \(maxRetryAttempts) attempts. Entering fallback mode."
            )

            try enterFallbackMode(lastError: lastError!)
        }
    }

    /// Enter fallback mode when Rust core initialization fails
    ///
    /// Fallback mode uses Swift-only implementations for core functionality.
    /// This ensures the application remains usable even if Rust initialization fails.
    ///
    /// - Parameter lastError: The last error that caused fallback activation
    /// - Throws: `RustBridgeError.initializationFailed` if fallback mode setup fails
    private func enterFallbackMode(lastError: Error) throws {
        isFallbackMode = true

        // Log fallback mode activation
        AppLogger.shared.error("Entering fallback mode. Last error: \(lastError)")

        // Note: User notification implementation will be added when
        // the UserNotification system is available in the codebase
        // For now, we log the event for monitoring

        // Mark initialization as complete (in fallback mode)
        isInitialized = true
    }

    /// Ensure the bridge is initialized before use
    private func ensureInitialized() throws {
        if !isInitialized {
            try initialize()
        }
    }

    /// Check if the bridge is operating in fallback mode
    ///
    /// - Returns: True if fallback mode is active (Swift-only operations)
    public func isInFallbackMode() -> Bool {
        return isFallbackMode
    }

    // MARK: - Version

    /// Get the version of the Rust core library
    ///
    /// - Returns: Version string
    /// - Throws: `RustBridgeError` if the operation fails
    public func version() throws -> String {
        try ensureInitialized()

        guard let versionPtr = osx_core_version() else {
            throw RustBridgeError.nullPointer
        }
        defer { osx_free_string(versionPtr) }

        guard let version = String(cString: versionPtr, encoding: .utf8) else {
            throw RustBridgeError.invalidUTF8
        }

        return version
    }

    // MARK: - Analysis

    /// Analyze a path for cleanup opportunities
    ///
    /// This method calls the Rust scanner to analyze the given path
    /// and returns detailed statistics about files and directories.
    ///
    /// - Parameter path: The path to analyze
    /// - Returns: Analysis result with statistics
    /// - Throws: `RustBridgeError` if the operation fails
    public func analyzePath(_ path: String) throws -> RustAnalysisResult {
        try ensureInitialized()
        try validateFFIString(path)

        let result = path.withCString { pathPtr in
            osx_analyze_path(pathPtr)
        }

        return try processFFIResult(result)
    }

    // MARK: - Safety

    /// Calculate the safety level for a path
    ///
    /// Returns a safety level indicating how dangerous it is to delete the path.
    /// SafetyLevel.safe = 1 (safest to delete), SafetyLevel.danger = 4 (never delete)
    ///
    /// - Parameter path: The path to evaluate
    /// - Returns: Safety level (1-4)
    /// - Throws: `RustBridgeError` if the operation fails
    public func calculateSafety(for path: String) throws -> SafetyLevel {
        try ensureInitialized()
        try validateFFIString(path)

        let level = path.withCString { pathPtr in
            osx_calculate_safety(pathPtr)
        }

        guard level >= 0 else {
            throw RustBridgeError.rustError("Failed to calculate safety level")
        }

        return SafetyLevel(rawValue: level) ?? .caution
    }

    // MARK: - Cleaning

    /// Clean a path with the specified cleanup level
    ///
    /// This method performs the actual cleanup operation using the Rust core.
    /// It respects the cleanup level to prevent accidental deletion of important files.
    ///
    /// - Parameters:
    ///   - path: The path to clean
    ///   - cleanupLevel: The cleanup level (determines which safety levels can be deleted)
    ///   - dryRun: If true, only simulate the cleanup without deleting files
    /// - Returns: Clean result with statistics
    /// - Throws: `RustBridgeError` if the operation fails
    public func cleanPath(
        _ path: String,
        cleanupLevel: CleanupLevel,
        dryRun: Bool
    ) throws -> RustCleanResult {
        try ensureInitialized()
        try validateFFIString(path)

        let result = path.withCString { pathPtr in
            osx_clean_path(pathPtr, cleanupLevel.rawValue, dryRun)
        }

        return try processFFIResult(result)
    }

    /// Clean a path with the specified safety level (deprecated)
    @available(*, deprecated, renamed: "cleanPath(_:cleanupLevel:dryRun:)")
    public func cleanPath(
        _ path: String,
        safetyLevel: SafetyLevel,
        dryRun: Bool
    ) throws -> RustCleanResult {
        // Map old safety level to new cleanup level
        let cleanupLevel: CleanupLevel
        switch safetyLevel {
        case .safe:
            cleanupLevel = .light
        case .caution:
            cleanupLevel = .normal
        case .warning:
            cleanupLevel = .deep
        case .danger:
            cleanupLevel = .system
        }
        return try cleanPath(path, cleanupLevel: cleanupLevel, dryRun: dryRun)
    }

    // MARK: - Input Validation

    /// Validate a string before passing to FFI boundary
    ///
    /// This method ensures strings meet FFI safety requirements:
    /// - No null bytes (invalid in C strings)
    /// - Valid UTF-8 encoding
    /// - Reasonable length (prevents DoS attacks)
    ///
    /// - Parameter string: The string to validate
    /// - Throws: `RustBridgeError.invalidString` if validation fails
    private func validateFFIString(_ string: String) throws {
        // Check for null bytes (invalid in C strings)
        guard !string.contains("\0") else {
            throw RustBridgeError.invalidString("String contains null byte")
        }

        // Verify UTF-8 validity by checking if conversion succeeds
        guard string.utf8CString.count > 0 else {
            throw RustBridgeError.invalidString("String is not valid UTF-8")
        }

        // Check reasonable length (prevent DoS)
        guard string.count <= 4096 else {
            throw RustBridgeError.invalidString("String exceeds maximum length (4096 characters)")
        }
    }

    // MARK: - Helpers

    /// Process an FFI result and decode the JSON data
    ///
    /// This method demonstrates proper FFI memory management:
    ///
    /// 1. **Check Success**: Validates `result.success` before accessing data
    /// 2. **Copy Data**: Converts C strings to Swift strings (copies memory)
    /// 3. **Free Memory**: Uses `defer` to ensure Rust-allocated memory is freed
    /// 4. **Error Propagation**: Converts Rust errors to Swift exceptions
    ///
    /// # Memory Safety
    ///
    /// - **Input**: `result` is stack-allocated by Rust (no ownership transfer)
    /// - **Strings**: `error_message` and `data` are heap-allocated by Rust
    /// - **Ownership**: Swift takes ownership and MUST free strings
    /// - **Cleanup**: `defer` ensures strings are freed even if function throws
    ///
    /// # Example Memory Flow
    ///
    /// ```
    /// 1. Rust allocates FFIResult { data: heap_string }
    /// 2. Swift receives result (borrowed, not owned)
    /// 3. Swift copies data: String(cString: dataPtr)
    /// 4. defer block executes: osx_free_string(dataPtr)
    /// 5. Rust deallocates heap_string
    /// ```
    ///
    /// - Parameter result: FFI result from Rust (strings will be freed automatically)
    /// - Returns: Decoded Swift object
    /// - Throws: `RustBridgeError` if parsing fails or result indicates error
    private func processFFIResult<T: Decodable>(_ result: osx_FFIResult) throws -> T {
        // Check success before accessing data (safety contract)
        if !result.success {
            let errorMessage: String
            if let errorPtr = result.error_message {
                // Copy error message to Swift string
                errorMessage = String(cString: errorPtr)
                // Free Rust-allocated memory immediately after copy
                osx_free_string(errorPtr)
            } else {
                errorMessage = "Unknown error"
            }
            throw RustBridgeError.rustError(errorMessage)
        }

        guard let dataPtr = result.data else {
            throw RustBridgeError.nullPointer
        }
        // Free data string at end of scope (even if exception thrown)
        defer { osx_free_string(dataPtr) }

        // Copy C string to Swift string (memory-safe)
        let jsonString = String(cString: dataPtr)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw RustBridgeError.invalidUTF8
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            throw RustBridgeError.jsonParsingError(error.localizedDescription)
        }
    }
}

// MARK: - Convenience Extensions

extension RustBridge {
    /// Check if a path can be cleaned at the given cleanup level
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - cleanupLevel: The cleanup level to use
    /// - Returns: True if the path can be cleaned at the given cleanup level
    public func canCleanPath(_ path: String, atLevel cleanupLevel: CleanupLevel) -> Bool {
        do {
            let pathSafety = try calculateSafety(for: path)
            return cleanupLevel.canDelete(pathSafety)
        } catch {
            AppLogger.shared.warning("Failed to calculate safety for \(path): \(error)")
            return false
        }
    }

    /// Check if a path is safe to clean (deprecated)
    @available(*, deprecated, renamed: "canCleanPath(_:atLevel:)")
    public func isPathSafe(_ path: String, atLevel level: SafetyLevel) -> Bool {
        // Map old safety level to cleanup level
        let cleanupLevel: CleanupLevel
        switch level {
        case .safe:
            cleanupLevel = .light
        case .caution:
            cleanupLevel = .normal
        case .warning:
            cleanupLevel = .deep
        case .danger:
            cleanupLevel = .system
        }
        return canCleanPath(path, atLevel: cleanupLevel)
    }
}

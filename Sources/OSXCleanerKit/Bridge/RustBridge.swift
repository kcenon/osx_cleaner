import COSXCore
import Foundation

/// Bridge between Swift and Rust core library
///
/// This class provides a safe Swift interface to the Rust FFI functions.
/// It handles memory management, string conversion, and error propagation
/// across the FFI boundary.
public final class RustBridge {
    /// Shared singleton instance
    public static let shared = RustBridge()

    /// Whether the Rust core has been initialized
    private var isInitialized = false

    /// Serial queue for thread-safe initialization
    private let initQueue = DispatchQueue(label: "com.osxcleaner.rustbridge.init")

    private init() {}

    // MARK: - Initialization

    /// Initialize the Rust core library
    ///
    /// This method is idempotent and thread-safe. It will only initialize
    /// the Rust core once, even if called multiple times.
    ///
    /// - Throws: `RustBridgeError.initializationFailed` if initialization fails
    public func initialize() throws {
        try initQueue.sync {
            guard !isInitialized else { return }

            let success = osx_core_init()
            guard success else {
                throw RustBridgeError.initializationFailed
            }

            isInitialized = true
            AppLogger.shared.info("Rust core initialized successfully")
        }
    }

    /// Ensure the bridge is initialized before use
    private func ensureInitialized() throws {
        if !isInitialized {
            try initialize()
        }
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

        let result = path.withCString { pathPtr in
            osx_analyze_path(pathPtr)
        }

        return try processFFIResult(result)
    }

    // MARK: - Safety

    /// Calculate the safety level for a path
    ///
    /// Returns a safety level indicating how safe it is to delete the path.
    /// Higher values indicate safer paths to delete.
    ///
    /// - Parameter path: The path to evaluate
    /// - Returns: Safety level (1-5)
    /// - Throws: `RustBridgeError` if the operation fails
    public func calculateSafety(for path: String) throws -> SafetyLevel {
        try ensureInitialized()

        let level = path.withCString { pathPtr in
            osx_calculate_safety(pathPtr)
        }

        guard level >= 0 else {
            throw RustBridgeError.rustError("Failed to calculate safety level")
        }

        return SafetyLevel(rawValue: level) ?? .moderate
    }

    // MARK: - Cleaning

    /// Clean a path with the specified safety level
    ///
    /// This method performs the actual cleanup operation using the Rust core.
    /// It respects the safety level to prevent accidental deletion of important files.
    ///
    /// - Parameters:
    ///   - path: The path to clean
    ///   - safetyLevel: Minimum safety level required for deletion
    ///   - dryRun: If true, only simulate the cleanup without deleting files
    /// - Returns: Clean result with statistics
    /// - Throws: `RustBridgeError` if the operation fails
    public func cleanPath(
        _ path: String,
        safetyLevel: SafetyLevel,
        dryRun: Bool
    ) throws -> RustCleanResult {
        try ensureInitialized()

        let result = path.withCString { pathPtr in
            osx_clean_path(pathPtr, safetyLevel.rawValue, dryRun)
        }

        return try processFFIResult(result)
    }

    // MARK: - Helpers

    /// Process an FFI result and decode the JSON data
    private func processFFIResult<T: Decodable>(_ result: osx_FFIResult) throws -> T {
        if !result.success {
            let errorMessage: String
            if let errorPtr = result.error_message {
                errorMessage = String(cString: errorPtr)
                osx_free_string(errorPtr)
            } else {
                errorMessage = "Unknown error"
            }
            throw RustBridgeError.rustError(errorMessage)
        }

        guard let dataPtr = result.data else {
            throw RustBridgeError.nullPointer
        }
        defer { osx_free_string(dataPtr) }

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
    /// Check if a path is safe to clean at the given level
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - level: The required safety level
    /// - Returns: True if the path is safe to clean at the given level
    public func isPathSafe(_ path: String, atLevel level: SafetyLevel) -> Bool {
        do {
            let pathSafety = try calculateSafety(for: path)
            return pathSafety.rawValue >= level.rawValue
        } catch {
            AppLogger.shared.warning("Failed to calculate safety for \(path): \(error)")
            return false
        }
    }
}

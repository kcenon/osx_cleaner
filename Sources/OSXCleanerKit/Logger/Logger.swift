// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Logging

/// Application-wide logger
public enum AppLogger {
    private static var _logger: Logger?

    public static var shared: Logger {
        if let logger = _logger {
            return logger
        }
        var logger = Logger(label: "com.osxcleaner")
        logger.logLevel = .info
        _logger = logger
        return logger
    }

    public static func configure(level: Logger.Level) {
        var logger = Logger(label: "com.osxcleaner")
        logger.logLevel = level
        _logger = logger
    }

    public static func configure(levelString: String) {
        let level: Logger.Level
        switch levelString.lowercased() {
        case "debug", "trace":
            level = .debug
        case "info":
            level = .info
        case "warning", "warn":
            level = .warning
        case "error":
            level = .error
        case "critical":
            level = .critical
        default:
            level = .info
        }
        configure(level: level)
    }
}

// MARK: - Convenience Extensions

public extension Logger {
    func operation(_ message: String, metadata: Logger.Metadata? = nil) {
        self.info("[\(message)]", metadata: metadata)
    }

    func success(_ message: String, metadata: Logger.Metadata? = nil) {
        self.info("✓ \(message)", metadata: metadata)
    }

    func failure(_ message: String, metadata: Logger.Metadata? = nil) {
        self.error("✗ \(message)", metadata: metadata)
    }
}

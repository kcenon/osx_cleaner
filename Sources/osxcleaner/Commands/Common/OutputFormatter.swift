// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import OSXCleanerKit

/// Common output formatting utilities for CLI commands
enum OutputFormatter {
    /// Encode and print an encodable value as JSON
    static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        print(String(data: data, encoding: .utf8) ?? "{}")
    }

    /// Create a standard date formatter for consistent date display
    static func standardDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    /// Create a short date formatter for table displays
    static func shortDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }

    /// Print a header line with the given message
    static func printHeader(_ message: String, progressView: ProgressView) {
        progressView.display(message: "")
        progressView.display(message: String(repeating: "=", count: 59))
        progressView.display(message: centerText(message, width: 59))
        progressView.display(message: String(repeating: "=", count: 59))
        progressView.display(message: "")
    }

    /// Print a footer line
    static func printFooter(_ message: String? = nil, progressView: ProgressView) {
        if let message = message {
            progressView.display(message: "")
            progressView.display(message: String(repeating: "=", count: 59))
            progressView.display(message: message)
            progressView.display(message: String(repeating: "=", count: 59))
        } else {
            progressView.display(message: "")
            progressView.display(message: String(repeating: "=", count: 59))
        }
    }

    /// Center text within a given width
    private static func centerText(_ text: String, width: Int) -> String {
        let padding = (width - text.count) / 2
        return String(repeating: " ", count: max(0, padding)) + text
    }

    /// Format bytes with appropriate unit
    static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.2f %@", value, units[unitIndex])
    }
}

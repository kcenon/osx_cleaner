// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// Type of Prometheus metric
public enum MetricType: String {
    case gauge
    case counter
    case histogram
    case summary
}

/// Represents a single Prometheus metric
public struct PrometheusMetric {
    public let name: String
    public let help: String
    public let type: MetricType
    public let labels: [String: String]
    public let value: Double

    public init(
        name: String,
        help: String,
        type: MetricType,
        labels: [String: String] = [:],
        value: Double
    ) {
        self.name = name
        self.help = help
        self.type = type
        self.labels = labels
        self.value = value
    }

    /// Format the metric in Prometheus exposition format
    public func format() -> String {
        var result = ""

        // Add HELP line
        result += "# HELP \(name) \(help)\n"

        // Add TYPE line
        result += "# TYPE \(name) \(type.rawValue)\n"

        // Add metric value with labels
        if labels.isEmpty {
            result += "\(name) \(formatValue(value))\n"
        } else {
            let labelStr = labels.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
            result += "\(name){\(labelStr)} \(formatValue(value))\n"
        }

        return result
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < Double(Int64.max) {
            return String(Int64(value))
        }
        return String(format: "%.6f", value)
    }
}

/// Collection of Prometheus metrics with formatting capabilities
public struct PrometheusMetricCollection {
    public var metrics: [PrometheusMetric]

    public init(metrics: [PrometheusMetric] = []) {
        self.metrics = metrics
    }

    /// Add a gauge metric
    public mutating func addGauge(
        name: String,
        help: String,
        value: Double,
        labels: [String: String] = [:]
    ) {
        metrics.append(PrometheusMetric(
            name: name,
            help: help,
            type: .gauge,
            labels: labels,
            value: value
        ))
    }

    /// Add a counter metric
    public mutating func addCounter(
        name: String,
        help: String,
        value: Double,
        labels: [String: String] = [:]
    ) {
        metrics.append(PrometheusMetric(
            name: name,
            help: help,
            type: .counter,
            labels: labels,
            value: value
        ))
    }

    /// Format all metrics in Prometheus exposition format
    /// Groups metrics by name to avoid duplicate HELP/TYPE lines
    public func format() -> String {
        var result = ""
        var processedNames: Set<String> = []

        for metric in metrics {
            if processedNames.contains(metric.name) {
                // Only output the value line for already processed metric names
                if metric.labels.isEmpty {
                    result += "\(metric.name) \(formatValue(metric.value))\n"
                } else {
                    let labelStr = metric.labels.map { "\($0.key)=\"\($0.value)\"" }
                        .joined(separator: ",")
                    result += "\(metric.name){\(labelStr)} \(formatValue(metric.value))\n"
                }
            } else {
                result += metric.format()
                processedNames.insert(metric.name)
            }
        }

        return result
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < Double(Int64.max) {
            return String(Int64(value))
        }
        return String(format: "%.6f", value)
    }
}

/// Statistics for cleanup operations
public struct CleanupStatistics: Codable {
    public var totalOperations: UInt64
    public var totalBytesFreed: UInt64
    public var totalFilesRemoved: UInt64
    public var totalDirectoriesRemoved: UInt64
    public var totalErrors: UInt64
    public var lastCleanupTime: Date?

    public init(
        totalOperations: UInt64 = 0,
        totalBytesFreed: UInt64 = 0,
        totalFilesRemoved: UInt64 = 0,
        totalDirectoriesRemoved: UInt64 = 0,
        totalErrors: UInt64 = 0,
        lastCleanupTime: Date? = nil
    ) {
        self.totalOperations = totalOperations
        self.totalBytesFreed = totalBytesFreed
        self.totalFilesRemoved = totalFilesRemoved
        self.totalDirectoriesRemoved = totalDirectoriesRemoved
        self.totalErrors = totalErrors
        self.lastCleanupTime = lastCleanupTime
    }

    /// Add result from a cleanup operation
    public mutating func addResult(_ result: CleanResult) {
        totalOperations += 1
        totalBytesFreed += result.freedBytes
        totalFilesRemoved += UInt64(result.filesRemoved)
        totalDirectoriesRemoved += UInt64(result.directoriesRemoved)
        totalErrors += UInt64(result.errors.count)
        lastCleanupTime = Date()
    }
}

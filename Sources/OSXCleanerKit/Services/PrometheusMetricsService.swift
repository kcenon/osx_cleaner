// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import Network

/// Configuration for Prometheus metrics endpoint
public struct MetricsConfig: Codable {
    /// Port to listen on (default: 9090)
    public let port: UInt16

    /// Host to bind to (default: localhost)
    public let host: String

    /// Whether to include detailed labels
    public let includeLabels: Bool

    /// Refresh interval for cached metrics in seconds
    public let refreshInterval: TimeInterval

    public init(
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        includeLabels: Bool = true,
        refreshInterval: TimeInterval = 5.0
    ) {
        self.port = port
        self.host = host
        self.includeLabels = includeLabels
        self.refreshInterval = refreshInterval
    }
}

/// Service for exposing Prometheus metrics via HTTP endpoint
///
/// Provides an HTTP server on configurable port (default 9090) that exposes
/// disk usage and cleanup statistics in Prometheus format.
public final class PrometheusMetricsService {

    // MARK: - Singleton

    public static let shared = PrometheusMetricsService()

    // MARK: - Properties

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let connectionQueue = DispatchQueue(label: "com.osxcleaner.metrics.connection")
    private let listenerQueue = DispatchQueue(label: "com.osxcleaner.metrics.listener")
    private let statsLock = NSLock()

    private var _cleanupStats = CleanupStatistics()
    private var config: MetricsConfig = MetricsConfig()
    private var isRunning = false

    private let diskMonitoringService: DiskMonitoringService

    /// Current cleanup statistics
    public var cleanupStats: CleanupStatistics {
        statsLock.lock()
        defer { statsLock.unlock() }
        return _cleanupStats
    }

    // MARK: - Initialization

    public init(
        diskMonitoringService: DiskMonitoringService = .shared
    ) {
        self.diskMonitoringService = diskMonitoringService
        loadStatistics()
    }

    // MARK: - Server Management

    /// Start the metrics server
    /// - Parameter config: Server configuration
    public func start(config: MetricsConfig = MetricsConfig()) throws {
        guard !isRunning else {
            AppLogger.shared.warning("Metrics server is already running")
            return
        }

        self.config = config

        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = config.host == "127.0.0.1" || config.host == "localhost"

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: config.port)!)

        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: listenerQueue)
        isRunning = true

        AppLogger.shared.success("Prometheus metrics server started on \(config.host):\(config.port)")
    }

    /// Stop the metrics server
    public func stop() {
        guard isRunning else { return }

        listener?.cancel()
        listener = nil

        connectionQueue.sync {
            for connection in connections {
                connection.cancel()
            }
            connections.removeAll()
        }

        isRunning = false
        saveStatistics()

        AppLogger.shared.info("Prometheus metrics server stopped")
    }

    /// Check if the server is running
    public var running: Bool {
        isRunning
    }

    // MARK: - Statistics Management

    /// Record a cleanup operation result
    /// - Parameter result: The cleanup result to record
    public func recordCleanup(_ result: CleanResult) {
        statsLock.lock()
        _cleanupStats.addResult(result)
        statsLock.unlock()

        saveStatistics()
    }

    /// Reset all statistics
    public func resetStatistics() {
        statsLock.lock()
        _cleanupStats = CleanupStatistics()
        statsLock.unlock()

        saveStatistics()
        AppLogger.shared.info("Cleanup statistics reset")
    }

    // MARK: - Metrics Collection

    /// Collect all current metrics
    public func collectMetrics() throws -> PrometheusMetricCollection {
        var collection = PrometheusMetricCollection()

        // Disk usage metrics
        let diskInfo = try diskMonitoringService.getDiskSpace()

        collection.addGauge(
            name: "osxcleaner_disk_total_bytes",
            help: "Total disk space in bytes",
            value: Double(diskInfo.totalSpace),
            labels: config.includeLabels ? ["volume": diskInfo.volumePath] : [:]
        )

        collection.addGauge(
            name: "osxcleaner_disk_available_bytes",
            help: "Available disk space in bytes",
            value: Double(diskInfo.availableSpace),
            labels: config.includeLabels ? ["volume": diskInfo.volumePath] : [:]
        )

        collection.addGauge(
            name: "osxcleaner_disk_used_bytes",
            help: "Used disk space in bytes",
            value: Double(diskInfo.usedSpace),
            labels: config.includeLabels ? ["volume": diskInfo.volumePath] : [:]
        )

        collection.addGauge(
            name: "osxcleaner_disk_usage_percent",
            help: "Disk usage percentage",
            value: diskInfo.usagePercent,
            labels: config.includeLabels ? ["volume": diskInfo.volumePath] : [:]
        )

        // Cleanup statistics metrics
        let stats = cleanupStats

        collection.addCounter(
            name: "osxcleaner_cleanup_operations_total",
            help: "Total number of cleanup operations performed",
            value: Double(stats.totalOperations)
        )

        collection.addCounter(
            name: "osxcleaner_bytes_cleaned_total",
            help: "Total bytes cleaned by cleanup operations",
            value: Double(stats.totalBytesFreed)
        )

        collection.addCounter(
            name: "osxcleaner_files_removed_total",
            help: "Total files removed by cleanup operations",
            value: Double(stats.totalFilesRemoved)
        )

        collection.addCounter(
            name: "osxcleaner_directories_removed_total",
            help: "Total directories removed by cleanup operations",
            value: Double(stats.totalDirectoriesRemoved)
        )

        collection.addCounter(
            name: "osxcleaner_cleanup_errors_total",
            help: "Total errors during cleanup operations",
            value: Double(stats.totalErrors)
        )

        // Last cleanup timestamp
        if let lastCleanup = stats.lastCleanupTime {
            collection.addGauge(
                name: "osxcleaner_last_cleanup_timestamp",
                help: "Unix timestamp of last cleanup operation",
                value: lastCleanup.timeIntervalSince1970
            )
        }

        // Server info
        collection.addGauge(
            name: "osxcleaner_info",
            help: "OSX Cleaner information",
            value: 1,
            labels: ["version": "1.0.0"]
        )

        return collection
    }

    /// Get metrics in Prometheus format string
    public func getMetricsString() -> String {
        do {
            let collection = try collectMetrics()
            return collection.format()
        } catch {
            AppLogger.shared.error("Failed to collect metrics: \(error)")
            return "# Error collecting metrics\n"
        }
    }

    // MARK: - Private Methods

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let port = listener?.port {
                AppLogger.shared.info("Metrics server listening on port \(port.rawValue)")
            }
        case .failed(let error):
            AppLogger.shared.error("Metrics server failed: \(error)")
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connectionQueue.async { [weak self] in
            self?.connections.append(connection)
        }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveRequest(on: connection)
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }

        connection.start(queue: connectionQueue)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.handleRequest(data: data, connection: connection)
            }

            if isComplete || error != nil {
                self.removeConnection(connection)
            }
        }
    }

    private func handleRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        // Parse HTTP request
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        guard method == "GET" else {
            sendErrorResponse(connection: connection, statusCode: 405, message: "Method Not Allowed")
            return
        }

        switch path {
        case "/metrics", "/":
            sendMetricsResponse(connection: connection)
        case "/health":
            sendHealthResponse(connection: connection)
        default:
            sendErrorResponse(connection: connection, statusCode: 404, message: "Not Found")
        }
    }

    private func sendMetricsResponse(connection: NWConnection) {
        let metrics = getMetricsString()
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/plain; version=0.0.4; charset=utf-8\r
        Content-Length: \(metrics.utf8.count)\r
        Connection: close\r
        \r
        \(metrics)
        """

        sendResponse(connection: connection, response: response)
    }

    private func sendHealthResponse(connection: NWConnection) {
        let body = "{\"status\":\"ok\"}"
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        sendResponse(connection: connection, response: response)
    }

    private func sendErrorResponse(connection: NWConnection, statusCode: Int, message: String) {
        let response = """
        HTTP/1.1 \(statusCode) \(message)\r
        Content-Type: text/plain\r
        Content-Length: \(message.utf8.count)\r
        Connection: close\r
        \r
        \(message)
        """

        sendResponse(connection: connection, response: response)
    }

    private func sendResponse(connection: NWConnection, response: String) {
        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                AppLogger.shared.error("Failed to send response: \(error)")
            }
            self?.removeConnection(connection)
        })
    }

    private func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        connectionQueue.async { [weak self] in
            self?.connections.removeAll { $0 === connection }
        }
    }

    // MARK: - Statistics Persistence

    private var statisticsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("osxcleaner")
            .appendingPathComponent("metrics_stats.json")
    }

    private func loadStatistics() {
        guard FileManager.default.fileExists(atPath: statisticsPath.path) else { return }

        do {
            let data = try Data(contentsOf: statisticsPath)
            let stats = try JSONDecoder().decode(CleanupStatistics.self, from: data)
            statsLock.lock()
            _cleanupStats = stats
            statsLock.unlock()
        } catch {
            AppLogger.shared.warning("Failed to load metrics statistics: \(error)")
        }
    }

    private func saveStatistics() {
        let stats = cleanupStats

        do {
            let directory = statisticsPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stats)
            try data.write(to: statisticsPath)
        } catch {
            AppLogger.shared.warning("Failed to save metrics statistics: \(error)")
        }
    }
}

// MARK: - Errors

public enum MetricsError: LocalizedError {
    case serverAlreadyRunning
    case failedToStart(String)
    case failedToCollectMetrics(String)

    public var errorDescription: String? {
        switch self {
        case .serverAlreadyRunning:
            return "Metrics server is already running"
        case .failedToStart(let reason):
            return "Failed to start metrics server: \(reason)"
        case .failedToCollectMetrics(let reason):
            return "Failed to collect metrics: \(reason)"
        }
    }
}

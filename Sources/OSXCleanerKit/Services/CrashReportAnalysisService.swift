// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - Crash Report Types

/// Represents a parsed crash report
public struct CrashReport: Sendable {
    public let path: String
    public let appName: String
    public let crashDate: Date
    public let reportType: ReportType
    public let size: UInt64

    public enum ReportType: String, Sendable, CaseIterable {
        case crash = ".crash"
        case ips = ".ips"      // Modern crash format (macOS 12+)
        case spin = ".spin"
        case hang = ".hang"
        case diag = ".diag"

        public var description: String {
            switch self {
            case .crash: return "Crash"
            case .ips: return "Crash (IPS)"
            case .spin: return "Spin"
            case .hang: return "Hang"
            case .diag: return "Diagnostic"
            }
        }
    }

    public init(path: String, appName: String, crashDate: Date, reportType: ReportType, size: UInt64) {
        self.path = path
        self.appName = appName
        self.crashDate = crashDate
        self.reportType = reportType
        self.size = size
    }
}

/// Summary of crash reports for a specific app
public struct AppCrashSummary: Sendable {
    public let appName: String
    public let reportCount: Int
    public let latestCrashDate: Date
    public let oldestCrashDate: Date
    public let totalSize: UInt64
    public let hasRepeatedCrashes: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    public var latestCrashRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: latestCrashDate, relativeTo: Date())
    }

    public init(
        appName: String,
        reportCount: Int,
        latestCrashDate: Date,
        oldestCrashDate: Date,
        totalSize: UInt64
    ) {
        self.appName = appName
        self.reportCount = reportCount
        self.latestCrashDate = latestCrashDate
        self.oldestCrashDate = oldestCrashDate
        self.totalSize = totalSize
        // More than 5 reports is considered repeated crashes
        self.hasRepeatedCrashes = reportCount > 5
    }
}

/// Complete analysis result for crash reports
public struct CrashReportAnalysis: Sendable {
    public let summaries: [AppCrashSummary]
    public let totalReports: Int
    public let totalSize: UInt64
    public let reportsOlderThan30Days: Int
    public let sizeOlderThan30Days: UInt64

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    public var formattedOlderSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeOlderThan30Days), countStyle: .file)
    }

    public init(
        summaries: [AppCrashSummary],
        totalReports: Int,
        totalSize: UInt64,
        reportsOlderThan30Days: Int,
        sizeOlderThan30Days: UInt64
    ) {
        self.summaries = summaries
        self.totalReports = totalReports
        self.totalSize = totalSize
        self.reportsOlderThan30Days = reportsOlderThan30Days
        self.sizeOlderThan30Days = sizeOlderThan30Days
    }
}

// MARK: - Crash Report Analysis Service

/// Service for analyzing crash reports
///
/// This service provides functionality to:
/// - Parse crash report files (.crash, .spin, .hang, .diag)
/// - Extract app name and crash date from reports
/// - Aggregate crash counts by app
/// - Identify apps with repeated crashes
public final class CrashReportAnalysisService: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = CrashReportAnalysisService()

    // MARK: - Properties

    private let fileManager: FileManager
    private let diagnosticReportsPath: String

    // MARK: - Initialization

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.diagnosticReportsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")
            .path
    }

    // MARK: - Public Methods

    /// Analyze all crash reports in the DiagnosticReports directory
    /// - Returns: Complete analysis of crash reports
    public func analyze() async throws -> CrashReportAnalysis {
        let reports = try await collectCrashReports()
        return aggregateReports(reports)
    }

    /// Check if there are crash reports to analyze
    public func hasCrashReports() -> Bool {
        guard fileManager.fileExists(atPath: diagnosticReportsPath) else {
            return false
        }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: diagnosticReportsPath)
            return contents.contains { file in
                CrashReport.ReportType.allCases.contains { type in
                    file.hasSuffix(type.rawValue)
                }
            }
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func collectCrashReports() async throws -> [CrashReport] {
        guard fileManager.fileExists(atPath: diagnosticReportsPath) else {
            return []
        }

        var reports: [CrashReport] = []

        guard let enumerator = fileManager.enumerator(atPath: diagnosticReportsPath) else {
            return []
        }

        while let file = enumerator.nextObject() as? String {
            // Check if this is a crash report file
            guard let reportType = CrashReport.ReportType.allCases.first(where: { file.hasSuffix($0.rawValue) }) else {
                continue
            }

            let fullPath = (diagnosticReportsPath as NSString).appendingPathComponent(file)

            // Get file attributes
            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                  let modificationDate = attrs[.modificationDate] as? Date,
                  let size = attrs[.size] as? UInt64 else {
                continue
            }

            // Parse app name from filename
            // Format: AppName_YYYY-MM-DD-HHMMSS_MachineName.crash
            // or: AppName-YYYY-MM-DD-HHMMSS.crash
            let appName = extractAppName(from: file)

            let report = CrashReport(
                path: fullPath,
                appName: appName,
                crashDate: modificationDate,
                reportType: reportType,
                size: size
            )
            reports.append(report)
        }

        return reports
    }

    private func extractAppName(from filename: String) -> String {
        // Remove extension
        var name = filename
        for type in CrashReport.ReportType.allCases {
            if name.hasSuffix(type.rawValue) {
                name = String(name.dropLast(type.rawValue.count))
                break
            }
        }

        // Split by common separators and get the first part (app name)
        // Formats:
        // - AppName_2025-01-15-120000_MachineName
        // - AppName-2025-01-15-120000
        // - AppName_YYYY-MM-DD-HHMMSS

        // Try underscore first
        if let underscoreIndex = name.firstIndex(of: "_") {
            return String(name[..<underscoreIndex])
        }

        // Try to find date pattern (YYYY-MM-DD) and extract what's before it
        let datePattern = #"[-_]\d{4}-\d{2}-\d{2}"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range, in: name) {
            let beforeDate = String(name[..<range.lowerBound])
            return beforeDate.isEmpty ? name : beforeDate
        }

        return name
    }

    private func aggregateReports(_ reports: [CrashReport]) -> CrashReportAnalysis {
        // Group by app name
        let groupedByApp = Dictionary(grouping: reports) { $0.appName }

        // Calculate 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        var summaries: [AppCrashSummary] = []
        var reportsOlderThan30Days = 0
        var sizeOlderThan30Days: UInt64 = 0

        for (appName, appReports) in groupedByApp {
            let sortedReports = appReports.sorted { $0.crashDate > $1.crashDate }

            guard let latest = sortedReports.first,
                  let oldest = sortedReports.last else {
                continue
            }

            let totalSize = appReports.reduce(0) { $0 + $1.size }

            let summary = AppCrashSummary(
                appName: appName,
                reportCount: appReports.count,
                latestCrashDate: latest.crashDate,
                oldestCrashDate: oldest.crashDate,
                totalSize: totalSize
            )
            summaries.append(summary)

            // Count reports older than 30 days
            for report in appReports where report.crashDate < thirtyDaysAgo {
                reportsOlderThan30Days += 1
                sizeOlderThan30Days += report.size
            }
        }

        // Sort summaries by report count (descending)
        summaries.sort { $0.reportCount > $1.reportCount }

        return CrashReportAnalysis(
            summaries: summaries,
            totalReports: reports.count,
            totalSize: reports.reduce(0) { $0 + $1.size },
            reportsOlderThan30Days: reportsOlderThan30Days,
            sizeOlderThan30Days: sizeOlderThan30Days
        )
    }
}

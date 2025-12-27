// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Dashboard view showing disk usage overview
struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var diskInfo: DiskSpaceInfo?
    @State private var isAnalyzing = false
    @State private var isCleaning = false
    @State private var cleanupOpportunities: [CleanupOpportunity] = []
    @State private var showCleanupResult = false
    @State private var lastCleanResult: CleanResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Disk Usage Overview
                diskUsageCard

                // Quick Actions
                quickActionsSection

                // Cleanup Opportunities
                cleanupOpportunitiesSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refreshData() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isAnalyzing)
            }
        }
        .task {
            await refreshData()
        }
    }

    // MARK: - Disk Usage Card

    private var diskUsageCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Disk Usage")
                            .font(.headline)
                        Text("Macintosh HD")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let info = diskInfo {
                    DiskUsageBar(
                        used: info.usedSpace,
                        total: info.totalSpace
                    )

                    HStack {
                        UsageLabel(
                            title: "Used",
                            value: info.formattedUsed,
                            color: .blue
                        )
                        Spacer()
                        UsageLabel(
                            title: "Available",
                            value: info.formattedAvailable,
                            color: .green
                        )
                        Spacer()
                        UsageLabel(
                            title: "Total",
                            value: info.formattedTotal,
                            color: .secondary
                        )
                    }
                } else {
                    Text("Analyzing disk...")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        GroupBox("Quick Actions") {
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Light Clean",
                    subtitle: "Safe items only",
                    icon: "sparkles",
                    color: .green,
                    isLoading: isCleaning
                ) {
                    Task { await performCleanup(.light) }
                }

                QuickActionButton(
                    title: "Normal Clean",
                    subtitle: "Includes caches",
                    icon: "wind",
                    color: .orange,
                    isLoading: isCleaning
                ) {
                    Task { await performCleanup(.normal) }
                }

                QuickActionButton(
                    title: "Deep Clean",
                    subtitle: "Developer caches",
                    icon: "tornado",
                    color: .red,
                    isLoading: isCleaning
                ) {
                    Task { await performCleanup(.deep) }
                }
            }
            .padding(.vertical, 8)
        }
        .alert("Cleanup Complete", isPresented: $showCleanupResult) {
            Button("OK") {}
        } message: {
            if let result = lastCleanResult {
                Text("Freed \(result.formattedFreedSpace) by removing \(result.filesRemoved) files.")
            }
        }
    }

    // MARK: - Cleanup Opportunities

    private var cleanupOpportunitiesSection: some View {
        GroupBox("Cleanup Opportunities") {
            VStack(alignment: .leading, spacing: 12) {
                if cleanupOpportunities.isEmpty {
                    Text("Analyzing...")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(cleanupOpportunities) { opportunity in
                        CleanupOpportunityRow(
                            category: opportunity.category,
                            icon: opportunity.icon,
                            size: opportunity.formattedSize,
                            safety: opportunity.safety
                        )
                        if opportunity.id != cleanupOpportunities.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Helper Methods

    private func refreshData() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Get disk space info
        diskInfo = appState.getDiskSpace()

        // Analyze cleanup opportunities
        do {
            let config = AnalyzerConfiguration(
                targetPath: "~",
                minSize: 10_000_000, // Minimum 10MB
                verbose: false,
                includeHidden: false
            )
            let result = try await appState.analyzerService.analyze(with: config)

            cleanupOpportunities = result.categories.map { category in
                CleanupOpportunity(
                    category: category.name,
                    icon: iconForCategory(category.name),
                    size: category.size,
                    safety: safetyForCategory(category.name)
                )
            }.filter { $0.size > 0 }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func performCleanup(_ level: CleanupLevel) async {
        isCleaning = true
        defer { isCleaning = false }

        do {
            let config = CleanerConfiguration(
                cleanupLevel: level,
                dryRun: false,
                includeSystemCaches: level == .deep || level == .system,
                includeDeveloperCaches: level == .deep || level == .system,
                includeBrowserCaches: true,
                includeLogsCaches: level != .light,
                specificPaths: []
            )

            let result = try await appState.cleanerService.clean(with: config)
            lastCleanResult = result
            showCleanupResult = true

            // Refresh data after cleanup
            await refreshData()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func iconForCategory(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("browser"): return "globe"
        case let n where n.contains("developer"): return "hammer"
        case let n where n.contains("system"): return "gearshape.2"
        case let n where n.contains("log"): return "doc.text"
        case let n where n.contains("download"): return "arrow.down.circle"
        default: return "app.badge"
        }
    }

    private func safetyForCategory(_ name: String) -> SafetyLevel {
        switch name.lowercased() {
        case let n where n.contains("browser"): return .safe
        case let n where n.contains("developer"): return .caution
        case let n where n.contains("system"): return .warning
        case let n where n.contains("log"): return .safe
        case let n where n.contains("download"): return .danger
        default: return .caution
        }
    }
}

// MARK: - Cleanup Opportunity Model

struct CleanupOpportunity: Identifiable {
    let id = UUID()
    let category: String
    let icon: String
    let size: UInt64
    let safety: SafetyLevel

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - Supporting Views

struct DiskUsageBar: View {
    let used: UInt64
    let total: UInt64

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    private var barColor: Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.75 { return .orange }
        return .blue
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geometry.size.width * percentage)
            }
        }
        .frame(height: 20)
    }
}

struct UsageLabel: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 28)
                } else {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct CleanupOpportunityRow: View {
    let category: String
    let icon: String
    let size: String
    let safety: SafetyLevel

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(category)
                    .font(.body)
                Text(safety.displayText)
                    .font(.caption)
                    .foregroundStyle(safety.color)
            }

            Spacer()

            Text(size)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Safety level for cleanup items
enum SafetyLevel {
    case safe
    case caution
    case warning
    case danger

    var displayText: String {
        switch self {
        case .safe: return "✅ Safe to delete"
        case .caution: return "⚠️ Requires rebuild"
        case .warning: return "⚠️⚠️ Re-download needed"
        case .danger: return "❌ Do not delete"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}

// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Clean view for selecting and executing cleanup operations
struct CleanView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedLevel: GUICleanupLevel = .normal
    @State private var selectedTargets: Set<CleanupTarget> = [.all]
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var scanResults: [CleanupItem] = []
    @State private var showConfirmation = false
    @State private var cleanupProgress: Double = 0
    @State private var lastCleanResult: CleanResult?

    var body: some View {
        HSplitView {
            // Left panel: Options
            optionsPanel
                .frame(minWidth: 250, maxWidth: 300)

            // Right panel: Results
            resultsPanel
        }
        .navigationTitle("Clean")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await scanForCleanup() }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(isScanning || isCleaning)

                Button {
                    showConfirmation = true
                } label: {
                    Label("Clean", systemImage: "trash")
                }
                .disabled(scanResults.isEmpty || isCleaning)
            }
        }
        .alert("Confirm Cleanup", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await performCleanup() }
            }
        } message: {
            Text("This will delete \(scanResults.count) items. This action cannot be undone.")
        }
    }

    // MARK: - Options Panel

    private var optionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cleanup Level
                GroupBox("Cleanup Level") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(GUICleanupLevel.allCases, id: \.self) { level in
                            CleanupLevelRow(
                                level: level,
                                isSelected: selectedLevel == level
                            ) {
                                selectedLevel = level
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Cleanup Targets
                GroupBox("Targets") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(CleanupTarget.allCases, id: \.self) { target in
                            Toggle(isOn: Binding(
                                get: { selectedTargets.contains(target) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedTargets.insert(target)
                                    } else {
                                        selectedTargets.remove(target)
                                    }
                                }
                            )) {
                                Label(target.displayName, systemImage: target.icon)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Results Panel

    private var resultsPanel: some View {
        VStack {
            if isScanning {
                ProgressView("Scanning...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanResults.isEmpty {
                ContentUnavailableView(
                    "No Scan Results",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Click 'Scan' to find items to clean up.")
                )
            } else {
                List(scanResults) { item in
                    CleanupItemRow(item: item)
                }
                .listStyle(.inset)

                // Summary
                HStack {
                    Text("\(scanResults.count) items")
                    Spacer()
                    Text("Total: \(formatTotalSize())")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    // MARK: - Actions

    private func scanForCleanup() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let config = AnalyzerConfiguration(
                targetPath: "~",
                minSize: 1_000_000, // Minimum 1MB
                verbose: false,
                includeHidden: false
            )

            let result = try await appState.analyzerService.analyze(with: config)

            // Convert analysis results to cleanup items
            scanResults = result.categories.flatMap { category in
                category.topItems.map { item in
                    CleanupItem(
                        name: item.path.components(separatedBy: "/").last ?? item.path,
                        path: item.path,
                        size: item.size,
                        safety: safetyLevel(for: category.name)
                    )
                }
            }
        } catch {
            appState.lastError = error.localizedDescription
            scanResults = []
        }
    }

    private func performCleanup() async {
        isCleaning = true
        cleanupProgress = 0
        defer {
            isCleaning = false
            cleanupProgress = 0
        }

        do {
            let config = CleanerConfiguration(
                cleanupLevel: selectedLevel.toBackendLevel(),
                dryRun: false,
                includeSystemCaches: selectedTargets.contains(.system) || selectedTargets.contains(.all),
                includeDeveloperCaches: selectedTargets.contains(.developer) || selectedTargets.contains(.all),
                includeBrowserCaches: selectedTargets.contains(.browser) || selectedTargets.contains(.all),
                includeLogsCaches: selectedTargets.contains(.logs) || selectedTargets.contains(.all),
                specificPaths: []
            )

            let result = try await appState.cleanerService.clean(with: config)
            lastCleanResult = result
            scanResults.removeAll()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func safetyLevel(for categoryName: String) -> SafetyLevel {
        switch categoryName.lowercased() {
        case let name where name.contains("browser"):
            return .safe
        case let name where name.contains("developer"):
            return .caution
        case let name where name.contains("system"):
            return .warning
        case let name where name.contains("log"):
            return .safe
        default:
            return .caution
        }
    }

    private func formatTotalSize() -> String {
        let total = scanResults.reduce(0) { $0 + $1.size }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(total))
    }
}

// MARK: - Supporting Types

/// GUI-specific cleanup level that maps to backend CleanupLevel
enum GUICleanupLevel: String, CaseIterable {
    case light = "Light"
    case normal = "Normal"
    case deep = "Deep"

    var description: String {
        switch self {
        case .light: return "Safe items only (trash, browser cache)"
        case .normal: return "Includes user caches and old logs"
        case .deep: return "Developer caches and unused data"
        }
    }

    var color: Color {
        switch self {
        case .light: return .green
        case .normal: return .orange
        case .deep: return .red
        }
    }

    /// Convert to backend CleanupLevel
    func toBackendLevel() -> CleanupLevel {
        switch self {
        case .light: return .light
        case .normal: return .normal
        case .deep: return .deep
        }
    }
}

enum CleanupTarget: String, CaseIterable {
    case all = "All"
    case browser = "Browser"
    case developer = "Developer"
    case logs = "Logs"
    case system = "System"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .browser: return "globe"
        case .developer: return "hammer"
        case .logs: return "doc.text"
        case .system: return "gearshape.2"
        }
    }
}

struct CleanupItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let safety: SafetyLevel
}

// MARK: - Supporting Views

struct CleanupLevelRow: View {
    let level: GUICleanupLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? level.color : .secondary)

                VStack(alignment: .leading) {
                    Text(level.rawValue)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CleanupItemRow: View {
    let item: CleanupItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(formatSize(item.size))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.safety.displayText)
                    .font(.caption2)
                    .foregroundStyle(item.safety.color)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    CleanView()
        .environmentObject(AppState())
}

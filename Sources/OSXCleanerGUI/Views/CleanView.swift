// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Clean view for selecting and executing cleanup operations
struct CleanView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedLevel: CleanupLevel = .normal
    @State private var selectedTargets: Set<CleanupTarget> = [.all]
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var scanResults: [CleanupItem] = []
    @State private var showConfirmation = false

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
                        ForEach(CleanupLevel.allCases, id: \.self) { level in
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

        // TODO: Implement actual scanning using CleanerService
        // Simulated results for now
        try? await Task.sleep(for: .seconds(1))
        scanResults = [
            CleanupItem(name: "Browser Cache", path: "~/Library/Caches/com.apple.Safari", size: 1_500_000_000, safety: .safe),
            CleanupItem(name: "Xcode DerivedData", path: "~/Library/Developer/Xcode/DerivedData", size: 8_000_000_000, safety: .caution),
            CleanupItem(name: "npm Cache", path: "~/.npm/_cacache", size: 2_000_000_000, safety: .safe)
        ]
    }

    private func performCleanup() async {
        isCleaning = true
        defer { isCleaning = false }

        // TODO: Implement actual cleanup using CleanerService
        try? await Task.sleep(for: .seconds(2))
        scanResults.removeAll()
    }

    private func formatTotalSize() -> String {
        let total = scanResults.reduce(0) { $0 + $1.size }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(total))
    }
}

// MARK: - Supporting Types

enum CleanupLevel: String, CaseIterable {
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
    let level: CleanupLevel
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

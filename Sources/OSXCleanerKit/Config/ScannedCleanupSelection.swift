// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

/// A cleanup candidate shown by a scan-based UI.
public struct ScannedCleanupSelectionItem: Equatable, Sendable {
    public let path: String
    public let size: UInt64
    public let isSelected: Bool

    public init(path: String, size: UInt64, isSelected: Bool = true) {
        self.path = path
        self.size = size
        self.isSelected = isSelected
    }
}

/// Count, size, and path data for selected scan results.
public struct CleanupSelectionSummary: Equatable, Sendable {
    public let selectedItemCount: Int
    public let selectedTotalSize: UInt64
    public let selectedPaths: [String]

    public var hasSelection: Bool {
        !selectedPaths.isEmpty
    }

    public init(selectedItemCount: Int, selectedTotalSize: UInt64, selectedPaths: [String]) {
        self.selectedItemCount = selectedItemCount
        self.selectedTotalSize = selectedTotalSize
        self.selectedPaths = selectedPaths
    }
}

/// Builds scan-result cleanup summaries and configurations.
public enum ScannedCleanupSelection {
    public static func summary(for items: [ScannedCleanupSelectionItem]) -> CleanupSelectionSummary {
        let selectedItems = items.filter(\.isSelected)
        return CleanupSelectionSummary(
            selectedItemCount: selectedItems.count,
            selectedTotalSize: selectedItems.reduce(0) { $0 + $1.size },
            selectedPaths: selectedItems.map(\.path)
        )
    }

    public static func makeConfiguration(
        cleanupLevel: CleanupLevel,
        dryRun: Bool = false,
        items: [ScannedCleanupSelectionItem]
    ) -> CleanerConfiguration? {
        let summary = summary(for: items)
        guard summary.hasSelection else {
            return nil
        }

        return CleanerConfiguration(
            cleanupLevel: cleanupLevel,
            dryRun: dryRun,
            includeSystemCaches: false,
            includeDeveloperCaches: false,
            includeBrowserCaches: false,
            includeLogsCaches: false,
            specificPaths: summary.selectedPaths
        )
    }
}

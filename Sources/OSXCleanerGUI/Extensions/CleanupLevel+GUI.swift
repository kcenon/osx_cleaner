// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// GUI extensions for CleanupLevel
extension CleanupLevel {
    /// Display name for GUI
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .normal: return "Normal"
        case .deep: return "Deep"
        case .system: return "System"
        }
    }

    /// Color for GUI
    var color: Color {
        switch self {
        case .light: return .green
        case .normal: return .orange
        case .deep: return .red
        case .system: return .purple
        }
    }
}

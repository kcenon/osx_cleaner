// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

@main
struct OSXCleanerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    // Future: Check for updates
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

/// Application-wide state management
@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    let cleanerService: CleanerService
    let analyzerService: AnalyzerService
    let diskMonitoringService: DiskMonitoringService

    init() {
        self.cleanerService = CleanerService()
        self.analyzerService = AnalyzerService()
        self.diskMonitoringService = DiskMonitoringService.shared
    }

    func getDiskSpace() -> DiskSpaceInfo? {
        try? diskMonitoringService.getDiskSpace()
    }
}

/// App navigation tabs
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case clean = "Clean"
    case schedule = "Schedule"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .clean: return "trash.circle"
        case .schedule: return "calendar.badge.clock"
        case .settings: return "gearshape"
        }
    }
}

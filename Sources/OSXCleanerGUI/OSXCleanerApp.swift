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
                Button(L("menu.checkForUpdates")) {
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
    let schedulerService: SchedulerService
    let configurationService: ConfigurationService

    init() {
        self.cleanerService = CleanerService()
        self.analyzerService = AnalyzerService()
        self.diskMonitoringService = DiskMonitoringService.shared
        self.schedulerService = SchedulerService()
        self.configurationService = ConfigurationService()
    }

    func getDiskSpace() -> DiskSpaceInfo? {
        try? diskMonitoringService.getDiskSpace()
    }
}

/// App navigation tabs
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case clean
    case schedule
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard: return L("nav.dashboard")
        case .clean: return L("nav.clean")
        case .schedule: return L("nav.schedule")
        case .settings: return L("nav.settings")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .clean: return "trash.circle"
        case .schedule: return "calendar.badge.clock"
        case .settings: return "gearshape"
        }
    }
}

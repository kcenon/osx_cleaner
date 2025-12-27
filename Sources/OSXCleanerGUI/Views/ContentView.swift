// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI

/// Main content view with tab-based navigation
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            selectedView
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var selectedView: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .clean:
            CleanView()
        case .schedule:
            ScheduleView()
        case .settings:
            SettingsView()
        }
    }
}

/// Sidebar navigation
struct Sidebar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(AppTab.allCases, selection: $appState.selectedTab) { tab in
            NavigationLink(value: tab) {
                Label(tab.displayName, systemImage: tab.icon)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(L("app.title"))
        .frame(minWidth: 180)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

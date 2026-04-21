// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI

/// Main content view with tab-based navigation
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.rustFallbackActive {
                FallbackModeBanner(reason: appState.rustFallbackReason)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            NavigationSplitView {
                Sidebar()
            } detail: {
                selectedView
            }
            .navigationSplitViewStyle(.balanced)
        }
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

/// Persistent banner shown at the top of the window when the Rust core
/// failed to initialize and the app is running the Swift fallback.
///
/// The banner has no dismiss affordance — fallback state persists until
/// the app restarts with a working Rust core, and silently hiding the
/// banner would defeat its purpose (telling the user why performance is
/// degraded).
struct FallbackModeBanner: View {
    let reason: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("banner.fallback.title"))
                    .font(.headline)
                if let reason, !reason.isEmpty {
                    Text(String(format: L("banner.fallback.reason"), reason))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(L("banner.fallback.body"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(Color.orange.opacity(0.4))
                .frame(height: 1),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
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

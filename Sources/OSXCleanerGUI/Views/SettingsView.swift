// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Settings view for configuring application preferences
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("diskThreshold") private var diskThreshold = 85
    @AppStorage("autoCleanupEnabled") private var autoCleanupEnabled = false
    @AppStorage("autoCleanupLevel") private var autoCleanupLevel = "light"
    @AppStorage("confirmBeforeCleanup") private var confirmBeforeCleanup = true
    @AppStorage("keepRecentLogs") private var keepRecentLogs = 30

    var body: some View {
        Form {
            // General Settings
            Section("General") {
                Toggle("Show notifications", isOn: $showNotifications)

                Toggle("Confirm before cleanup", isOn: $confirmBeforeCleanup)

                Picker("Keep logs for", selection: $keepRecentLogs) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            }

            // Disk Monitoring
            Section("Disk Monitoring") {
                Slider(
                    value: Binding(
                        get: { Double(diskThreshold) },
                        set: { diskThreshold = Int($0) }
                    ),
                    in: 70...95,
                    step: 5
                ) {
                    Text("Warning threshold")
                } minimumValueLabel: {
                    Text("70%")
                } maximumValueLabel: {
                    Text("95%")
                }

                Text("Notify when disk usage exceeds \(diskThreshold)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Auto Cleanup
            Section("Automatic Cleanup") {
                Toggle("Enable automatic cleanup", isOn: $autoCleanupEnabled)

                if autoCleanupEnabled {
                    Picker("Cleanup level", selection: $autoCleanupLevel) {
                        Text("Light").tag("light")
                        Text("Normal").tag("normal")
                    }

                    Text("Automatic cleanup runs when disk usage exceeds 95%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Protected Paths
            Section("Protected Paths") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The following paths are always protected from deletion:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        ProtectedPathRow(path: "/System/*", reason: "System files")
                        ProtectedPathRow(path: "/Applications/*", reason: "Applications")
                        ProtectedPathRow(path: "~/Documents/*", reason: "User documents")
                        ProtectedPathRow(path: "~/Desktop/*", reason: "Desktop files")
                        ProtectedPathRow(path: "~/.ssh/*", reason: "SSH keys")
                        ProtectedPathRow(path: "Keychains", reason: "Security credentials")
                    }
                    .padding(.leading, 8)
                }
            }

            // About
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Build", value: "Phase 3 Preview")

                Link(destination: URL(string: "https://github.com/kcenon/osx_cleaner")!) {
                    Label("GitHub Repository", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/kcenon/osx_cleaner/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 500)
    }
}

// MARK: - Supporting Views

struct ProtectedPathRow: View {
    let path: String
    let reason: String

    var body: some View {
        HStack {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(path)
                .font(.caption)
                .fontDesign(.monospaced)

            Spacer()

            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

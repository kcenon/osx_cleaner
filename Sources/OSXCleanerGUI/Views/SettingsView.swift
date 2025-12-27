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

    @State private var monitoringEnabled = false
    @State private var showSaveAlert = false
    @State private var errorMessage: String?

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
                Toggle("Enable disk monitoring", isOn: $monitoringEnabled)
                    .onChange(of: monitoringEnabled) { _, newValue in
                        toggleMonitoring(enabled: newValue)
                    }

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
                    .onChange(of: autoCleanupEnabled) { _, _ in
                        updateMonitoringConfig()
                    }

                if autoCleanupEnabled {
                    Picker("Cleanup level", selection: $autoCleanupLevel) {
                        Text("Light").tag("light")
                        Text("Normal").tag("normal")
                    }
                    .onChange(of: autoCleanupLevel) { _, _ in
                        updateMonitoringConfig()
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
        .onAppear {
            loadCurrentSettings()
        }
        .alert("Settings Saved", isPresented: $showSaveAlert) {
            Button("OK") {}
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Settings Management

    private func loadCurrentSettings() {
        let status = appState.diskMonitoringService.getStatus()
        monitoringEnabled = status.isEnabled

        if let config = status.config {
            autoCleanupEnabled = config.autoCleanupEnabled
            autoCleanupLevel = config.autoCleanupLevel
        }
    }

    private func toggleMonitoring(enabled: Bool) {
        do {
            if enabled {
                let config = MonitoringConfig(
                    autoCleanupEnabled: autoCleanupEnabled,
                    autoCleanupLevel: autoCleanupLevel,
                    checkIntervalSeconds: 3600,
                    notificationsEnabled: showNotifications,
                    warningThreshold: diskThreshold,
                    criticalThreshold: 90,
                    emergencyThreshold: 95
                )
                try appState.diskMonitoringService.enableMonitoring(config)
            } else {
                try appState.diskMonitoringService.disableMonitoring()
            }
        } catch {
            errorMessage = error.localizedDescription
            monitoringEnabled = !enabled // Revert
        }
    }

    private func updateMonitoringConfig() {
        guard monitoringEnabled else { return }

        let config = MonitoringConfig(
            autoCleanupEnabled: autoCleanupEnabled,
            autoCleanupLevel: autoCleanupLevel,
            checkIntervalSeconds: 3600,
            notificationsEnabled: showNotifications,
            warningThreshold: diskThreshold,
            criticalThreshold: 90,
            emergencyThreshold: 95
        )

        do {
            try appState.diskMonitoringService.enableMonitoring(config)
        } catch {
            errorMessage = error.localizedDescription
        }
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

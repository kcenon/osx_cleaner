// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Settings view for configuring application preferences
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var languageManager = LanguageManager.shared

    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("diskThreshold") private var diskThreshold = 85
    @AppStorage("autoCleanupEnabled") private var autoCleanupEnabled = false
    @AppStorage("autoCleanupLevel") private var autoCleanupLevel = "light"
    @AppStorage("confirmBeforeCleanup") private var confirmBeforeCleanup = true
    @AppStorage("keepRecentLogs") private var keepRecentLogs = 30

    @State private var monitoringEnabled = false
    @State private var showSaveAlert = false
    @State private var errorMessage: String?
    @State private var selectedLanguage: AppLanguage = .system

    var body: some View {
        Form {
            // Language Settings
            Section(L("settings.language")) {
                Picker(L("settings.language"), selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: selectedLanguage) { _, newValue in
                    languageManager.setLanguage(newValue)
                }

                Text(L("settings.language.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // General Settings
            Section(L("settings.general")) {
                Toggle(L("settings.showNotifications"), isOn: $showNotifications)

                Toggle(L("settings.confirmBeforeCleanup"), isOn: $confirmBeforeCleanup)

                Picker(L("settings.keepLogsFor"), selection: $keepRecentLogs) {
                    Text(L("settings.days", 7)).tag(7)
                    Text(L("settings.days", 14)).tag(14)
                    Text(L("settings.days", 30)).tag(30)
                    Text(L("settings.days", 90)).tag(90)
                }
            }

            // Disk Monitoring
            Section(L("settings.diskMonitoring")) {
                Toggle(L("settings.enableDiskMonitoring"), isOn: $monitoringEnabled)
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
                    Text(L("settings.warningThreshold"))
                } minimumValueLabel: {
                    Text("70%")
                } maximumValueLabel: {
                    Text("95%")
                }

                Text(L("settings.notifyWhenExceeds", diskThreshold))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Auto Cleanup
            Section(L("settings.automaticCleanup")) {
                Toggle(L("settings.enableAutomaticCleanup"), isOn: $autoCleanupEnabled)
                    .onChange(of: autoCleanupEnabled) { _, _ in
                        updateMonitoringConfig()
                    }

                if autoCleanupEnabled {
                    Picker(L("settings.cleanupLevel"), selection: $autoCleanupLevel) {
                        Text(L("cleanupLevel.light")).tag("light")
                        Text(L("cleanupLevel.normal")).tag("normal")
                    }
                    .onChange(of: autoCleanupLevel) { _, _ in
                        updateMonitoringConfig()
                    }

                    Text(L("settings.autoCleanupNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Protected Paths
            Section(L("settings.protectedPaths")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("settings.protectedPaths.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        ProtectedPathRow(path: "/System/*", reason: L("settings.protectedReason.system"))
                        ProtectedPathRow(path: "/Applications/*", reason: L("settings.protectedReason.applications"))
                        ProtectedPathRow(path: "~/Documents/*", reason: L("settings.protectedReason.documents"))
                        ProtectedPathRow(path: "~/Desktop/*", reason: L("settings.protectedReason.desktop"))
                        ProtectedPathRow(path: "~/.ssh/*", reason: L("settings.protectedReason.ssh"))
                        ProtectedPathRow(path: "Keychains", reason: L("settings.protectedReason.keychains"))
                    }
                    .padding(.leading, 8)
                }
            }

            // About
            Section(L("settings.about")) {
                LabeledContent(L("settings.version"), value: "0.1.0")
                LabeledContent(L("settings.build"), value: L("settings.buildPhase"))

                Link(destination: URL(string: "https://github.com/kcenon/osx_cleaner")!) {
                    Label(L("settings.github"), systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/kcenon/osx_cleaner/issues")!) {
                    Label(L("settings.reportIssue"), systemImage: "exclamationmark.bubble")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("settings.title"))
        .frame(minWidth: 500)
        .onAppear {
            loadCurrentSettings()
            selectedLanguage = languageManager.getLanguage()
        }
        .alert(L("settings.saved"), isPresented: $showSaveAlert) {
            Button(L("common.ok")) {}
        }
        .alert(L("settings.error"), isPresented: .constant(errorMessage != nil)) {
            Button(L("common.ok")) { errorMessage = nil }
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

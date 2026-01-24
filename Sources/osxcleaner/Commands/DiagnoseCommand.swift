// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct DiagnoseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagnose",
        abstract: "Diagnose OSX Cleaner installation and performance"
    )

    mutating func run() async throws {
        let progressView = ProgressView()

        progressView.display(message: "OSX Cleaner Diagnostics")
        progressView.display(message: "========================")
        progressView.display(message: "")

        // Check Rust core
        progressView.display(message: "Rust Core:")
        let rustBridge = RustBridge.shared
        do {
            try rustBridge.initialize()
            progressView.display(message: "  ✅ Status: Available")
            progressView.display(message: "  ✅ Library: Loaded successfully")
        } catch {
            progressView.display(message: "  ❌ Status: Unavailable")
            progressView.display(message: "  ❌ Error: \(error.localizedDescription)")
            progressView.display(message: "")
            progressView.display(message: "  Expected locations:")
            progressView.display(message: "    - /usr/local/lib/libosxcore.dylib")
            progressView.display(message: "    - ./libosxcore.dylib")
            progressView.display(message: "")
            progressView.display(message: "  Resolution:")
            progressView.display(message: "    Run: make install")
        }

        progressView.display(message: "")
        progressView.display(message: "Swift Fallback: Available")
        progressView.display(message: "")

        // System info
        progressView.display(message: "System Information:")
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        progressView.display(message: "  macOS: \(systemVersion)")

        let architecture = machineArchitecture()
        progressView.display(message: "  Architecture: \(architecture)")
        progressView.display(message: "")

        // Configuration
        progressView.display(message: "Configuration:")
        let configService = ConfigurationService()
        if let config = try? configService.load() {
            progressView.display(message: "  Performance warnings: \(config.showPerformanceWarnings ? "Enabled" : "Disabled")")
            progressView.display(message: "  Default cleanup level: \(config.defaultSafetyLevel)")
            progressView.display(message: "  Log level: \(config.logLevel)")
        } else {
            progressView.display(message: "  ⚠️  Using default configuration")
        }

        progressView.display(message: "")
    }

    private func machineArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

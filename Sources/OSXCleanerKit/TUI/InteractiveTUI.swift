// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - Menu State

/// Current menu state in the TUI
public enum MenuState {
    case main
    case analyze
    case clean
    case schedule
    case snapshot
    case config
    case monitor
    case help
    case confirmQuit
}

// MARK: - Menu Item

/// A menu item with display information
public struct MenuItem {
    let key: String
    let icon: String
    let label: String
    let description: String

    public init(key: String, icon: String, label: String, description: String = "") {
        self.key = key
        self.icon = icon
        self.label = label
        self.description = description
    }
}

// MARK: - Interactive TUI

/// Main interactive TUI class for OSX Cleaner
public final class InteractiveTUI {

    // MARK: - Properties

    private var isRunning = true
    private var currentState: MenuState = .main
    private var originalTermios: termios?
    private var statusMessage: String = ""
    private var statusIsError: Bool = false

    private let analyzerService: AnalyzerService
    private let cleanerService: CleanerService
    private let schedulerService: SchedulerService
    private let timeMachineService: TimeMachineService
    private let monitoringService: DiskMonitoringService
    private let configService: ConfigurationService

    private let version = "0.1.0"

    // MARK: - Menu Items

    private let mainMenuItems: [MenuItem] = [
        MenuItem(key: "1", icon: "📊", label: "Analyze Disk Usage", description: "View disk space analysis"),
        MenuItem(key: "2", icon: "🧹", label: "Quick Clean (Light)", description: "Safe cleanup of caches"),
        MenuItem(key: "3", icon: "🔧", label: "Normal Clean", description: "Standard cleanup"),
        MenuItem(key: "4", icon: "💪", label: "Deep Clean", description: "Thorough cleanup"),
        MenuItem(key: "5", icon: "⏰", label: "Manage Schedules", description: "Setup automated cleanup"),
        MenuItem(key: "6", icon: "📸", label: "Time Machine Snapshots", description: "Manage local snapshots"),
        MenuItem(key: "7", icon: "⚙️ ", label: "Configuration", description: "App settings"),
        MenuItem(key: "8", icon: "📈", label: "Monitoring Status", description: "Disk monitoring"),
        MenuItem(key: "h", icon: "❓", label: "Help", description: "Show help information")
    ]

    // MARK: - Initialization

    public init() {
        self.analyzerService = AnalyzerService()
        self.cleanerService = CleanerService()
        self.schedulerService = SchedulerService()
        self.timeMachineService = TimeMachineService()
        self.monitoringService = DiskMonitoringService()
        self.configService = ConfigurationService()
    }

    // MARK: - Public Methods

    /// Run the interactive TUI
    public func run() throws {
        // Setup terminal
        originalTermios = TerminalUtils.enableRawMode()
        TerminalUtils.hideCursor()

        // Setup signal handlers for clean exit
        setupSignalHandlers()

        defer {
            cleanup()
        }

        // Main loop
        while isRunning {
            render()
            handleInput()
        }
    }

    // MARK: - Rendering

    private func render() {
        TerminalUtils.clearScreen()

        let (rows, cols) = TerminalUtils.getTerminalSize()
        let contentWidth = min(cols - 4, 70)
        let startCol = max(1, (cols - contentWidth) / 2)

        drawHeader(width: contentWidth, startCol: startCol)
        drawDiskUsage(width: contentWidth, startCol: startCol, startRow: 4)

        switch currentState {
        case .main:
            drawMainMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .analyze:
            drawAnalyzeMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .clean:
            drawCleanMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .schedule:
            drawScheduleMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .snapshot:
            drawSnapshotMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .config:
            drawConfigMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .monitor:
            drawMonitorMenu(width: contentWidth, startCol: startCol, startRow: 9)
        case .help:
            drawHelpScreen(width: contentWidth, startCol: startCol, startRow: 9)
        case .confirmQuit:
            drawQuitConfirmation(width: contentWidth, startCol: startCol, startRow: 9)
        }

        drawStatusBar(width: contentWidth, startCol: startCol, startRow: rows - 2)
        drawFooter(width: contentWidth, startCol: startCol, startRow: rows - 1)

        TerminalUtils.flush()
    }

    private func drawHeader(width: Int, startCol: Int) {
        TerminalUtils.moveCursor(row: 1, col: startCol)
        TerminalUtils.setAttributes([.bold, .cyan])
        print(TerminalUtils.centerText("OSX Cleaner v\(version)", width: width), terminator: "")
        TerminalUtils.resetColor()

        TerminalUtils.moveCursor(row: 2, col: startCol)
        TerminalUtils.setColor(.dim)
        print(String(repeating: BoxChar.horizontal.rawValue, count: width), terminator: "")
        TerminalUtils.resetColor()
    }

    private func drawDiskUsage(width: Int, startCol: Int, startRow: Int) {
        let diskInfo = getDiskInfo()

        TerminalUtils.moveCursor(row: startRow, col: startCol)
        let usageText = "Disk Usage: \(diskInfo.usedFormatted) / \(diskInfo.totalFormatted) (\(String(format: "%.1f", diskInfo.usagePercent))%)"
        print(TerminalUtils.padRight(usageText, width: width), terminator: "")

        TerminalUtils.moveCursor(row: startRow + 1, col: startCol)
        let barWidth = width - 2
        let progressBar = TerminalUtils.drawColoredProgressBar(percent: diskInfo.usagePercent, width: barWidth)
        print(" \(progressBar) ", terminator: "")

        TerminalUtils.moveCursor(row: startRow + 2, col: startCol)
        TerminalUtils.setColor(.dim)
        print(String(repeating: BoxChar.horizontal.rawValue, count: width), terminator: "")
        TerminalUtils.resetColor()
    }

    private func drawMainMenu(width: Int, startCol: Int, startRow: Int) {
        TerminalUtils.moveCursor(row: startRow, col: startCol)
        TerminalUtils.setAttributes([.bold])
        print("Main Menu:", terminator: "")
        TerminalUtils.resetColor()

        for (index, item) in mainMenuItems.enumerated() {
            TerminalUtils.moveCursor(row: startRow + 2 + index, col: startCol + 2)
            TerminalUtils.setColor(.brightWhite)
            print("[\(item.key)] ", terminator: "")
            TerminalUtils.resetColor()
            print("\(item.icon) \(item.label)", terminator: "")
        }
    }

    private func drawAnalyzeMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Disk Analysis", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "📁", label: "Full Analysis", description: "Analyze all categories"),
            MenuItem(key: "2", icon: "🔨", label: "Xcode Only", description: "Analyze Xcode caches"),
            MenuItem(key: "3", icon: "🐳", label: "Docker Only", description: "Analyze Docker data"),
            MenuItem(key: "4", icon: "🌐", label: "Browser Only", description: "Analyze browser caches"),
            MenuItem(key: "5", icon: "📄", label: "Logs Only", description: "Analyze log files"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawCleanMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Cleanup Options", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "👀", label: "Preview (Dry Run)", description: "See what would be cleaned"),
            MenuItem(key: "2", icon: "✅", label: "Confirm & Clean", description: "Execute cleanup"),
            MenuItem(key: "3", icon: "🎯", label: "Select Targets", description: "Choose specific targets"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawScheduleMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Schedule Management", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "📋", label: "List Schedules", description: "View active schedules"),
            MenuItem(key: "2", icon: "➕", label: "Add Daily Schedule", description: "Add daily cleanup"),
            MenuItem(key: "3", icon: "➕", label: "Add Weekly Schedule", description: "Add weekly cleanup"),
            MenuItem(key: "4", icon: "🔄", label: "Toggle Schedule", description: "Enable/disable schedule"),
            MenuItem(key: "5", icon: "🗑️", label: "Remove Schedule", description: "Delete a schedule"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawSnapshotMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Time Machine Snapshots", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "📋", label: "List Snapshots", description: "View local snapshots"),
            MenuItem(key: "2", icon: "📊", label: "Snapshot Status", description: "Show snapshot status"),
            MenuItem(key: "3", icon: "✂️", label: "Thin Snapshots", description: "Remove old snapshots"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawConfigMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Configuration", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "👁️", label: "Show Current Config", description: "Display settings"),
            MenuItem(key: "2", icon: "📝", label: "Set Default Level", description: "Change cleanup level"),
            MenuItem(key: "3", icon: "🔄", label: "Reset to Defaults", description: "Restore defaults"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawMonitorMenu(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Disk Monitoring", width: width, startCol: startCol, startRow: startRow)

        let items = [
            MenuItem(key: "1", icon: "📊", label: "Check Status", description: "Current monitoring status"),
            MenuItem(key: "2", icon: "▶️", label: "Enable Monitoring", description: "Start disk monitoring"),
            MenuItem(key: "3", icon: "⏹️", label: "Disable Monitoring", description: "Stop disk monitoring"),
            MenuItem(key: "b", icon: "⬅️", label: "Back to Main Menu", description: "")
        ]

        drawMenuItems(items, width: width, startCol: startCol, startRow: startRow + 2)
    }

    private func drawHelpScreen(width: Int, startCol: Int, startRow: Int) {
        drawSubMenuHeader("Help & Information", width: width, startCol: startCol, startRow: startRow)

        let helpLines = [
            "",
            "OSX Cleaner is a safe disk cleanup utility for macOS.",
            "",
            "Navigation:",
            "  • Press number keys (1-9) to select menu items",
            "  • Press 'b' to go back to previous menu",
            "  • Press 'q' to quit the application",
            "  • Press 'h' for help at any time",
            "",
            "Cleanup Levels:",
            "  • Light: Safe caches only (temp files, browser caches)",
            "  • Normal: Standard cleanup (+ developer caches)",
            "  • Deep: Thorough cleanup (+ logs, old files)",
            "",
            "Safety:",
            "  • Protected paths are never deleted",
            "  • Running app caches are preserved",
            "  • Use dry-run to preview before cleanup",
            "",
            "Press 'b' to return to main menu"
        ]

        for (index, line) in helpLines.enumerated() {
            TerminalUtils.moveCursor(row: startRow + 2 + index, col: startCol + 2)
            print(line, terminator: "")
        }
    }

    private func drawQuitConfirmation(width: Int, startCol: Int, startRow: Int) {
        TerminalUtils.moveCursor(row: startRow + 2, col: startCol)
        TerminalUtils.setAttributes([.bold, .yellow])
        print("Are you sure you want to quit?", terminator: "")
        TerminalUtils.resetColor()

        TerminalUtils.moveCursor(row: startRow + 4, col: startCol + 2)
        print("[y] Yes, quit    [n] No, stay", terminator: "")
    }

    private func drawSubMenuHeader(_ title: String, width: Int, startCol: Int, startRow: Int) {
        TerminalUtils.moveCursor(row: startRow, col: startCol)
        TerminalUtils.setAttributes([.bold])
        print("\(title):", terminator: "")
        TerminalUtils.resetColor()
    }

    private func drawMenuItems(_ items: [MenuItem], width: Int, startCol: Int, startRow: Int) {
        for (index, item) in items.enumerated() {
            TerminalUtils.moveCursor(row: startRow + index, col: startCol + 2)
            TerminalUtils.setColor(.brightWhite)
            print("[\(item.key)] ", terminator: "")
            TerminalUtils.resetColor()
            print("\(item.icon) \(item.label)", terminator: "")
        }
    }

    private func drawStatusBar(width: Int, startCol: Int, startRow: Int) {
        TerminalUtils.moveCursor(row: startRow, col: startCol)

        if !statusMessage.isEmpty {
            if statusIsError {
                TerminalUtils.setColor(.red)
            } else {
                TerminalUtils.setColor(.green)
            }
            print(TerminalUtils.truncate(statusMessage, maxLength: width), terminator: "")
            TerminalUtils.resetColor()
        } else {
            print(String(repeating: " ", count: width), terminator: "")
        }
    }

    private func drawFooter(width: Int, startCol: Int, startRow: Int) {
        TerminalUtils.moveCursor(row: startRow, col: startCol)
        TerminalUtils.setColor(.dim)
        let footerText = currentState == .main
            ? "Press [q] to quit, [h] for help"
            : "Press [b] to go back, [q] to quit"
        print(TerminalUtils.centerText(footerText, width: width), terminator: "")
        TerminalUtils.resetColor()
    }

    // MARK: - Input Handling

    private func handleInput() {
        let key = TerminalUtils.readKey()

        // Clear status message on any input
        statusMessage = ""
        statusIsError = false

        switch currentState {
        case .main:
            handleMainMenuInput(key)
        case .analyze:
            handleAnalyzeInput(key)
        case .clean:
            handleCleanInput(key)
        case .schedule:
            handleScheduleInput(key)
        case .snapshot:
            handleSnapshotInput(key)
        case .config:
            handleConfigInput(key)
        case .monitor:
            handleMonitorInput(key)
        case .help:
            handleHelpInput(key)
        case .confirmQuit:
            handleQuitConfirmInput(key)
        }
    }

    private func handleMainMenuInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            currentState = .analyze
        case .char("2"):
            executeCleanup(level: .light)
        case .char("3"):
            executeCleanup(level: .normal)
        case .char("4"):
            executeCleanup(level: .deep)
        case .char("5"):
            currentState = .schedule
        case .char("6"):
            currentState = .snapshot
        case .char("7"):
            currentState = .config
        case .char("8"):
            currentState = .monitor
        case .char("h"), .char("H"):
            currentState = .help
        case .quit, .char("q"), .char("Q"):
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleAnalyzeInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            executeAnalysis(category: nil)
        case .char("2"):
            executeAnalysis(category: "xcode")
        case .char("3"):
            executeAnalysis(category: "docker")
        case .char("4"):
            executeAnalysis(category: "browser")
        case .char("5"):
            executeAnalysis(category: "logs")
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleCleanInput(_ key: KeyCode) {
        switch key {
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleScheduleInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            listSchedules()
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleSnapshotInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            listSnapshots()
        case .char("2"):
            showSnapshotStatus()
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleConfigInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            showConfig()
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleMonitorInput(_ key: KeyCode) {
        switch key {
        case .char("1"):
            checkMonitorStatus()
        case .char("b"), .char("B"), .escape:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleHelpInput(_ key: KeyCode) {
        switch key {
        case .char("b"), .char("B"), .escape, .enter:
            currentState = .main
        case .quit:
            currentState = .confirmQuit
        default:
            break
        }
    }

    private func handleQuitConfirmInput(_ key: KeyCode) {
        switch key {
        case .char("y"), .char("Y"):
            isRunning = false
        case .char("n"), .char("N"), .escape:
            currentState = .main
        default:
            break
        }
    }

    // MARK: - Actions

    private func executeCleanup(level: CleanupLevel) {
        setStatus("Running \(level.description) cleanup...", isError: false)
        render()

        let config = CleanerConfiguration(
            cleanupLevel: level,
            dryRun: false,
            includeSystemCaches: true,
            includeDeveloperCaches: true,
            includeBrowserCaches: true,
            includeLogsCaches: true,
            specificPaths: []
        )

        Task {
            do {
                let result = try await cleanerService.clean(with: config, triggerType: .manual)
                await MainActor.run {
                    setStatus("Cleanup complete! Freed \(result.formattedFreedSpace)", isError: false)
                }
            } catch {
                await MainActor.run {
                    setStatus("Cleanup failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func executeAnalysis(category: String?) {
        setStatus("Running analysis...", isError: false)
        render()

        Task {
            do {
                let config = AnalyzerConfiguration(
                    targetPath: FileManager.default.homeDirectoryForCurrentUser.path,
                    minSize: 1024 * 1024,
                    verbose: false,
                    includeHidden: false
                )

                let result = try await analyzerService.analyze(with: config)
                await MainActor.run {
                    setStatus("Analysis complete! Found \(result.formattedPotentialSavings) cleanable", isError: false)
                }
            } catch {
                await MainActor.run {
                    setStatus("Analysis failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func listSchedules() {
        let schedules = schedulerService.listSchedules()
        if schedules.isEmpty {
            setStatus("No schedules configured", isError: false)
        } else {
            setStatus("Found \(schedules.count) schedule(s)", isError: false)
        }
    }

    private func listSnapshots() {
        Task {
            do {
                let snapshots = try await timeMachineService.listLocalSnapshots()
                await MainActor.run {
                    if snapshots.isEmpty {
                        setStatus("No local snapshots found", isError: false)
                    } else {
                        setStatus("Found \(snapshots.count) snapshot(s)", isError: false)
                    }
                }
            } catch {
                await MainActor.run {
                    setStatus("Failed to list snapshots: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func showSnapshotStatus() {
        Task {
            do {
                let status = try await timeMachineService.getStatus()
                let snapshots = try await timeMachineService.listLocalSnapshots()
                await MainActor.run {
                    let statusText = status.isEnabled ? "Enabled" : "Disabled"
                    setStatus("Time Machine: \(statusText), Snapshots: \(snapshots.count)", isError: false)
                }
            } catch {
                await MainActor.run {
                    setStatus("Failed to get status: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func showConfig() {
        do {
            let config = try configService.load()
            let levelName: String
            switch config.defaultSafetyLevel {
            case 1: levelName = "Light"
            case 2: levelName = "Normal"
            case 3: levelName = "Deep"
            case 4: levelName = "System"
            default: levelName = "Unknown"
            }
            setStatus("Default level: \(levelName), Auto-backup: \(config.autoBackup)", isError: false)
        } catch {
            setStatus("Failed to load config: \(error.localizedDescription)", isError: true)
        }
    }

    private func checkMonitorStatus() {
        let status = monitoringService.getStatus()
        if status.isEnabled {
            let interval = status.config?.checkIntervalSeconds ?? 3600
            setStatus("Monitoring: Enabled (interval: \(interval)s)", isError: false)
        } else {
            setStatus("Monitoring: Disabled", isError: false)
        }
    }

    // MARK: - Helpers

    private func getDiskInfo() -> (
        total: UInt64,
        used: UInt64,
        available: UInt64,
        usagePercent: Double,
        totalFormatted: String,
        usedFormatted: String,
        availableFormatted: String
    ) {
        let fileManager = FileManager.default

        do {
            let attrs = try fileManager.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )

            let total = attrs[.systemSize] as? UInt64 ?? 0
            let free = attrs[.systemFreeSize] as? UInt64 ?? 0
            let used = total - free
            let usagePercent = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0

            return (
                total: total,
                used: used,
                available: free,
                usagePercent: usagePercent,
                totalFormatted: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file),
                usedFormatted: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file),
                availableFormatted: ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
            )
        } catch {
            return (0, 0, 0, 0, "N/A", "N/A", "N/A")
        }
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    // MARK: - Cleanup

    private func cleanup() {
        TerminalUtils.showCursor()
        TerminalUtils.clearScreen()
        TerminalUtils.resetColor()

        if let originalTermios = originalTermios {
            TerminalUtils.restoreTerminalMode(originalTermios)
        }

        print("Goodbye!")
    }

    private func setupSignalHandlers() {
        signal(SIGINT) { _ in
            TerminalUtils.showCursor()
            TerminalUtils.resetColor()
            print("\n")
            exit(0)
        }

        signal(SIGTERM) { _ in
            TerminalUtils.showCursor()
            TerminalUtils.resetColor()
            exit(0)
        }
    }
}

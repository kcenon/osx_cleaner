// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct InteractiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "interactive",
        abstract: "Launch interactive menu interface",
        discussion: """
            Starts an interactive terminal-based user interface for OSX Cleaner.
            Navigate using number keys to select options and 'q' to quit.

            The interactive mode provides:
              • Visual disk usage display
              • Easy access to all cleanup operations
              • Schedule management
              • Time Machine snapshot control
              • Configuration settings

            Examples:
              osxcleaner interactive
              osxcleaner i
            """
    )

    // MARK: - Run

    mutating func run() throws {
        // Check if running in a TTY
        guard isatty(STDIN_FILENO) != 0 else {
            print("Error: Interactive mode requires a terminal (TTY)")
            print("Use standard commands for non-interactive usage:")
            print("  osxcleaner analyze")
            print("  osxcleaner clean --level normal")
            throw ExitCode.generalError
        }

        let tui = InteractiveTUI()
        try tui.run()
    }
}

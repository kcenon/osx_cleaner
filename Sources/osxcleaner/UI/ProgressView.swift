// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import OSXCleanerKit

/// Simple progress display for CLI output
public struct ProgressView {
    private let output: FileHandle
    private let useColors: Bool

    public init(output: FileHandle = .standardOutput, useColors: Bool? = nil) {
        self.output = output
        self.useColors = useColors ?? ErrorFormatter.terminalSupportsColors
    }

    public func display(message: String) {
        let data = Data((message + "\n").utf8)
        output.write(data)
    }

    public func displayProgress(current: Int, total: Int, description: String) {
        let percentage = total > 0 ? (current * 100) / total : 0
        let barWidth = 30
        let filledWidth = (percentage * barWidth) / 100
        let emptyWidth = barWidth - filledWidth

        let bar = String(repeating: "█", count: filledWidth) +
                  String(repeating: "░", count: emptyWidth)

        let message = "\r[\(bar)] \(percentage)% - \(description)"
        let data = Data(message.utf8)
        output.write(data)
    }

    public func clearLine() {
        let clearSequence = "\r" + String(repeating: " ", count: 80) + "\r"
        let data = Data(clearSequence.utf8)
        output.write(data)
    }

    public func displayError(_ error: Error) {
        let message = ErrorFormatter.format(error, useColors: useColors) + "\n"
        FileHandle.standardError.write(Data(message.utf8))
    }

    public func displayWarning(_ warning: String) {
        display(message: "Warning: \(warning)")
    }

    public func displaySuccess(_ message: String) {
        display(message: "Success: \(message)")
    }
}

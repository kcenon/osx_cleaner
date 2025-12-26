// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation

// MARK: - ANSI Color Codes

/// ANSI color codes for terminal output
public enum ANSIColor: String {
    // Standard colors
    case black = "30"
    case red = "31"
    case green = "32"
    case yellow = "33"
    case blue = "34"
    case magenta = "35"
    case cyan = "36"
    case white = "37"

    // Bright colors
    case brightBlack = "90"
    case brightRed = "91"
    case brightGreen = "92"
    case brightYellow = "93"
    case brightBlue = "94"
    case brightMagenta = "95"
    case brightCyan = "96"
    case brightWhite = "97"

    // Background colors
    case bgBlack = "40"
    case bgRed = "41"
    case bgGreen = "42"
    case bgYellow = "43"
    case bgBlue = "44"
    case bgMagenta = "45"
    case bgCyan = "46"
    case bgWhite = "47"

    // Special
    case reset = "0"
    case bold = "1"
    case dim = "2"
    case underline = "4"
    case blink = "5"
    case reverse = "7"
}

// MARK: - Box Drawing Characters

/// Unicode box drawing characters for TUI borders
public enum BoxChar: String {
    case horizontal = "─"
    case vertical = "│"
    case topLeft = "┌"
    case topRight = "┐"
    case bottomLeft = "└"
    case bottomRight = "┘"
    case teeLeft = "├"
    case teeRight = "┤"
    case teeTop = "┬"
    case teeBottom = "┴"
    case cross = "┼"

    // Double line variants
    case doubleHorizontal = "═"
    case doubleVertical = "║"
    case doubleTopLeft = "╔"
    case doubleTopRight = "╗"
    case doubleBottomLeft = "╚"
    case doubleBottomRight = "╝"

    // Progress bar characters
    case progressFull = "█"
    case progressEmpty = "░"
    case progressHalf = "▓"
}

// MARK: - Terminal Utilities

/// Utility class for terminal control using ANSI escape sequences
public struct TerminalUtils {

    // MARK: - Escape Sequences

    /// ANSI escape sequence prefix
    private static let escape = "\u{1B}["

    // MARK: - Screen Control

    /// Clear the entire screen
    public static func clearScreen() {
        print("\(escape)2J", terminator: "")
        moveCursor(row: 1, col: 1)
    }

    /// Clear from cursor to end of screen
    public static func clearToEnd() {
        print("\(escape)J", terminator: "")
    }

    /// Clear from cursor to end of line
    public static func clearLine() {
        print("\(escape)K", terminator: "")
    }

    /// Clear the entire current line
    public static func clearEntireLine() {
        print("\(escape)2K", terminator: "")
    }

    // MARK: - Cursor Control

    /// Move cursor to specified position (1-based)
    public static func moveCursor(row: Int, col: Int) {
        print("\(escape)\(row);\(col)H", terminator: "")
    }

    /// Move cursor up by n rows
    public static func cursorUp(_ n: Int = 1) {
        print("\(escape)\(n)A", terminator: "")
    }

    /// Move cursor down by n rows
    public static func cursorDown(_ n: Int = 1) {
        print("\(escape)\(n)B", terminator: "")
    }

    /// Move cursor right by n columns
    public static func cursorRight(_ n: Int = 1) {
        print("\(escape)\(n)C", terminator: "")
    }

    /// Move cursor left by n columns
    public static func cursorLeft(_ n: Int = 1) {
        print("\(escape)\(n)D", terminator: "")
    }

    /// Save cursor position
    public static func saveCursor() {
        print("\(escape)s", terminator: "")
    }

    /// Restore cursor position
    public static func restoreCursor() {
        print("\(escape)u", terminator: "")
    }

    /// Hide cursor
    public static func hideCursor() {
        print("\(escape)?25l", terminator: "")
    }

    /// Show cursor
    public static func showCursor() {
        print("\(escape)?25h", terminator: "")
    }

    // MARK: - Color Control

    /// Set foreground color
    public static func setColor(_ color: ANSIColor) {
        print("\(escape)\(color.rawValue)m", terminator: "")
    }

    /// Reset all text attributes
    public static func resetColor() {
        print("\(escape)0m", terminator: "")
    }

    /// Apply multiple text attributes
    public static func setAttributes(_ attributes: [ANSIColor]) {
        let codes = attributes.map { $0.rawValue }.joined(separator: ";")
        print("\(escape)\(codes)m", terminator: "")
    }

    // MARK: - Colored Output

    /// Print colored text
    public static func printColored(_ text: String, color: ANSIColor) {
        print("\(escape)\(color.rawValue)m\(text)\(escape)0m", terminator: "")
    }

    /// Print colored text with newline
    public static func printColoredLine(_ text: String, color: ANSIColor) {
        print("\(escape)\(color.rawValue)m\(text)\(escape)0m")
    }

    /// Print bold text
    public static func printBold(_ text: String) {
        print("\(escape)1m\(text)\(escape)0m", terminator: "")
    }

    /// Create colored string without printing
    public static func colored(_ text: String, color: ANSIColor) -> String {
        return "\(escape)\(color.rawValue)m\(text)\(escape)0m"
    }

    /// Create bold string without printing
    public static func bold(_ text: String) -> String {
        return "\(escape)1m\(text)\(escape)0m"
    }

    // MARK: - Terminal Size

    /// Get terminal size (rows, columns)
    public static func getTerminalSize() -> (rows: Int, cols: Int) {
        var size = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 {
            return (Int(size.ws_row), Int(size.ws_col))
        }
        // Default fallback
        return (24, 80)
    }

    // MARK: - Input Handling

    /// Enable raw mode for single character input
    public static func enableRawMode() -> termios {
        var originalTermios = termios()
        tcgetattr(STDIN_FILENO, &originalTermios)

        var raw = originalTermios
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        return originalTermios
    }

    /// Restore terminal to original mode
    public static func restoreTerminalMode(_ originalTermios: termios) {
        var termios = originalTermios
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &termios)
    }

    /// Read a single character from input
    public static func readChar() -> Character? {
        var char: UInt8 = 0
        let result = read(STDIN_FILENO, &char, 1)
        if result == 1 {
            return Character(UnicodeScalar(char))
        }
        return nil
    }

    /// Read a key (handles escape sequences for arrow keys)
    public static func readKey() -> KeyCode {
        guard let char = readChar() else {
            return .unknown
        }

        // Check for escape sequence (arrow keys, etc.)
        if char == "\u{1B}" {
            guard let bracket = readChar(), bracket == "[" else {
                return .escape
            }

            guard let code = readChar() else {
                return .escape
            }

            switch code {
            case "A": return .up
            case "B": return .down
            case "C": return .right
            case "D": return .left
            case "H": return .home
            case "F": return .end
            default: return .unknown
            }
        }

        // Handle special characters
        switch char {
        case "\n", "\r": return .enter
        case "\t": return .tab
        case "\u{7F}", "\u{08}": return .backspace
        case "q", "Q": return .quit
        default:
            if let scalar = char.unicodeScalars.first,
               scalar.value >= 32, scalar.value < 127 {
                return .char(char)
            }
            return .unknown
        }
    }

    // MARK: - Box Drawing

    /// Draw a horizontal line
    public static func drawHorizontalLine(length: Int, char: BoxChar = .horizontal) {
        print(String(repeating: char.rawValue, count: length), terminator: "")
    }

    /// Draw a box border at current position
    public static func drawBox(width: Int, height: Int, row: Int, col: Int) {
        // Top border
        moveCursor(row: row, col: col)
        print(BoxChar.topLeft.rawValue, terminator: "")
        drawHorizontalLine(length: width - 2)
        print(BoxChar.topRight.rawValue, terminator: "")

        // Side borders
        for rowOffset in 1..<(height - 1) {
            moveCursor(row: row + rowOffset, col: col)
            print(BoxChar.vertical.rawValue, terminator: "")
            moveCursor(row: row + rowOffset, col: col + width - 1)
            print(BoxChar.vertical.rawValue, terminator: "")
        }

        // Bottom border
        moveCursor(row: row + height - 1, col: col)
        print(BoxChar.bottomLeft.rawValue, terminator: "")
        drawHorizontalLine(length: width - 2)
        print(BoxChar.bottomRight.rawValue, terminator: "")
    }

    // MARK: - Progress Bar

    /// Draw a progress bar
    public static func drawProgressBar(
        percent: Double,
        width: Int,
        fillChar: BoxChar = .progressFull,
        emptyChar: BoxChar = .progressEmpty
    ) -> String {
        let clampedPercent = max(0, min(100, percent))
        let filledWidth = Int(Double(width) * clampedPercent / 100.0)
        let emptyWidth = width - filledWidth

        var bar = String(repeating: fillChar.rawValue, count: filledWidth)
        bar += String(repeating: emptyChar.rawValue, count: emptyWidth)
        return bar
    }

    /// Draw a colored progress bar based on percentage
    public static func drawColoredProgressBar(percent: Double, width: Int) -> String {
        let bar = drawProgressBar(percent: percent, width: width)
        let color: ANSIColor

        switch percent {
        case 0..<50:
            color = .green
        case 50..<75:
            color = .yellow
        case 75..<90:
            color = .brightYellow
        default:
            color = .red
        }

        return colored(bar, color: color)
    }

    // MARK: - Text Formatting

    /// Center text within a given width
    public static func centerText(_ text: String, width: Int) -> String {
        let textLength = text.count
        guard textLength < width else { return String(text.prefix(width)) }

        let padding = (width - textLength) / 2
        let leftPad = String(repeating: " ", count: padding)
        let rightPad = String(repeating: " ", count: width - textLength - padding)
        return leftPad + text + rightPad
    }

    /// Pad text to the right
    public static func padRight(_ text: String, width: Int) -> String {
        let textLength = text.count
        guard textLength < width else { return String(text.prefix(width)) }
        return text + String(repeating: " ", count: width - textLength)
    }

    /// Pad text to the left
    public static func padLeft(_ text: String, width: Int) -> String {
        let textLength = text.count
        guard textLength < width else { return String(text.prefix(width)) }
        return String(repeating: " ", count: width - textLength) + text
    }

    /// Truncate text with ellipsis if too long
    public static func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength - 3)) + "..."
    }

    // MARK: - Flush Output

    /// Flush stdout to ensure all output is displayed
    public static func flush() {
        fflush(stdout)
    }
}

// MARK: - Key Codes

/// Keyboard input codes
public enum KeyCode: Equatable {
    case char(Character)
    case enter
    case tab
    case backspace
    case escape
    case up
    case down
    case left
    case right
    case home
    case end
    case quit
    case unknown

    /// Check if this is a number key (1-9)
    public var numericValue: Int? {
        if case .char(let c) = self,
           let value = c.wholeNumberValue,
           value >= 1, value <= 9 {
            return value
        }
        return nil
    }
}

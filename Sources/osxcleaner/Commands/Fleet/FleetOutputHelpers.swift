// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import OSXCleanerKit

/// Helper utilities for Fleet command output formatting
enum FleetOutputHelpers {
    /// Print agent table
    static func printAgentTable(_ agents: [RegisteredAgent], progressView: ProgressView) {
        let formatter = OutputFormatter.shortDateFormatter()

        progressView.display(message: "")
        progressView.display(message: "╔══════════════════════════════════════╤══════════╤══════════════════╤═══════════════╗")
        progressView.display(message: "║               Agent ID               │  Status  │     Hostname     │  Last Seen    ║")
        progressView.display(message: "╠══════════════════════════════════════╪══════════╪══════════════════╪═══════════════╣")

        for agent in agents {
            let id = agent.identity.id.uuidString.prefix(36).padding(toLength: 36, withPad: " ", startingAt: 0)
            let status = statusIcon(agent.connectionState).padding(toLength: 8, withPad: " ", startingAt: 0)
            let hostname = String(agent.identity.hostname.prefix(16)).padding(toLength: 16, withPad: " ", startingAt: 0)
            let lastSeen: String
            if let heartbeat = agent.lastHeartbeat {
                lastSeen = formatter.string(from: heartbeat)
            } else {
                lastSeen = "Never"
            }
            let lastSeenPadded = lastSeen.padding(toLength: 13, withPad: " ", startingAt: 0)

            progressView.display(message: "║ \(id) │ \(status) │ \(hostname) │ \(lastSeenPadded) ║")
        }

        progressView.display(message: "╚══════════════════════════════════════╧══════════╧══════════════════╧═══════════════╝")
        progressView.display(message: "")
        progressView.display(message: "Legend: ● active, ○ pending, ◌ offline, ✗ rejected")
        progressView.display(message: "Showing \(agents.count) agent(s)")
    }

    // MARK: - Private Helpers

    private static func statusIcon(_ state: AgentConnectionState) -> String {
        switch state {
        case .active: return "● active"
        case .pending: return "○ pending"
        case .offline: return "◌ offline"
        case .rejected: return "✗ reject"
        case .disconnected: return "◌ discon"
        }
    }
}

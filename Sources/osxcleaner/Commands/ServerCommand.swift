// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import ArgumentParser
import Foundation
import OSXCleanerKit

struct ServerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "server",
        abstract: "Manage connection to central management server",
        discussion: """
            Connect this agent to a central OSX Cleaner management server for
            fleet-wide policy management and monitoring.

            Examples:
              osxcleaner server status                    # Show connection status
              osxcleaner server connect https://mgmt.example.com
              osxcleaner server disconnect
              osxcleaner server register --name "my-mac"
            """,
        subcommands: [
            Status.self,
            Connect.self,
            Disconnect.self,
            Register.self,
            Heartbeat.self
        ],
        defaultSubcommand: Status.self
    )
}

// MARK: - Status Subcommand

extension ServerCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show current server connection status"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()
            let config = try configService.load()

            let status = ServerConnectionStatus(
                serverURL: config.serverURL,
                agentId: config.agentId,
                isRegistered: config.agentId != nil,
                lastHeartbeat: config.lastHeartbeat,
                tokenExpiresAt: config.tokenExpiresAt
            )

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(status)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                printStatus(status, progressView: progressView)
            }
        }

        private func printStatus(_ status: ServerConnectionStatus, progressView: ProgressView) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "                  SERVER CONNECTION STATUS                  ")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
            progressView.display(message: "")

            if let serverURL = status.serverURL {
                progressView.display(message: "  Server URL:      \(serverURL)")
            } else {
                progressView.display(message: "  Server URL:      Not configured")
            }

            if let agentId = status.agentId {
                progressView.display(message: "  Agent ID:        \(agentId)")
                progressView.display(message: "  Registered:      ✓ Yes")
            } else {
                progressView.display(message: "  Agent ID:        -")
                progressView.display(message: "  Registered:      ○ No")
            }

            if let lastHeartbeat = status.lastHeartbeat {
                progressView.display(message: "  Last Heartbeat:  \(formatter.string(from: lastHeartbeat))")
            } else {
                progressView.display(message: "  Last Heartbeat:  Never")
            }

            if let tokenExpires = status.tokenExpiresAt {
                let isExpired = tokenExpires < Date()
                let expiryStr = formatter.string(from: tokenExpires)
                if isExpired {
                    progressView.display(message: "  Token Expires:   \(expiryStr) (EXPIRED)")
                } else {
                    progressView.display(message: "  Token Expires:   \(expiryStr)")
                }
            }

            progressView.display(message: "")
            progressView.display(message: "═══════════════════════════════════════════════════════════")
        }
    }
}

// MARK: - Connect Subcommand

extension ServerCommand {
    struct Connect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "connect",
            abstract: "Configure connection to a management server"
        )

        @Argument(help: "Server URL (e.g., https://mgmt.example.com)")
        var serverURL: String

        @Option(name: .shortAndLong, help: "Request timeout in seconds")
        var timeout: Int = 30

        mutating func validate() throws {
            // Validate server URL is valid and uses HTTPS
            guard let url = URL(string: serverURL) else {
                throw ValidationError.invalidFFIString("Invalid server URL format")
            }

            guard url.scheme == "https" else {
                throw ValidationError.insecureMDMURL
            }

            // Validate timeout is positive
            guard timeout > 0 else {
                throw ValidationError.invalidCheckInterval(timeout)
            }
        }

        mutating func run() async throws {
            let progressView = ProgressView()

            guard let url = URL(string: serverURL) else {
                progressView.display(message: "✗ Invalid server URL: \(serverURL)")
                return
            }

            let configService = ConfigurationService()
            var config = try configService.load()
            config.serverURL = serverURL
            config.serverTimeout = timeout
            try configService.save(config)

            progressView.display(message: "")
            progressView.displaySuccess("Server configured: \(url.absoluteString)")
            progressView.display(message: "")
            progressView.display(message: "Use 'osxcleaner server register' to register this agent with the server.")
        }
    }
}

// MARK: - Disconnect Subcommand

extension ServerCommand {
    struct Disconnect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disconnect",
            abstract: "Disconnect from the management server"
        )

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
        var force: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()
            var config = try configService.load()

            guard config.serverURL != nil else {
                progressView.display(message: "Not connected to any server")
                return
            }

            if !force {
                progressView.display(message: "This will disconnect from the server and clear registration.")
                progressView.display(message: "Use --force to confirm.")
                return
            }

            // If registered, try to unregister first
            if let serverURL = config.serverURL,
               let url = URL(string: serverURL),
               config.authToken != nil {
                let clientConfig = ServerClientConfig(serverURL: url)
                let client = ServerClient(config: clientConfig)

                do {
                    try await client.unregister()
                    progressView.display(message: "Unregistered from server")
                } catch {
                    progressView.displayWarning("Could not unregister: \(error.localizedDescription)")
                }
            }

            // Clear local configuration
            config.serverURL = nil
            config.agentId = nil
            config.authToken = nil
            config.tokenExpiresAt = nil
            config.lastHeartbeat = nil
            try configService.save(config)

            progressView.display(message: "")
            progressView.displaySuccess("Disconnected from server")
        }
    }
}

// MARK: - Register Subcommand

extension ServerCommand {
    struct Register: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "register",
            abstract: "Register this agent with the configured server"
        )

        @Option(name: .shortAndLong, help: "Custom agent name (defaults to hostname)")
        var name: String?

        @Option(name: .long, help: "Agent tags (comma-separated)")
        var tags: String?

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func validate() throws {
            // Validate custom name if provided
            if let agentName = name {
                let trimmed = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw ValidationError.missingRequiredField("name")
                }
            }

            // Validate tags format if provided
            if let tagStr = tags {
                let trimmed = tagStr.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw ValidationError.missingRequiredField("tags")
                }
            }
        }

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()
            var config = try configService.load()

            guard let serverURLString = config.serverURL,
                  let serverURL = URL(string: serverURLString) else {
                progressView.display(message: "✗ No server configured. Use 'osxcleaner server connect <url>' first.")
                return
            }

            // Create agent identity
            let hostname = name ?? ProcessInfo.processInfo.hostName
            let tagList = tags?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } ?? []

            let identity = AgentIdentity(
                id: config.agentId ?? UUID(),
                hostname: hostname,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                appVersion: "0.1.0",
                tags: tagList
            )

            progressView.display(message: "Registering with server: \(serverURL.absoluteString)")
            progressView.display(message: "")

            let clientConfig = ServerClientConfig(
                serverURL: serverURL,
                requestTimeout: TimeInterval(config.serverTimeout ?? 30)
            )
            let client = ServerClient(config: clientConfig)

            do {
                let result = try await client.register(identity: identity)

                if result.success {
                    // Save registration info
                    config.agentId = result.agentId
                    config.authToken = result.authToken
                    config.tokenExpiresAt = result.tokenExpiresAt
                    config.lastHeartbeat = Date()
                    try configService.save(config)

                    if json {
                        let output = RegistrationOutput(
                            success: true,
                            agentId: result.agentId,
                            message: result.message
                        )
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let data = try encoder.encode(output)
                        print(String(data: data, encoding: .utf8) ?? "{}")
                    } else {
                        progressView.displaySuccess("Agent registered successfully!")
                        progressView.display(message: "")
                        progressView.display(message: "  Agent ID:  \(result.agentId?.uuidString ?? "unknown")")
                        if let message = result.message {
                            progressView.display(message: "  Message:   \(message)")
                        }
                    }
                } else {
                    progressView.display(message: "✗ Registration failed: \(result.message ?? "Unknown error")")
                }
            } catch {
                progressView.display(message: "✗ Registration error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Heartbeat Subcommand

extension ServerCommand {
    struct Heartbeat: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "heartbeat",
            abstract: "Send a heartbeat to the server manually"
        )

        @Flag(name: .shortAndLong, help: "Show output in JSON format")
        var json: Bool = false

        mutating func run() async throws {
            let progressView = ProgressView()
            let configService = ConfigurationService()
            var config = try configService.load()

            guard let serverURLString = config.serverURL,
                  let serverURL = URL(string: serverURLString) else {
                progressView.display(message: "✗ No server configured")
                return
            }

            guard config.authToken != nil, config.agentId != nil else {
                progressView.display(message: "✗ Agent not registered. Use 'osxcleaner server register' first.")
                return
            }

            let clientConfig = ServerClientConfig(
                serverURL: serverURL,
                requestTimeout: TimeInterval(config.serverTimeout ?? 30)
            )
            let client = ServerClient(config: clientConfig)

            // Create current status
            let status = AgentStatus.current(
                agentId: config.agentId!,
                connectionState: .active
            )

            do {
                let response = try await client.heartbeat(status: status)

                config.lastHeartbeat = Date()
                try configService.save(config)

                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(response)
                    print(String(data: data, encoding: .utf8) ?? "{}")
                } else {
                    progressView.displaySuccess("Heartbeat sent successfully")
                    if response.pendingCommands > 0 {
                        progressView.display(message: "  Pending commands: \(response.pendingCommands)")
                    }
                    progressView.display(message: "  Next heartbeat in: \(Int(response.nextHeartbeat))s")
                }
            } catch {
                progressView.display(message: "✗ Heartbeat failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Helper Types

private struct ServerConnectionStatus: Codable {
    let serverURL: String?
    let agentId: UUID?
    let isRegistered: Bool
    let lastHeartbeat: Date?
    let tokenExpiresAt: Date?
}

private struct RegistrationOutput: Codable {
    let success: Bool
    let agentId: UUID?
    let message: String?
}

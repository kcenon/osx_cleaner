# ``OSXCleanerKit``

High-performance macOS disk cleanup library with Rust-powered analysis.

## Overview

OSXCleanerKit provides a comprehensive solution for analyzing and cleaning disk space on macOS systems. It combines the performance of Rust core scanning with the convenience of Swift APIs.

### Key Features

- **High-Performance Analysis**: Parallel directory scanning powered by Rust
- **Safety-First Design**: Multi-level safety checks prevent accidental data loss
- **Flexible Configuration**: Supports custom paths, exclusions, and cleanup levels
- **FFI Bridge**: Safe memory management across Swift-Rust boundary
- **Server Mode**: Centralized management for enterprise deployments
- **MDM Integration**: Works with Jamf, Kandji, and Mosyle
- **Audit Logging**: Complete audit trail for compliance

### Platform Requirements

- macOS 12.0 or later
- Swift 5.9 or later
- Rust core library (optional, falls back to Swift implementation)

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:BasicUsage>

### Core Services

- ``AnalyzerService``
- ``CleanerService``
- ``ConfigurationService``

### FFI Bridge

- ``RustBridge``
- <doc:FFISafety>

### Configuration

- ``AppConfiguration``
- ``AnalyzerConfiguration``
- ``CleanerConfiguration``

### Types

- ``AnalysisResult``
- ``AnalysisCategory``
- ``AnalysisItem``
- ``SafetyLevel``
- ``CleanupLevel``

### Server Mode

- ``ManagementServerProtocol``
- ``ServerClient``
- ``AgentRegistry``
- ``PolicyEngine``

### MDM Integration

- ``MDMService``
- ``JamfConnector``
- ``KandjiConnector``
- ``MosyleConnector``

### Audit & Compliance

- ``AuditLogger``
- ``AuditEvent``
- ``ComplianceReporter``

### Validation

- ``PathValidator``
- ``ConfigValidator``
- ``ValidationError``

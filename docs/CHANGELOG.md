# Changelog

All notable changes to OSX Cleaner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Changed
- **Code Quality Improvements** (#111)
  - Add SwiftLint configuration (.swiftlint.yml) for consistent code style
  - Refactor LogsCommand.swift: extract JSON types and reduce function complexity
  - Refactor CleanCommand.swift: extract helper methods from run() function
  - Refactor InteractiveTUI.swift: replace 7-member tuple with TUIDiskInfo struct
  - Configure SwiftLint thresholds for project-appropriate limits
  - Reduce total lint violations from 87 to 29 (all warnings, no errors)

### Added
- **F14-4: Compliance Reporting** (#126)
  - ComplianceReporter actor for generating fleet-wide compliance reports
  - ComplianceScore model with weighted scoring:
    - Policy compliance score (40% weight)
    - Health compliance score (30% weight)
    - Connectivity compliance score (30% weight)
  - ComplianceLevel enum for categorizing compliance states (compliant, partially-compliant, non-compliant, critical)
  - FleetOverviewReport for fleet-wide statistics and metrics
  - AgentComplianceReport for individual agent compliance tracking
  - PolicyExecutionReport for policy distribution tracking
  - AuditLogSummary for audit log aggregation
  - Report export functionality supporting JSON and CSV formats
  - Audit log recording and querying
  - 36 comprehensive unit tests for compliance reporting functionality

- **F14-3: Policy Distribution System** (#125)
  - PolicyDistributor actor for distributing policies to fleet agents
  - DistributionTarget enum for flexible agent targeting:
    - all: Target all registered agents
    - agents: Target specific agents by ID
    - tags: Target agents with specific tags
    - capabilities: Target agents with specific capabilities
    - filter: Custom filtering with required tags, capabilities, exclusions
    - combined: Union of multiple targets
  - DistributionFilter for advanced agent selection criteria
  - DistributionStatus for tracking distribution progress
  - AgentDistributionStatus for per-agent distribution tracking
  - PolicyDistributorDelegate for distribution event notifications
  - Retry mechanism for failed agent distributions
  - Rollback support for completed distributions
  - Distribution history tracking
  - Policy version management
  - 24 comprehensive unit tests for policy distribution

- **F14-2: Agent Registration & Heartbeat** (#124)
  - AgentRegistry actor for centralized agent tracking with token management
  - RegisteredAgent model with authentication and status information
  - RegistrationService with multiple approval policies:
    - auto-approve: Automatically approve all registrations
    - manual-approve: Require manual approval for all registrations
    - whitelist-only: Auto-approve if agent is in whitelist
    - hostname-pattern: Auto-approve based on hostname regex patterns
  - HeartbeatMonitor for detecting offline agents with configurable thresholds
  - RegistryStatistics for fleet-wide monitoring metrics
  - MonitoringSummary for real-time system status
  - 32 comprehensive unit tests for registration and heartbeat functionality

- **F14-1: Server Foundation & Agent Protocol** (#123)
  - AgentIdentity model for unique agent identification with system metadata
  - AgentStatus for tracking agent connection state and health
  - ProtocolVersion for server-agent communication protocol versioning
  - ServerMessage types for structured agent-server communication
  - ManagementServerProtocol for server abstraction
  - ServerClient actor for HTTP-based server communication
  - Registration, heartbeat, policy fetch, and command execution flows
  - ServerCommunicationError for comprehensive error handling
  - 31 unit tests for server foundation components

- **F13: Policy Engine** (#114)
  - Policy model with versioned JSON schema for enterprise cleanup rules
  - PolicyTarget, PolicyAction, PolicySchedule enums for flexible configuration
  - PolicyCondition for conditional execution (age, disk space, time)
  - PolicyValidator with comprehensive validation and error messages
  - PolicyStore for file-based policy management with caching
  - PolicyEngine actor for thread-safe policy execution
  - Compliance checking with detailed reports
  - Sample policies (personal, developer, aggressive, enterprise)
  - CLI `policy` command with subcommands:
    - `policy list`: List installed policies
    - `policy show`: Display policy details
    - `policy add`: Import policy from JSON file
    - `policy remove`: Remove a policy
    - `policy apply`: Execute a policy (with dry-run support)
    - `policy validate`: Validate policy JSON file
    - `policy compliance`: Check compliance status
    - `policy export`: Export policy to file
    - `policy create`: Create from template
  - Integration with AuditLogger for audit trail
  - 37 comprehensive unit tests for policy functionality

- **F12: Enterprise Audit Logging System** (#113)
  - AuditEvent model with categories (cleanup, policy, security, system, user)
  - AuditEventStore with SQLite persistence for long-term retention
  - AuditLogger service for centralized audit logging
  - AuditExporter for JSON, CSV, and JSON Lines export formats
  - CLI `audit` command with subcommands:
    - `audit list`: View recent audit events with filtering
    - `audit show`: Display detailed event information
    - `audit stats`: Show aggregate statistics
    - `audit export`: Export events to file
    - `audit clear`: Clear old events with retention policy
    - `audit info`: Display audit system information
  - Event filtering by category, result, date range, and session
  - Configurable retention policy (default: 365 days)
  - 25 comprehensive unit tests for audit functionality

- **F04-2: Crash Report Analysis** (#81)
  - CrashReportAnalysisService for analyzing crash reports
  - Parse .crash, .ips, .spin, .hang, .diag report files
  - Support for modern macOS 12+ .ips crash format
  - Extract app name and crash date from reports
  - Aggregate crash counts by app
  - Identify apps with repeated crashes (>5 reports)
  - CLI `logs` command with subcommands:
    - `logs analyze`: Display crash report analysis with recommendations
    - `logs clean`: Clean old crash reports with age-based filtering
  - Age-based cleanup (default: 30 days)
  - Recommendations for apps with repeated crashes

- User documentation (INSTALLATION.md, USAGE.md, SAFETY.md, CONTRIBUTING.md)
- Comprehensive user guide with CLI examples
- Safety classification documentation

- **F11: Interactive Terminal User Interface** (#71)
  - TerminalUtils for ANSI escape sequence control
  - InteractiveTUI class with menu-driven navigation
  - InteractiveCommand CLI command (`osxcleaner interactive`)
  - Visual disk usage display with colored progress bar
  - Main menu with 8 options + help
  - Sub-menus for analyze, clean, schedule, snapshot, config, monitor
  - Keyboard navigation (number keys, b for back, q to quit)
  - Real-time status messages
  - Graceful signal handling (Ctrl+C)
  - TTY detection for terminal requirement

- **F04-1: Log Cleanup CLI Integration** (#69)
  - Integrate Rust LogCleaner module into CLI interface
  - Add `includeLogsCaches` field to CleanerConfiguration
  - Add `logs` category to CleanTarget for cleanup targeting
  - Implement `logsCacheTargets()` for user logs and crash reports cleanup
  - Wire up `--target logs` option in clean command
  - Target paths: `~/Library/Logs/`, `~/Library/Logs/DiagnosticReports/`
  - 2 new unit tests for log cleanup configuration

- **F07: Automation Scheduling - Complete Implementation** (#11)
  - SchedulerService for managing launchd-based cleanup schedules
  - ScheduleConfig, ScheduleInfo, ScheduleFrequency types for schedule management
  - CLI `schedule` command with subcommands:
    - `schedule list`: List all configured schedules
    - `schedule add`: Add a new cleanup schedule (daily/weekly/monthly)
    - `schedule remove`: Remove a cleanup schedule
    - `schedule enable`: Enable a schedule (load launchd agent)
    - `schedule disable`: Disable a schedule (unload launchd agent)
  - Support for daily, weekly, and monthly schedules
  - Customizable execution time (hour, minute, weekday, day)
  - launchd plist generation with proper configuration
  - 35 comprehensive unit tests for scheduler functionality
  - NotificationService for macOS system notifications
  - DiskThreshold enum for 85%/90%/95% warning levels
  - Notification categories with action buttons (Run Cleanup, Retry, View Logs)
  - DiskMonitoringService for periodic disk usage monitoring
  - MonitoringConfig for customizable thresholds and auto-cleanup settings
  - launchd integration for background monitoring
  - CLI `monitor` command with subcommands:
    - `monitor status`: Show disk usage and monitoring status
    - `monitor enable`: Enable background monitoring
    - `monitor disable`: Disable background monitoring
    - `monitor check`: Perform immediate disk usage check
  - 20 comprehensive unit tests for disk monitoring

- **F07-3: Automated Cleanup Logging Integration** (#65)
  - AutomatedCleanupLoggingService for structured cleanup logging
  - CleanupSession and CleanupSessionResult for tracking operations
  - Support for multiple trigger types: manual, scheduled, autoCleanup, diskMonitor
  - Log session start/end times with cleanup results
  - JSON-formatted log entries for machine parsing
  - Log file rotation (10MB default, 5 rotated files)
  - Disk monitor trigger logging for auto-cleanup events
  - Integration with CleanerService for automated logging
  - 17 comprehensive unit tests for logging functionality

- **F02-2: XcodeCleaner Enhancement** (#33)
  - Add connected device detection using `xcrun devicectl` (Xcode 15+)
  - Implement AC-08: Preserve currently used iOS Device Support versions
  - Add `get_connected_ios_versions()` and `get_connected_watchos_versions()` methods
  - Add `get_device_support_cleanup_targets_smart()` for intelligent Device Support cleanup
  - Smart cleanup preserves both latest N versions AND versions for connected devices
  - 5 new unit tests for connected device detection functionality

- **F01-3: Expand Protected and Warning Path Lists** (#23)
  - Implement `categorize_path` function for comprehensive path classification
  - Support PathCategory: SystemCritical, UserCritical, DeveloperCache, AppContainer, BrowserCache, AppCache, Logs, Temporary, UserDocuments, Unknown
  - 40+ comprehensive unit tests for all path categories
  - Tests for home directory (~) expansion functionality
  - Export categorize_path in public API

- **F01-5: Running Process Detection FFI Bindings** (#25)
  - `osx_is_app_running`: Check if a specific application is running
  - `osx_is_file_in_use`: Check if a file/directory is in use by any process
  - `osx_check_related_app_running`: Check if app related to cache path is running
  - `osx_get_running_processes`: Get list of all running processes
  - `osx_get_processes_using_path`: Get processes using a specific path
  - `osx_get_app_cache_paths`: Get cache paths for an application
  - Comprehensive FFI unit tests (10 test cases)

- **F01-6: Cloud Sync Status Detection FFI Bindings** (#26)
  - `osx_detect_cloud_service`: Detect cloud service (iCloud, Dropbox, OneDrive, Google Drive)
  - `osx_get_cloud_sync_info`: Get detailed sync status information
  - `osx_is_safe_to_delete_cloud`: Check if safe to delete from cloud perspective
  - `osx_is_icloud_path`: Check if path is in iCloud location
  - `osx_is_dropbox_path`: Check if path is in Dropbox location
  - `osx_is_onedrive_path`: Check if path is in OneDrive location
  - `osx_is_google_drive_path`: Check if path is in Google Drive location
  - Comprehensive FFI unit tests (16 test cases)

- **F05: Time Machine Snapshot Management** (#9)

  - TimeMachineService for managing local APFS snapshots
  - List local snapshots via `tmutil listlocalsnapshots`
  - Delete individual snapshots by date
  - Thin all snapshots to free disk space
  - Query Time Machine status and last backup date
  - CLI `snapshot` command with subcommands (list, status, delete, thin)
  - Dry run support for safe preview of operations
  - Comprehensive unit tests (13 tests)

- **F01-7: Comprehensive Logging for Deletion Operations** (#27)

  - Structured DeletionLogEntry with timestamp, path, safety level, result, bytes freed
  - DeletionLogger with memory and file output support
  - Log rotation support (10MB max file size, 5 rotated files)
  - FFI bindings for Swift integration (osx_init_logger, osx_get_deletion_logs, osx_get_log_stats)
  - LogStats for summary statistics (success/failed/skipped counts, bytes freed)
  - Integration with cleaner module for automatic logging of all deletion attempts

- **F06: Disk Usage Analysis** (#10)

  - DiskSpace query with total/used/available information
  - Home directory analysis with Top N by size
  - Application cache analysis (~/Library/Caches)
  - Developer component analysis (~/Library/Developer)
  - Cleanable space estimation by safety level
  - FFI bindings for Swift integration

- **F04: Log and Crash Report Management** (#8)

  - LogCleaner struct for managing logs and crash reports
  - LogType classification (AppLog, CrashReport, SpinReport, HangReport, etc.)
  - LogSource differentiation (User vs System logs)
  - Age-based filtering with configurable retention period (default: 30 days)
  - Safety-aware cleanup (system logs are read-only)
  - Parallel file deletion using rayon
  - Comprehensive test suite (14 unit tests)

### Testing
- **F02-5: DockerCleaner Test Coverage Expansion** (#36)
  - Default trait implementation tests
  - Size parsing edge cases (empty, whitespace, lowercase, short units)
  - DockerDiskUsage default values and serialization tests
  - DockerImage and DockerContainer struct validation tests
  - DockerError variants verification tests
  - Scan result structure validation tests
  - Dry run cleanup with empty targets tests
  - CleanupTarget method and safety level validation tests
  - Serialization/deserialization tests for all data structures
  - Increase test count from 4 to 20

- **F02-4: PackageManagerCleaner Test Coverage Expansion** (#35)
  - AC-04: Comprehensive package manager detection tests
  - AC-09: Graceful handling of missing tools tests
  - Cache path expansion verification tests
  - Cleanup method validation tests
  - Dry run and empty target handling tests
  - Homebrew and pnpm dynamic path detection tests
  - Increase test count from 3 to 14

- **F02-3: SimulatorCleaner Test Coverage Expansion** (#34)
  - JSON parsing tests for `xcrun simctl list devices` output
  - JSON parsing tests for `xcrun simctl runtime list` output
  - Tempfile integration tests for cache scanning
  - Edge case tests for missing/unavailable data handling
  - Error display tests for SimulatorError
  - Cleanup target construction tests
  - Increase test count from 3 to 18

- **F01-8: Comprehensive unit tests for safety module** (#28)
  - Edge case tests (symlinks, permissions, missing paths)
  - Unicode and special character path handling tests
  - Very long path and path traversal tests
  - Thread safety tests for concurrent validator access
  - Performance tests (10,000+ paths classification)
  - Criterion benchmark suite for safety module

---

## [0.1.0] - 2025-12-25

### Added

#### Core Features
- **F01: Safety-Based Cleanup System** (#29)
  - 4-level safety classification (Safe, Caution, Warning, Danger)
  - Protected path enforcement
  - Running process detection
  - Cloud sync status detection (iCloud, Dropbox, OneDrive)
  - Batch validation for performance

- **F02: Developer Tool Cache Management** (#37)
  - Xcode cleanup (DerivedData, Archives, Device Support)
  - iOS Simulator management (via xcrun simctl)
  - Package manager cache cleanup (npm, yarn, pip, brew, cargo, gradle, etc.)
  - Docker cleanup (images, containers, volumes, build cache)

- **F03: Browser and App Cache Cleanup** (#41)
  - Browser cache cleanup (Safari, Chrome, Firefox, Edge, Brave, Opera, Arc)
  - Cloud service cache detection (iCloud, Dropbox, OneDrive, Google Drive)
  - General application cache cleanup

- **F10: macOS Version Optimization** (#42)
  - macOS version detection (10.15 - 15.x)
  - CPU architecture detection (Intel x64, Apple Silicon)
  - Rosetta 2 status detection
  - Version-specific path resolution

#### Architecture
- Swift + Rust hybrid architecture
- FFI bridge using cbindgen (C-ABI)
- CLI application using Swift ArgumentParser
- Parallel file scanning using Rayon

#### Build System
- Unified Makefile for building Rust and Swift
- Installation scripts (install.sh, uninstall.sh)
- GitHub Actions CI/CD workflows

#### Documentation
- Product Requirements Document (PRD)
- Software Requirements Specification (SRS)
- Software Design Specification (SDS)
- Reference documentation for macOS cleanup

### Security
- BSD 3-Clause license applied (#31)
- Protected paths hardcoded and non-overridable
- Danger-level paths blocked even with --force

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.1.0 | 2025-12-25 | Initial release with core features (F01, F02, F03, F10) |

---

## Roadmap

### v0.2.0 ✅ (Implemented in Unreleased)
- Level 1-2 cleanup execution
- Disk usage analysis visualization (F06)
- Improved error handling

### v0.5.0 ✅ (Implemented in Unreleased)
- Level 3 cleanup support
- Automation scheduling (F07)
- Log and crash report management (F04)
- Time Machine snapshot management (F05)
- Interactive terminal UI (F11)
- Team environment management (F09)

### v1.0.0 (Planned)
- Full GUI interface (SwiftUI)

---

## Contributors

Thanks to all contributors who have helped with this project:

- [@kcenon](https://github.com/kcenon) - Project maintainer

---

## Links

- [GitHub Repository](https://github.com/kcenon/osx_cleaner)
- [Issue Tracker](https://github.com/kcenon/osx_cleaner/issues)
- [Discussions](https://github.com/kcenon/osx_cleaner/discussions)

---

*This changelog is automatically updated with each release.*

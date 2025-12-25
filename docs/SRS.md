# OSX Cleaner - Software Requirements Specification (SRS)

> **Version**: 0.1.0.0
> **Created**: 2025-12-25
> **Status**: Draft
> **Related PRD**: [PRD.md](PRD.md) v0.1.0.0

---

## Document Control

### Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0.0 | 2025-12-25 | - | Initial SRS based on PRD v0.1.0.0 |

### Requirements ID Convention

| Prefix | Category | Example |
|--------|----------|---------|
| `SRS-FR-Fxx-nnn` | Functional Requirement | SRS-FR-F01-001 |
| `SRS-NFR-xxx-nnn` | Non-Functional Requirement | SRS-NFR-SEC-001 |
| `SRS-IR-xxx-nnn` | Interface Requirement | SRS-IR-CLI-001 |
| `SRS-DR-nnn` | Data Requirement | SRS-DR-001 |
| `SRS-CR-nnn` | Constraint Requirement | SRS-CR-001 |

---

## 1. Introduction

### 1.1 Purpose

This document defines the detailed technical requirements for the OSX Cleaner software. It transforms the business requirements defined in the PRD (Product Requirements Document) into implementable technical specifications.

**Primary Audience**:
- Development Team (Backend, Frontend, QA)
- System Architects
- Test Engineers
- Project Managers

### 1.2 Scope

**System Name**: OSX Cleaner

**System Scope**:
- Support for macOS 10.15 (Catalina) ~ 15.x (Sequoia)
- Provides both CLI (Command Line Interface) and GUI (Graphical User Interface)
- Local system cleanup functionality (no network features)
- launchd-based automation support

**Out of Scope**:
- Windows/Linux support
- Cloud-based remote management (after Phase 4)
- File recovery functionality

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|-----|------|
| **DerivedData** | Repository for intermediate files generated during Xcode build process |
| **Device Support** | Symbol files for iOS device debugging |
| **SIP** | System Integrity Protection - macOS system protection mechanism |
| **APFS** | Apple File System - default file system since macOS High Sierra |
| **launchd** | macOS service/job management daemon |
| **TCC** | Transparency, Consent, and Control - macOS permission management framework |
| **FDA** | Full Disk Access - full disk access permission |
| **Cleanup Level** | Level indicating cleanup intensity (Light, Normal, Deep, System) |
| **Safety Level** | Deletion safety level (Safe, Caution, Warning, Danger) |

### 1.4 References

| Document | Version | Description |
|-----|------|------|
| PRD.md | 0.1.0.0 | Product Requirements Document |
| 01-temporary-files.md | 0.1.0.0 | Temporary file location reference |
| 02-cache-system.md | 0.1.0.0 | Cache system reference |
| 06-safe-cleanup-guide.md | 0.1.0.0 | Safe cleanup guide |

### 1.5 Document Overview

| Section | Content |
|---------|---------|
| Section 2 | Overall system description |
| Section 3 | Functional Requirements |
| Section 4 | Non-Functional Requirements |
| Section 5 | Interface Requirements |
| Section 6 | Data Requirements |
| Section 7 | Constraints |
| Section 8 | Traceability Matrix |

---

## 2. Overall Description

### 2.1 System Perspective

```
┌─────────────────────────────────────────────────────────────────┐
│                         OSX Cleaner                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │   CLI App   │    │   GUI App   │    │  launchd    │          │
│  │ (osxcleaner)│    │  (SwiftUI)  │    │   Agent     │          │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘          │
│         │                  │                  │                  │
│         └────────────┬─────┴─────────────────┘                  │
│                      │                                           │
│              ┌───────▼───────┐                                   │
│              │  Core Engine  │                                   │
│              │  (Rust/Swift) │                                   │
│              └───────┬───────┘                                   │
│                      │                                           │
│    ┌─────────────────┼─────────────────┐                        │
│    │                 │                 │                        │
│ ┌──▼───┐    ┌───────▼───────┐    ┌────▼────┐                   │
│ │Safety│    │    Cleaner    │    │Analyzer │                   │
│ │Module│    │    Module     │    │ Module  │                   │
│ └──────┘    └───────────────┘    └─────────┘                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      macOS System                                │
├─────────────────────────────────────────────────────────────────┤
│  ~/Library/Caches  │  ~/Library/Developer  │  /private/var     │
│  ~/Library/Logs    │  Docker/node_modules  │  Time Machine     │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 System Functions Summary

| Function | PRD Reference | Description |
|----------|---------------|-------------|
| Safety Verification | F01 | Safety verification before deletion |
| Developer Cache Cleanup | F02 | Cleanup of development tool caches like Xcode, npm, Docker |
| Browser/App Cache Cleanup | F03 | Cleanup of browser and general app caches |
| Log Management | F04 | Log and crash report management |
| Time Machine Management | F05 | Local snapshot management |
| Disk Analysis | F06 | Disk usage analysis and visualization |
| Automation | F07 | launchd-based automatic cleanup |
| CI/CD Integration | F08 | Build pipeline integration |
| Team Management | F09 | Team environment management |
| Version Optimization | F10 | macOS version-specific optimization |

### 2.3 User Classes and Characteristics

| User Class | Technical Level | Primary Use | PRD Persona |
|------------|-----------------|-------------|-------------|
| iOS Developer | High | Xcode, Simulator cleanup | Persona 1 |
| Full-Stack Developer | High | Docker, node_modules cleanup | Persona 2 |
| DevOps Engineer | High | CI/CD build machine management | Persona 3 |
| Power User | Medium | Browser, general app cache | Persona 4 |
| System Administrator | High | Multi-machine management | (Enterprise) |

### 2.4 Operating Environment

| Component | Requirement |
|-----------|-------------|
| Operating System | macOS 10.15 Catalina ~ 15.x Sequoia |
| Architecture | Intel x64, Apple Silicon (arm64) |
| Memory | 4GB RAM (minimum), 8GB+ (recommended) |
| Disk Space | 50MB (application), 500MB (working space) |
| Shell | zsh (default), bash (supported) |
| Xcode CLT | Required for iOS developer features |

### 2.5 Design and Implementation Constraints

| ID | Constraint | Rationale |
|----|------------|-----------|
| SRS-CR-001 | Cannot access SIP-protected areas | macOS system security policy |
| SRS-CR-002 | TCC permission required | Full Disk Access requirement |
| SRS-CR-003 | Asynchronous I/O mandatory | Performance for large file processing |
| SRS-CR-004 | Sandbox compatibility | Constraints for App Store distribution |

### 2.6 Assumptions and Dependencies

**Assumptions**:
1. User has administrator privileges
2. System is in normal operating state
3. Sufficient free space exists (minimum 500MB)

**Dependencies**:
| Dependency | Purpose | Required |
|------------|---------|----------|
| xcrun | iOS Simulator management | Optional |
| docker | Docker cleanup | Optional |
| brew | Homebrew cleanup | Optional |
| tmutil | Time Machine management | Yes |
| osascript | Notification display | Yes |

---

## 3. Functional Requirements

### 3.1 F01: Safety-Based Cleanup System

> **PRD Reference**: Section 4.2

#### SRS-FR-F01-001: Safety Level Classification

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 4.2.1 |

**Description**: The system shall perform 4-level safety classification for all cleanup targets.

**Input**: File/directory path

**Processing**:
1. Compare path against protected list (PROTECTED_PATHS)
2. Compare path against warning list (WARNING_PATHS)
3. Analyze file type and modification date
4. Determine safety level

**Output**: Safety Level (SAFE | CAUTION | WARNING | DANGER)

**Safety Level Definitions**:

```
enum SafetyLevel {
    SAFE      = 1,  // ✅ Can be deleted immediately
    CAUTION   = 2,  // ⚠️ Can be deleted, requires rebuild time
    WARNING   = 3,  // ⚠️⚠️ Can be deleted, requires data re-download
    DANGER    = 4   // ❌ Must not be deleted
}
```

**Validation Rules**:
- DANGER level items return error when deletion attempted
- WARNING level items require user confirmation

---

#### SRS-FR-F01-002: Protected Path Enforcement

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-002 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 6.1.1 |

**Description**: The system shall reject deletion requests for protected paths.

**Protected Paths (Hardcoded)**:
```
PROTECTED_PATHS = [
    "/System/",
    "/usr/bin/",
    "/usr/sbin/",
    "/bin/",
    "/sbin/",
    "/private/var/db/",
    "/private/var/folders/",
    "~/Library/Keychains/",
    "~/Library/Application Support/",  # Full deletion prohibited
    "~/Library/Mail/",
    "~/Library/Messages/",
    "~/Library/Preferences/"           # Full deletion prohibited
]
```

**Behavior**:
- Protected path deletion attempt → Error Code: `E_PROTECTED_PATH`
- Log the attempt
- Display warning message to user

---

#### SRS-FR-F01-003: Running Application Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F01, Section 4.2.2 |

**Description**: The system shall warn before deleting caches of running applications.

**Input**: Cache path to be deleted

**Processing**:
1. Extract Bundle ID from cache path (e.g., `com.apple.Safari`)
2. Check running processes with `pgrep` or `lsof`
3. Display warning if running

**Output**:
- Running: true/false
- Process Name: string
- PID: number (if running)

**User Interaction**:
```
⚠️ Safari is currently running.
   Deleting cache may cause unexpected behavior.

   [Quit app and delete] [Force delete] [Cancel]
```

---

#### SRS-FR-F01-004: Cleanup Level Selection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-004 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 4.2.3 |

**Description**: The system shall provide 4 cleanup levels.

**Cleanup Levels**:

| Level | Name | Safety | Targets |
|-------|------|--------|---------|
| 1 | Light | SAFE only | Trash, browser cache, 90+ day downloads |
| 2 | Normal | SAFE + CAUTION | Level 1 + user caches, 30+ day logs |
| 3 | Deep | SAFE + CAUTION + WARNING | Level 2 + developer caches, Docker |
| 4 | System | All (NOT RECOMMENDED) | Level 3 + system cache (root) |

**Level Inheritance**:
- Level N includes all targets from Level 1 ~ Level N-1
- Higher levels extend lower levels

---

#### SRS-FR-F01-005: Pre-Cleanup Confirmation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-005 |
| **Priority** | P1 (High) |
| **Source** | PRD F01, Section 6.2 |

**Description**: User confirmation shall be required for Level 2+ cleanup.

**Confirmation Dialog Content**:
1. Summary of items to be deleted
2. Estimated space to be freed
3. Description of potential impact
4. Last Time Machine backup time (if exists)

**CLI Format**:
```
=== OSX Cleaner: Normal Cleanup ===

The following items will be cleaned:
  • User caches: 15.2GB (245 apps)
  • Old logs: 890MB (30+ days)
  • Crash reports: 120MB

Expected space to free: 16.2GB

⚠️ Note: First launch of some apps may be slower.
⏰ Last Time Machine backup: 2 hours ago

Continue? [y/N]:
```

---

### 3.2 F02: Developer Tools Cache Management

> **PRD Reference**: Section 4.3

#### SRS-FR-F02-001: Xcode DerivedData Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F02, Section 4.3.1 |

**Description**: The system shall clean Xcode DerivedData directory.

**Target Paths**:
```
~/Library/Developer/Xcode/DerivedData/
~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/
```

**Cleanup Options**:

| Option | Description | Command |
|--------|-------------|---------|
| All | Delete all | `rm -rf ~/Library/Developer/Xcode/DerivedData/*` |
| Project | Specific project only | `rm -rf ~/Library/Developer/Xcode/DerivedData/{project}-*` |
| Old | 30+ days unaccessed | `find ... -atime +30 -delete` |

**Size Estimation**:
- Average: 5-50GB
- Calculation: Execute `du -sh`

---

#### SRS-FR-F02-002: iOS Simulator Management

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.2 |

**Description**: The system shall manage iOS Simulator devices and runtimes.

**Operations**:

| Operation | Command | Safety |
|-----------|---------|--------|
| List Devices | `xcrun simctl list devices` | N/A |
| Delete Unavailable | `xcrun simctl delete unavailable` | SAFE |
| Delete Specific | `xcrun simctl delete [UDID]` | CAUTION |
| Erase All | `xcrun simctl erase all` | WARNING |
| List Runtimes | `xcrun simctl runtime list` | N/A |
| Delete Runtime | `xcrun simctl runtime delete [ID]` | WARNING |

**Error Handling**:
- Xcode CLT not installed: `E_XCODE_NOT_FOUND`
- xcrun execution failed: `E_SIMCTL_FAILED`

---

#### SRS-FR-F02-003: iOS Device Support Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.1 |

**Description**: The system shall clean old iOS Device Support files.

**Target Path**:
```
~/Library/Developer/Xcode/iOS DeviceSupport/
~/Library/Developer/Xcode/watchOS DeviceSupport/
```

**Cleanup Strategy**:
1. Check iOS version of currently connected devices (system_profiler)
2. Recommend keeping only last 2 major versions
3. Display size by version to user for selective deletion

**Output Format**:
```
iOS Device Support Analysis:
  ✓ 18.1 (19B81)       - 4.2GB  [Currently in use]
  ✓ 17.5 (21F90)       - 4.1GB  [Recently used]
  ? 16.4 (20E247)      - 3.8GB  [Unused for 90 days]
  ? 15.7 (19H357)      - 3.5GB  [Unused for 180 days]

Select versions to delete (comma-separated numbers):
```

---

#### SRS-FR-F02-004: Package Manager Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-004 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F02, Section 4.3.3 |

**Description**: The system shall clean package manager caches.

**Supported Package Managers**:

| Manager | Detection | Cache Path | Cleanup Method |
|---------|-----------|------------|----------------|
| CocoaPods | `command -v pod` | `~/Library/Caches/CocoaPods/` | `pod cache clean --all` |
| SPM | Always | `~/Library/Caches/org.swift.swiftpm/` | Direct delete |
| Carthage | `command -v carthage` | `~/Library/Caches/org.carthage.CarthageKit/` | Direct delete |
| npm | `command -v npm` | `~/.npm/` | `npm cache clean --force` |
| yarn | `command -v yarn` | `$(yarn cache dir)` | `yarn cache clean` |
| pnpm | `command -v pnpm` | `$(pnpm store path)` | `pnpm store prune` |
| pip | `command -v pip3` | `~/Library/Caches/pip/` | `pip cache purge` |
| Homebrew | `command -v brew` | `$(brew --cache)` | `brew cleanup -s` |

**Fallback**: Direct `rm -rf` execution if command fails

---

#### SRS-FR-F02-005: Docker Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-005 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.4 |

**Description**: The system shall clean Docker resources.

**Prerequisites**:
- Docker Desktop is running
- `docker` command is available

**Cleanup Levels**:

| Level | Command | Description | Safety |
|-------|---------|-------------|--------|
| Basic | `docker system prune -f` | Stopped containers, dangling images | CAUTION |
| Images | `docker image prune -a` | All unused images | WARNING |
| Volumes | `docker volume prune -f` | Unused volumes | WARNING |
| Builder | `docker builder prune -f` | Build cache | CAUTION |
| Full | `docker system prune -a --volumes` | Complete cleanup | WARNING |

**Pre-Cleanup Info**:
```
Docker Usage:
  Images:       12.5GB (15 items)
  Containers:   2.1GB (3 stopped)
  Volumes:      8.3GB (5 items)
  Build Cache:  4.2GB
  ─────────────────────────
  Total:        27.1GB
```

---

#### SRS-FR-F02-006: node_modules Discovery and Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-006 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3 (implied) |

**Description**: The system shall discover and clean distributed node_modules directories.

**Discovery Algorithm**:
```bash
find ~/{Projects,Developer,Sources,repos,code} \
    -name "node_modules" \
    -type d \
    -prune \
    2>/dev/null
```

**Output Format**:
```
node_modules Search Results (from ~/Projects):

 SIZE     LAST ACCESS    PATH
 ──────   ────────────   ─────────────────────────────────
 1.2GB    3 days ago     ~/Projects/webapp/node_modules
 890MB    45 days ago    ~/Projects/old-project/node_modules
 2.1GB    120 days ago   ~/Projects/archived/node_modules
 ──────
 4.2GB    Total 3 items

[Delete All] [Only Old (30+ days)] [Select] [Cancel]
```

---

#### SRS-FR-F02-007: IDE Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-007 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F02, Section 4.3 (implied) |

**Description**: The system shall clean IDE caches.

**Supported IDEs**:

| IDE | Cache Paths |
|-----|-------------|
| VS Code | `~/Library/Application Support/Code/Cache/`<br>`~/Library/Application Support/Code/CachedData/`<br>`~/Library/Application Support/Code/CachedExtensionVSIXs/` |
| JetBrains | `~/Library/Caches/JetBrains/IntelliJIdea*/`<br>`~/Library/Caches/JetBrains/PyCharm*/`<br>`~/Library/Caches/JetBrains/WebStorm*/` |
| Xcode | `~/Library/Developer/Xcode/DerivedData/` (SRS-FR-F02-001) |

---

### 3.3 F03: Browser/App Cache Cleanup

> **PRD Reference**: Section 4.4

#### SRS-FR-F03-001: Browser Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F03, Section 4.4.1 |

**Description**: The system shall clean major browser caches.

**Browser Definitions**:

| Browser | Bundle ID | Cache Paths | Safety |
|---------|-----------|-------------|--------|
| Safari | `com.apple.Safari` | `~/Library/Caches/com.apple.Safari/`<br>`~/Library/Caches/com.apple.Safari/WebKitCache/` | SAFE |
| Chrome | `com.google.Chrome` | `~/Library/Caches/Google/Chrome/`<br>`~/Library/Caches/Google/Chrome/Default/Cache/` | SAFE |
| Firefox | `org.mozilla.firefox` | `~/Library/Caches/Firefox/`<br>`~/Library/Caches/Firefox/Profiles/*/cache2/` | SAFE |
| Edge | `com.microsoft.edgemac` | `~/Library/Caches/Microsoft Edge/`<br>`~/Library/Caches/Microsoft Edge/Default/Cache/` | SAFE |
| Arc | `company.thebrowser.Browser` | `~/Library/Caches/company.thebrowser.Browser/` | SAFE |

**Pre-Cleanup Check**:
- Apply SRS-FR-F01-003 (Running App Detection)
- Warn if browser is running

---

#### SRS-FR-F03-002: Application Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F03, Section 4.4 |

**Description**: The system shall clean general application caches.

**Target Path**: `~/Library/Caches/*`

**Exclusion Rules**:
```
CACHE_EXCLUSIONS = [
    "com.apple.Photos",      # Risk of Photos library corruption
    "com.apple.CloudKit",    # iCloud sync issues
    "com.apple.bird",        # iCloud Drive cache
    "Metadata",              # Spotlight related
    "CloudKit"               # CloudKit metadata
]
```

**Processing**:
1. Enumerate subdirectories in `~/Library/Caches/`
2. Check against exclusion list
3. Calculate size per app
4. Display list to user (optional)
5. Delete after confirmation

---

#### SRS-FR-F03-003: Cloud Service Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F03, Section 4.4.2 |

**Description**: The system shall safely clean cloud service caches.

**Cloud Services**:

| Service | Cache Path | Pre-Check |
|---------|------------|-----------|
| iCloud | `~/Library/Caches/com.apple.bird/` | Check sync status |
| Dropbox | `~/Library/Caches/com.getdropbox.dropbox/` | Check sync status |
| OneDrive | `~/Library/Caches/com.microsoft.OneDrive/` | Check sync status |
| Google Drive | `~/Library/Caches/com.google.GoogleDrive/` | Check streaming files |

**Safety Level**: CAUTION (sync verification required)

---

### 3.4 F04: Log and Crash Report Management

> **PRD Reference**: Section 4.5

#### SRS-FR-F04-001: User Log Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F04-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F04, Section 4.5.1 |

**Description**: The system shall clean user log files.

**Target Paths**:
```
~/Library/Logs/
~/Library/Logs/DiagnosticReports/
```

**Age-Based Cleanup**:
```bash
# Delete log files older than 30 days
find ~/Library/Logs -type f -mtime +30 -delete

# Clean empty directories
find ~/Library/Logs -type d -empty -delete
```

**Cleanup Options**:

| Option | Age Threshold | Target |
|--------|---------------|--------|
| Recent | 7+ days | One week or older |
| Normal | 30+ days | One month or older (default) |
| Deep | All | Everything |

---

#### SRS-FR-F04-002: Crash Report Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F04-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F04, Section 4.5.1 |

**Description**: The system shall clean crash reports.

**Target Paths**:
```
~/Library/Logs/DiagnosticReports/*.crash
~/Library/Logs/DiagnosticReports/*.spin
~/Library/Logs/DiagnosticReports/*.hang
~/Library/Logs/DiagnosticReports/*.diag
```

**Pre-Cleanup Analysis**:
- Aggregate crash count by app
- Identify and warn about repeatedly crashing apps

**Output**:
```
Crash Report Analysis:
  Safari: 3 reports (latest: 2 days ago)
  Xcode: 12 reports (latest: today)  ⚠️ Repeated crashes
  Finder: 1 report (latest: 45 days ago)

Reports older than 30 days: 8 reports (2.3MB)
```

---

### 3.5 F05: Time Machine Snapshot Management

> **PRD Reference**: Section 4.6

#### SRS-FR-F05-001: Snapshot Listing

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F05-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F05, Section 4.6.1 |

**Description**: The system shall list local Time Machine snapshots.

**Command**: `tmutil listlocalsnapshots /`

**Output Parsing**:
```
com.apple.TimeMachine.2025-01-15-120000.local
com.apple.TimeMachine.2025-01-14-180000.local
...
```

**Display Format**:
```
Time Machine Local Snapshots:
  DATE                    AGE         EST. SIZE
  ────────────────────    ─────────   ─────────
  2025-01-15 12:00:00     3 hours ago ~2.1GB
  2025-01-14 18:00:00     21 hours ago ~1.8GB
  2025-01-13 12:00:00     2 days ago   ~3.2GB
  ────────────────────────────────────────────
  Total: 3 snapshots, estimated ~7.1GB
```

---

#### SRS-FR-F05-002: Snapshot Deletion

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F05-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F05, Section 4.6.1 |

**Description**: The system shall delete specific or all snapshots.

**Commands**:
```bash
# Delete specific snapshot
sudo tmutil deletelocalsnapshots 2025-01-15-120000

# Thin snapshots to free space
tmutil thinlocalsnapshots / 9999999999999
```

**Safety Level**: CAUTION (irreversible)

**Pre-Deletion Warning**:
```
⚠️ Warning: Time Machine Snapshot Deletion

   Once deleted, you cannot restore to this point in time.
   External Time Machine backups are not affected.

   [Proceed with deletion] [Cancel]
```

---

### 3.6 F06: Disk Analysis and Visualization

> **PRD Reference**: Section 4.7

#### SRS-FR-F06-001: Disk Usage Analysis

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F06, Section 4.7.2 |

**Description**: The system shall analyze disk usage.

**Analysis Targets**:

| Target | Path | Method |
|--------|------|--------|
| User Home | `~/*` | `du -sh` |
| User Caches | `~/Library/Caches/*` | `du -sh` per app |
| Developer | `~/Library/Developer/*` | `du -sh` per component |
| Docker | Docker API | `docker system df` |
| node_modules | Discovered paths | `du -sh` per project |

**Output Structure**:
```typescript
interface DiskAnalysis {
    totalSize: number;           // bytes
    freeSpace: number;           // bytes
    usedSpace: number;           // bytes
    usagePercent: number;        // 0-100
    categories: Category[];
}

interface Category {
    name: string;
    size: number;
    percentage: number;
    safetyLevel: SafetyLevel;
    cleanable: boolean;
    items: Item[];
}
```

---

#### SRS-FR-F06-002: Cleanup Estimation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F06, Section 4.7.1 |

**Description**: The system shall estimate cleanable space by safety level.

**Estimation Categories**:

| Category | Calculation | Display |
|----------|-------------|---------|
| Safe Total | Sum of SAFE items | ✅ Can clean immediately |
| Caution Total | Sum of CAUTION items | ⚠️ Caution required |
| Warning Total | Sum of WARNING items | ⚠️⚠️ Re-download required |

**Accuracy Note**: Actual cleanup results may differ from estimates (due to file sharing, APFS clones, etc.)

---

#### SRS-FR-F06-003: Progress Visualization (CLI)

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F06, Section 4.7.1 |

**Description**: The system shall display progress visually in CLI.

**Progress Bar Format**:
```
Cleaning... [████████████░░░░░░░░] 60% (15.2GB / 25.3GB)
  Current: ~/Library/Caches/com.spotify.client/
```

**Category Progress**:
```
Usage by Category:
  Xcode & Simulators ████████████████░░░░  80GB (16%)
  User Caches        ██████████░░░░░░░░░░  50GB (10%)
  Docker             ██████░░░░░░░░░░░░░░  30GB (6%)
```

---

### 3.7 F07: Automation Scheduling

> **PRD Reference**: Section 4.8

#### SRS-FR-F07-001: launchd Agent Installation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.2 |

**Description**: The system shall install a launchd agent to schedule automatic cleanup.

**Agent Location**: `~/Library/LaunchAgents/`

**Agent Template**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.osxcleaner.{schedule}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/osxcleaner</string>
        <string>--level</string>
        <string>{level}</string>
        <string>--non-interactive</string>
        <string>--log</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <!-- Schedule-specific keys -->
    </dict>
    <key>StandardOutPath</key>
    <string>~/Library/Logs/osxcleaner/{schedule}.log</string>
    <key>StandardErrorPath</key>
    <string>~/Library/Logs/osxcleaner/{schedule}.error.log</string>
</dict>
</plist>
```

**Management Commands**:
```bash
# Install
osxcleaner schedule --add daily --level light

# Remove
osxcleaner schedule --remove daily

# List
osxcleaner schedule --list
```

---

#### SRS-FR-F07-002: Schedule Options

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.1 |

**Description**: The system shall provide various schedule options.

**Predefined Schedules**:

| Schedule | Timing | Default Level |
|----------|--------|---------------|
| daily | Daily 03:00 | Light |
| weekly | Sunday 04:00 | Normal |
| monthly | 1st of month 05:00 | Deep |

**Custom Schedule**:
```bash
osxcleaner schedule --add custom \
    --weekday 0,3 \
    --hour 3 \
    --minute 30 \
    --level normal
```

---

#### SRS-FR-F07-003: Disk Usage Alert

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.3 |

**Description**: The system shall display alerts when disk usage exceeds threshold.

**Threshold Configuration**:
```json
{
    "alert_threshold": 85,
    "critical_threshold": 95,
    "auto_cleanup_on_critical": false
}
```

**Alert Methods**:
1. macOS Notification Center
2. Terminal bell (CLI)
3. Log file entry

**Notification Content**:
```
⚠️ Disk Space Warning

Disk usage is at 87%.
Free space: 41GB

[Run Cleanup] [Dismiss]
```

---

### 3.8 F08: CI/CD Pipeline Integration

> **PRD Reference**: Section 4.9

#### SRS-FR-F08-001: Non-Interactive Mode

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-001 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08, Section 4.9.2 |

**Description**: The system shall be executable without user input in CI/CD environments.

**CLI Flag**: `--non-interactive` or `-y`

**Behavior**:
- Auto-approve all confirmation prompts
- Output progress to stdout
- Output errors to stderr
- Communicate results via exit code

**Exit Codes**:
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Partial success (some items failed) |
| 2 | Invalid arguments |
| 3 | Permission denied |
| 4 | Disk full |
| 5 | Protected path violation attempt |

---

#### SRS-FR-F08-002: Machine-Readable Output

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-002 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08 |

**Description**: The system shall support JSON output for CI/CD parsing.

**CLI Flag**: `--json` or `--output json`

**Output Schema**:
```json
{
    "version": "0.1.0.0",
    "timestamp": "2025-01-15T12:00:00Z",
    "level": "deep",
    "status": "success",
    "summary": {
        "space_before": 385000000000,
        "space_after": 343000000000,
        "space_freed": 42000000000,
        "items_processed": 1523,
        "items_failed": 2
    },
    "categories": [
        {
            "name": "xcode_derived_data",
            "size_freed": 25000000000,
            "items": 45
        }
    ],
    "errors": [
        {
            "path": "/path/to/file",
            "error": "Permission denied"
        }
    ]
}
```

---

#### SRS-FR-F08-003: Disk Space Check Mode

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08, Section 4.9.2 |

**Description**: The system shall provide a mode to check disk state without cleanup.

**CLI Usage**:
```bash
osxcleaner check --min-free 20G --json
```

**Output**:
```json
{
    "status": "warning",
    "free_space": 15000000000,
    "required_space": 20000000000,
    "usage_percent": 88,
    "recommendation": "cleanup_required"
}
```

**Exit Codes (Check Mode)**:
| Code | Condition |
|------|-----------|
| 0 | Free space >= threshold |
| 1 | Free space < threshold |

---

### 3.9 F09: Team Environment Management

> **PRD Reference**: Section 4.9 (implied)

#### SRS-FR-F09-001: Multi-User Awareness

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F09-001 |
| **Priority** | P3 (Low) |
| **Source** | PRD F09 |

**Description**: The system shall be aware of other user sessions on shared machines.

**Check**:
```bash
who | wc -l  # Number of logged-in users
```

**Warning**:
```
⚠️ Other users are logged in (2 users).
   System cache cleanup is not recommended.
```

---

### 3.10 F10: macOS Version Optimization

> **PRD Reference**: Section 4.10

#### SRS-FR-F10-001: Version Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F10, Section 4.10.1 |

**Description**: The system shall detect current macOS version and apply version-specific optimizations.

**Detection Method**:
```bash
sw_vers -productVersion  # e.g., "15.2"
```

**Version Mapping**:

| Version Range | Codename | Special Handling |
|---------------|----------|------------------|
| 15.x | Sequoia | `mediaanalysisd` cache, AI cache |
| 14.x | Sonoma | Safari profile-specific paths |
| 13.x | Ventura | System Settings path changes |
| 12.x | Monterey | System Data category |
| 11.x | Big Sur | Rosetta cache (Intel apps) |
| 10.15 | Catalina | Volume separation, legacy apps |

---

#### SRS-FR-F10-002: Sequoia-Specific Fixes

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F10, Section 4.10.1 |

**Description**: The system shall handle macOS Sequoia 15.1's `mediaanalysisd` bug.

**Bug**: 64MB cache files created hourly, not auto-deleted

**Affected Path**:
```
~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/
```

**Fix Condition**: Recommend automatic cleanup only on macOS 15.1.x

---

#### SRS-FR-F10-003: Architecture Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F10 |

**Description**: The system shall detect CPU architecture and identify related caches.

**Detection**:
```bash
uname -m  # arm64 or x86_64
```

**Apple Silicon Specific**:
- Rosetta cache: `/Library/Apple/usr/share/rosetta/`
- Universal binary related

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### SRS-NFR-PERF-001: Cleanup Execution Time

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-001 |
| **Priority** | P1 |
| **Source** | PRD Section 7.1 |

**Requirements**:
| Cleanup Level | Max Time | Condition |
|---------------|----------|-----------|
| Light | 2 minutes | Up to 10GB cleanup |
| Normal | 5 minutes | Up to 30GB cleanup |
| Deep | 10 minutes | Up to 100GB cleanup |

**Measurement**: Wall-clock time from start to completion

---

#### SRS-NFR-PERF-002: Memory Usage

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-002 |
| **Priority** | P1 |
| **Source** | PRD Section 7.2 |

**Requirements**:
- Peak memory usage: < 100MB
- Idle memory usage: < 20MB
- No memory leaks over 1-hour operation

---

#### SRS-NFR-PERF-003: Disk I/O Efficiency

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-003 |
| **Priority** | P2 |

**Requirements**:
- Use asynchronous I/O
- Single file deletion is synchronous, bulk deletion is parallel
- Disk throttling: within 50% of max I/O bandwidth

---

### 4.2 Security Requirements

#### SRS-NFR-SEC-001: Privilege Escalation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-001 |
| **Priority** | P0 |
| **Source** | PRD Section 5.3 |

**Requirements**:
- Apply principle of least privilege
- Request sudo only when cleaning system caches
- Explicitly state reason for privilege escalation to user

---

#### SRS-NFR-SEC-002: Audit Logging

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-002 |
| **Priority** | P1 |
| **Source** | PRD Section 5.3.2 |

**Requirements**:
- Log all deletion operations
- Log location: `~/Library/Logs/osxcleaner/`
- Log retention: minimum 30 days

**Log Format**:
```
[2025-01-15T12:00:00Z] [INFO] DELETE ~/Library/Caches/com.spotify.client/ (1.2GB)
[2025-01-15T12:00:01Z] [WARN] SKIP ~/Library/Caches/com.apple.bird/ (running)
[2025-01-15T12:00:02Z] [ERROR] FAIL /protected/path (E_PROTECTED_PATH)
```

---

#### SRS-NFR-SEC-003: Input Validation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-003 |
| **Priority** | P0 |

**Requirements**:
- Prevent path traversal attacks (block `../`)
- Validate symbolic link targets
- Escape special characters

---

### 4.3 Reliability Requirements

#### SRS-NFR-REL-001: Error Recovery

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-REL-001 |
| **Priority** | P1 |

**Requirements**:
- Continue on single file deletion failure
- Save current state and exit on critical errors
- Allow recovery of previous session on restart

---

#### SRS-NFR-REL-002: False Positive Prevention

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-REL-002 |
| **Priority** | P0 |
| **Source** | PRD Section 7.2 |

**Requirements**:
- False Positive Rate < 0.1%
- Do not delete when uncertain (Fail-safe)
- User feedback collection mechanism

---

### 4.4 Usability Requirements

#### SRS-NFR-USE-001: CLI Usability

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-USE-001 |
| **Priority** | P1 |

**Requirements**:
- Provide explanation for all commands via `--help` option
- Clear progress indication
- Color coding support (when terminal supports)
- Internationalization support (Korean, English)

---

#### SRS-NFR-USE-002: Error Messages

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-USE-002 |
| **Priority** | P1 |

**Requirements**:
- Error messages include cause and solution
- Provide error codes
- Display detailed information in `--verbose` mode

**Example**:
```
❌ Error: Cannot access system cache (E_PERMISSION_DENIED)

   Solutions:
   1. Re-run with: sudo osxcleaner --level system
   2. Or grant osxcleaner permission in
      System Settings > Privacy & Security > Full Disk Access
```

---

### 4.5 Compatibility Requirements

#### SRS-NFR-COMP-001: macOS Version Support

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-COMP-001 |
| **Priority** | P0 |
| **Source** | PRD Section 5.1 |

**Requirements**:
| Version | Support Level |
|---------|---------------|
| 15.x Sequoia | Full |
| 14.x Sonoma | Full |
| 13.x Ventura | Full |
| 12.x Monterey | Full |
| 11.x Big Sur | Full |
| 10.15 Catalina | Partial (no ARM) |

---

#### SRS-NFR-COMP-002: Shell Compatibility

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-COMP-002 |
| **Priority** | P1 |

**Requirements**:
- zsh (macOS default): Full support
- bash: Full support
- POSIX sh: Core features only

---

### 4.6 Maintainability Requirements

#### SRS-NFR-MAINT-001: Modularity

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-MAINT-001 |
| **Priority** | P2 |

**Requirements**:
- Independent modules per cleanup target
- Minimize existing code changes when adding new cleanup targets
- Configuration file-based extension

---

#### SRS-NFR-MAINT-002: Configuration

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-MAINT-002 |
| **Priority** | P2 |

**Configuration File**: `~/.config/osxcleaner/config.yaml`

**Schema**:
```yaml
version: 1
cleanup:
  default_level: normal
  confirm_level: 2  # Level 2+ requires confirmation

schedule:
  enabled: true
  daily: light
  weekly: normal

alerts:
  threshold: 85
  critical: 95

exclusions:
  paths:
    - "~/Library/Caches/com.example.app/"
  patterns:
    - "*.important"
```

---

## 5. Interface Requirements

### 5.1 Command Line Interface

#### SRS-IR-CLI-001: Main Command Structure

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-001 |
| **Priority** | P0 |

**Command Format**:
```
osxcleaner [command] [options]
```

**Commands**:
| Command | Description |
|---------|-------------|
| `clean` | Execute cleanup (default) |
| `analyze` | Perform analysis only |
| `check` | Check disk status |
| `schedule` | Manage schedules |
| `config` | Manage configuration |
| `version` | Version information |
| `help` | Help |

---

#### SRS-IR-CLI-002: Clean Command Options

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-002 |
| **Priority** | P0 |

**Options**:
```
osxcleaner clean [options]

Options:
  -l, --level <level>     Cleanup level (light|normal|deep|system)
  -y, --non-interactive   Run without user input
  -n, --dry-run           Preview without actual deletion
  -v, --verbose           Verbose output
  -q, --quiet             Minimal output
  --json                  JSON format output
  --include <category>    Include only specific category
  --exclude <category>    Exclude specific category
  --older-than <days>     Only files older than specified days

Categories:
  browser, developer, logs, docker, homebrew, trash, downloads
```

---

#### SRS-IR-CLI-003: Analyze Command

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-003 |
| **Priority** | P1 |

**Usage**:
```
osxcleaner analyze [options]

Options:
  --top <n>     Show only top n items (default: 10)
  --sort <by>   Sort by (size|name|date)
  --json        JSON output
```

---

#### SRS-IR-CLI-004: Schedule Command

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-004 |
| **Priority** | P1 |

**Usage**:
```
osxcleaner schedule <action> [options]

Actions:
  list          List registered schedules
  add           Add schedule
  remove        Remove schedule
  enable        Enable schedule
  disable       Disable schedule

Options (add):
  --name <name>     Schedule name (daily|weekly|monthly|custom)
  --level <level>   Cleanup level
  --weekday <0-6>   Weekday (0=Sunday)
  --hour <0-23>     Hour
  --minute <0-59>   Minute
```

---

### 5.2 Graphical User Interface (Phase 3)

#### SRS-IR-GUI-001: Main Window Layout

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-GUI-001 |
| **Priority** | P3 |

**Components**:
1. **Header**: Disk usage summary, free space
2. **Category List**: Tree of cleanable categories
3. **Detail Panel**: Detailed information for selected category
4. **Action Bar**: Cleanup execution, settings buttons
5. **Status Bar**: Progress, last cleanup time

---

### 5.3 System Interfaces

#### SRS-IR-SYS-001: File System Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-001 |
| **Priority** | P0 |

**Operations**:
| Operation | API |
|-----------|-----|
| File size | `stat()` / `FileManager.attributesOfItem` |
| Directory traversal | `readdir()` / `FileManager.contentsOfDirectory` |
| File deletion | `unlink()` / `FileManager.removeItem` |
| Symlink resolution | `realpath()` / `FileManager.destinationOfSymbolicLink` |

---

#### SRS-IR-SYS-002: Process Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-002 |
| **Priority** | P1 |

**Used For**: Detecting running applications

**Methods**:
```bash
pgrep -l [process_name]
lsof +D [directory]
```

---

#### SRS-IR-SYS-003: Notification Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-003 |
| **Priority** | P2 |

**macOS Notification Center**:
```bash
osascript -e 'display notification "message" with title "title"'
```

**User Notification Framework** (Swift):
```swift
UNUserNotificationCenter.current().requestAuthorization(...)
```

---

## 6. Data Requirements

### 6.1 Data Entities

#### SRS-DR-001: Cleanup Target

```typescript
interface CleanupTarget {
    id: string;                    // Unique identifier
    path: string;                  // Absolute path
    type: "file" | "directory";
    size: number;                  // bytes
    modifiedAt: Date;
    accessedAt: Date;
    safetyLevel: SafetyLevel;
    category: CleanupCategory;
    cleanable: boolean;
    reason?: string;               // If not cleanable
}
```

---

#### SRS-DR-002: Cleanup Session

```typescript
interface CleanupSession {
    id: string;                    // UUID
    startedAt: Date;
    completedAt?: Date;
    level: CleanupLevel;
    status: "running" | "completed" | "failed" | "cancelled";
    spaceBefore: number;
    spaceAfter?: number;
    itemsProcessed: number;
    itemsFailed: number;
    errors: CleanupError[];
}
```

---

#### SRS-DR-003: Configuration

```typescript
interface Configuration {
    version: number;
    cleanup: {
        defaultLevel: CleanupLevel;
        confirmLevel: number;
        dryRunDefault: boolean;
    };
    schedule: {
        enabled: boolean;
        daily?: CleanupLevel;
        weekly?: CleanupLevel;
        monthly?: CleanupLevel;
    };
    alerts: {
        threshold: number;        // Percentage
        critical: number;
        autoCleanup: boolean;
    };
    exclusions: {
        paths: string[];
        patterns: string[];
    };
}
```

---

### 6.2 Data Storage

#### SRS-DR-004: Local Storage

| Data | Location | Format |
|------|----------|--------|
| Configuration | `~/.config/osxcleaner/config.yaml` | YAML |
| Session Logs | `~/Library/Logs/osxcleaner/` | Plain text |
| Cache | `~/Library/Caches/osxcleaner/` | Binary |
| State | `~/.local/state/osxcleaner/` | JSON |

---

### 6.3 Data Retention

| Data Type | Retention Period |
|-----------|------------------|
| Session Logs | 30 days |
| Error Logs | 90 days |
| Cache | Until next run |
| Configuration | Permanent |

---

## 7. Constraints

### 7.1 Technical Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| SRS-CR-001 | Cannot access SIP-protected areas | Cannot clean `/System/`, `/usr/` |
| SRS-CR-002 | TCC permission system | Full Disk Access required |
| SRS-CR-003 | App Sandbox (MAS) | Limited path access |
| SRS-CR-004 | APFS clones | Displayed size vs actual space may differ |

### 7.2 Business Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| SRS-CR-005 | Open source license | Verify dependency license compatibility |
| SRS-CR-006 | App Store policy | System utility restrictions |

---

## 8. Traceability Matrix

### 8.1 PRD → SRS Mapping

| PRD Feature | SRS Requirements |
|-------------|------------------|
| **F01** Safety System | SRS-FR-F01-001 ~ SRS-FR-F01-005 |
| **F02** Developer Cache | SRS-FR-F02-001 ~ SRS-FR-F02-007 |
| **F03** Browser/App Cache | SRS-FR-F03-001 ~ SRS-FR-F03-003 |
| **F04** Log Management | SRS-FR-F04-001 ~ SRS-FR-F04-002 |
| **F05** Time Machine | SRS-FR-F05-001 ~ SRS-FR-F05-002 |
| **F06** Disk Analysis | SRS-FR-F06-001 ~ SRS-FR-F06-003 |
| **F07** Automation | SRS-FR-F07-001 ~ SRS-FR-F07-003 |
| **F08** CI/CD | SRS-FR-F08-001 ~ SRS-FR-F08-003 |
| **F09** Team Env | SRS-FR-F09-001 |
| **F10** Version Opt | SRS-FR-F10-001 ~ SRS-FR-F10-003 |

### 8.2 Requirements Summary

| Category | Count | Priority Distribution |
|----------|-------|----------------------|
| Functional (FR) | 28 | P0: 8, P1: 14, P2: 5, P3: 1 |
| Non-Functional (NFR) | 14 | P0: 4, P1: 7, P2: 3 |
| Interface (IR) | 10 | P0: 3, P1: 3, P2: 2, P3: 2 |
| Data (DR) | 4 | - |
| Constraint (CR) | 6 | - |
| **Total** | **62** | |

### 8.3 Complete Traceability Matrix

| SRS ID | PRD Section | Priority | Phase |
|--------|-------------|----------|-------|
| SRS-FR-F01-001 | 4.2.1 | P0 | 1 |
| SRS-FR-F01-002 | 6.1.1 | P0 | 1 |
| SRS-FR-F01-003 | 4.2.2 | P1 | 1 |
| SRS-FR-F01-004 | 4.2.3 | P0 | 1 |
| SRS-FR-F01-005 | 6.2 | P1 | 1 |
| SRS-FR-F02-001 | 4.3.1 | P0 | 1 |
| SRS-FR-F02-002 | 4.3.2 | P1 | 1 |
| SRS-FR-F02-003 | 4.3.1 | P1 | 1 |
| SRS-FR-F02-004 | 4.3.3 | P0 | 1 |
| SRS-FR-F02-005 | 4.3.4 | P1 | 1 |
| SRS-FR-F02-006 | 4.3 | P1 | 1 |
| SRS-FR-F02-007 | 4.3 | P2 | 2 |
| SRS-FR-F03-001 | 4.4.1 | P0 | 1 |
| SRS-FR-F03-002 | 4.4 | P1 | 1 |
| SRS-FR-F03-003 | 4.4.2 | P2 | 2 |
| SRS-FR-F04-001 | 4.5.1 | P1 | 1 |
| SRS-FR-F04-002 | 4.5.1 | P1 | 1 |
| SRS-FR-F05-001 | 4.6.1 | P1 | 2 |
| SRS-FR-F05-002 | 4.6.1 | P1 | 2 |
| SRS-FR-F06-001 | 4.7.2 | P1 | 1 |
| SRS-FR-F06-002 | 4.7.1 | P1 | 1 |
| SRS-FR-F06-003 | 4.7.1 | P2 | 2 |
| SRS-FR-F07-001 | 4.8.2 | P1 | 2 |
| SRS-FR-F07-002 | 4.8.1 | P1 | 2 |
| SRS-FR-F07-003 | 4.8.3 | P1 | 2 |
| SRS-FR-F08-001 | 4.9.2 | P2 | 2 |
| SRS-FR-F08-002 | 4.9 | P2 | 2 |
| SRS-FR-F08-003 | 4.9.2 | P2 | 2 |
| SRS-FR-F09-001 | 4.9 | P3 | 3 |
| SRS-FR-F10-001 | 4.10.1 | P1 | 1 |
| SRS-FR-F10-002 | 4.10.1 | P1 | 1 |
| SRS-FR-F10-003 | 4.10 | P2 | 2 |

---

## Appendix A: Error Codes

| Code | Name | Description |
|------|------|-------------|
| E_SUCCESS | Success | Operation successful |
| E_PARTIAL | Partial Success | Some items failed |
| E_INVALID_ARGS | Invalid Arguments | Invalid arguments |
| E_PERMISSION_DENIED | Permission Denied | Insufficient permissions |
| E_DISK_FULL | Disk Full | Insufficient disk space |
| E_PROTECTED_PATH | Protected Path | Protected path access attempt |
| E_APP_RUNNING | App Running | Application running |
| E_NOT_FOUND | Not Found | File/directory not found |
| E_IO_ERROR | I/O Error | Input/output error |
| E_XCODE_NOT_FOUND | Xcode Not Found | Xcode CLT not installed |
| E_SIMCTL_FAILED | Simctl Failed | simctl command failed |
| E_DOCKER_NOT_RUNNING | Docker Not Running | Docker not running |
| E_CONFIG_INVALID | Config Invalid | Configuration file error |

---

## Appendix B: Glossary

For terms used in this document, please refer to Section 1.3 and Appendix A of the PRD.

---

## Document Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Owner | | | |
| Tech Lead | | | |
| QA Lead | | | |

---

*This document is based on PRD v0.1.0.0 and should be updated together when the PRD changes.*

# OSX Cleaner - Software Design Specification (SDS)

> **Version**: 0.1.0.0
> **Created**: 2025-12-25
> **Status**: Draft
> **Related SRS**: [SRS.md](SRS.md) v0.1.0.0
> **Related PRD**: [PRD.md](PRD.md) v0.1.0.0

---

## Document Control

### Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0.0 | 2025-12-25 | - | Initial SDS based on SRS v0.1.0.0 |

### Design ID Convention

| Prefix | Category | Example |
|--------|----------|---------|
| `SDS-ARCH-nnn` | Architecture Design | SDS-ARCH-001 |
| `SDS-MOD-xxx-nnn` | Module Design | SDS-MOD-SAFETY-001 |
| `SDS-DATA-nnn` | Data Design | SDS-DATA-001 |
| `SDS-IF-xxx-nnn` | Interface Design | SDS-IF-CLI-001 |
| `SDS-SEC-nnn` | Security Design | SDS-SEC-001 |
| `SDS-ERR-nnn` | Error Handling Design | SDS-ERR-001 |

### Document Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                    Document Hierarchy                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐                 │
│   │   PRD   │ ───→ │   SRS   │ ───→ │   SDS   │                 │
│   │ (What)  │      │ (What + │      │  (How)  │                 │
│   │         │      │  Why)   │      │         │                 │
│   └─────────┘      └─────────┘      └─────────┘                 │
│        │                │                │                       │
│        │                │                │                       │
│        ▼                ▼                ▼                       │
│   F01-F10          SRS-FR-*          SDS-MOD-*                  │
│   Features         Requirements       Designs                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Introduction

### 1.1 Purpose

This document defines the detailed design specification for the OSX Cleaner software. It transforms the technical requirements defined in the SRS (Software Requirements Specification) into implementable design specifications.

**Primary Audience**:
- Development Team (Implementation)
- QA Team (Test Case Design)
- System Architects (Review)
- Maintenance Team (Reference)

### 1.2 Scope

**Design Coverage**:
- Overall system architecture
- Detailed module designs
- Data structures and flows
- Interface design
- Security and error handling design

**Out of Scope**:
- GUI detailed design (Phase 3 and later)
- Enterprise features (Phase 4)
- Detailed test cases (separate document)

### 1.3 Design Principles

| Principle | Description | Application |
|-----|------|------|
| **Safety First** | System stability is top priority | Safety validation before all delete operations |
| **Modularity** | Independent module structure | Independent modules per cleanup target |
| **Fail-Safe** | Safe state on failure | Abort and rollback on errors |
| **Extensibility** | Extensible structure | Configuration-based addition of cleanup targets |
| **Transparency** | Transparent operations | All operations logged and user-confirmed |

### 1.4 References

| Document | Version | Description |
|-----|------|------|
| SRS.md | 0.1.0.0 | Software Requirements Specification |
| PRD.md | 0.1.0.0 | Product Requirements Document |
| 06-safe-cleanup-guide.md | 0.1.0.0 | Safe cleanup guide |
| 08-automation-scripts.md | 0.1.0.0 | Automation scripts reference |

### 1.5 Technology Stack

#### SDS-TECH-001: Swift + Rust Hybrid Architecture

OSX Cleaner adopts a **Swift + Rust hybrid** technology stack.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Technology Stack Overview                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    Swift Layer                               │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │
│   │  │ Presentation│  │   Service   │  │  Core       │          │   │
│   │  │ (CLI, GUI)  │  │   Layer     │  │ (Config,    │          │   │
│   │  │             │  │             │  │  Logger)    │          │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘          │   │
│   └──────────────────────────┬──────────────────────────────────┘   │
│                              │ FFI (C-ABI)                           │
│   ┌──────────────────────────▼──────────────────────────────────┐   │
│   │                    Rust Layer                                │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │
│   │  │ Core Engine │  │Infrastructure│  │  Safety     │          │   │
│   │  │ (Scanner,   │  │ (FileSystem,│  │  Validator  │          │   │
│   │  │  Cleaner)   │  │  Process)   │  │             │          │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘          │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

#### Language Role Assignment

| Layer | Language | Responsibility | Rationale |
|-------|----------|----------------|-----------|
| **Presentation** | Swift | CLI (ArgumentParser), GUI (SwiftUI) | Native macOS API, SwiftUI integration |
| **Service** | Swift | Business logic orchestration | Type safety, async/await |
| **Core - Config/Logger** | Swift | Configuration management, logging | Foundation framework utilization |
| **Core - Engine** | Rust | File scanning, cleanup execution | Memory safety, maximum performance |
| **Core - Safety** | Rust | Safety level calculation, validation | Accuracy, side-effect-free functional processing |
| **Infrastructure** | Rust | Filesystem abstraction | Parallel processing, memory efficiency |
| **Scripts** | Shell | launchd integration, installation | macOS native, simplicity |

#### Technology Stack Details

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Swift** | Swift | 5.9+ | Primary development language |
| | Swift Package Manager | - | Dependency management |
| | ArgumentParser | 1.3+ | CLI parsing |
| | SwiftUI | - | GUI (Phase 3) |
| **Rust** | Rust | 1.75+ | Performance-critical modules |
| | Cargo | - | Build/dependency management |
| | rayon | 1.8+ | Parallel processing |
| | walkdir | 2.4+ | Directory traversal |
| | serde | 1.0+ | Serialization/deserialization |
| **FFI** | cbindgen | 0.26+ | Rust → C header generation |
| | swift-bridge | - | Swift-Rust bindings (optional) |
| **Build** | Make / Just | - | Unified build script |
| | Xcode | 15+ | Swift build |
| **Test** | XCTest | - | Swift unit tests |
| | cargo test | - | Rust unit tests |

#### Build System

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Build Pipeline                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐         │
│   │   Rust      │      │   cbindgen  │      │   Swift     │         │
│   │   Source    │ ───→ │   (FFI)     │ ───→ │   Source    │         │
│   │             │      │             │      │             │         │
│   └──────┬──────┘      └──────┬──────┘      └──────┬──────┘         │
│          │                    │                    │                 │
│          ▼                    ▼                    ▼                 │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐         │
│   │ libosxcore  │      │ osxcore.h   │      │ osxcleaner  │         │
│   │   .a/.dylib │      │ (C Header)  │      │ (Binary)    │         │
│   └──────┬──────┘      └─────────────┘      └──────┬──────┘         │
│          │                                         │                 │
│          └────────────────┬────────────────────────┘                 │
│                           ▼                                          │
│                    ┌─────────────┐                                   │
│                    │ OSX Cleaner │                                   │
│                    │   .app      │                                   │
│                    └─────────────┘                                   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

#### Project Structure

```
osxcleaner/
├── Makefile                    # Unified build script
├── Package.swift               # Swift Package definition
│
├── Sources/                    # Swift sources
│   ├── osxcleaner/             # CLI application
│   │   ├── main.swift
│   │   ├── Commands/
│   │   └── UI/
│   ├── OSXCleanerKit/          # Swift library
│   │   ├── Services/
│   │   ├── Config/
│   │   └── Logger/
│   └── OSXCleanerGUI/          # SwiftUI app (Phase 3)
│
├── rust-core/                  # Rust sources
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs              # FFI entry point
│   │   ├── scanner/            # File scanner
│   │   ├── cleaner/            # Cleanup engine
│   │   ├── safety/             # Safety validation
│   │   └── fs/                 # Filesystem abstraction
│   └── cbindgen.toml           # C header generation config
│
├── include/                    # Generated C headers
│   └── osxcore.h
│
├── scripts/                    # Shell scripts
│   ├── install.sh
│   ├── uninstall.sh
│   └── launchd/
│
└── Tests/                      # Tests
    ├── OSXCleanerKitTests/     # Swift tests
    └── rust-core/tests/        # Rust tests
```

---

## 2. System Architecture

### 2.1 High-Level Architecture

#### SDS-ARCH-001: Layered Architecture (Swift + Rust Hybrid)

**Traces to**: SRS Section 2.1 (System Perspective), SDS-TECH-001

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Presentation Layer [Swift]                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │   CLI App   │    │   GUI App   │    │  launchd    │              │
│  │ (osxcleaner)│    │  (SwiftUI)  │    │   Agent     │              │
│  │ [Swift P1]  │    │ [Swift P3]  │    │ [Shell P2]  │              │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘              │
│         │                  │                  │                      │
│         └────────────┬─────┴─────────────────┘                      │
│                      │                                               │
├──────────────────────┼───────────────────────────────────────────────┤
│                      ▼        Service Layer [Swift]                  │
│              ┌───────────────┐                                       │
│              │ Command       │                                       │
│              │ Dispatcher    │                                       │
│              └───────┬───────┘                                       │
│                      │                                               │
│    ┌─────────────────┼─────────────────┐                            │
│    │                 │                 │                            │
│ ┌──▼───────┐  ┌──────▼──────┐  ┌───────▼────┐                       │
│ │ Analyzer │  │   Cleaner   │  │  Scheduler │                       │
│ │ Service  │  │   Service   │  │  Service   │                       │
│ └──────────┘  └─────────────┘  └────────────┘                       │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│                    Core Layer [Swift + Rust]                         │
│  ┌────────────────────────────┐  ┌────────────────────────────┐     │
│  │      Swift Modules         │  │      Rust Modules (FFI)     │     │
│  │  ┌──────────┐ ┌──────────┐│  │  ┌──────────┐ ┌──────────┐ │     │
│  │  │  Config  │ │  Logger  ││  │  │  Safety  │ │  Scanner │ │     │
│  │  │  Module  │ │  Module  ││  │  │ Validator│ │  Engine  │ │     │
│  │  └──────────┘ └──────────┘│  │  └──────────┘ └──────────┘ │     │
│  └────────────────────────────┘  │  ┌──────────┐ ┌──────────┐ │     │
│                                   │  │ Cleaner  │ │  Target  │ │     │
│                                   │  │  Engine  │ │  Rules   │ │     │
│                                   │  └──────────┘ └──────────┘ │     │
│                                   └────────────────────────────┘     │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│                   Infrastructure Layer [Rust]                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │FileSystem│  │ Process  │  │ Parallel │  │ System   │             │
│  │ Adapter  │  │ Monitor  │  │  Worker  │  │  Info    │             │
│  │  (Rust)  │  │  (Rust)  │  │ (rayon)  │  │  (Rust)  │             │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘             │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│                       FFI Boundary (C-ABI)                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  libosxcore.a / libosxcore.dylib + osxcore.h                 │     │
│  └─────────────────────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         macOS System                                   │
│  FileManager │ Process │ NSUserNotification │ sysctl/sw_vers          │
└───────────────────────────────────────────────────────────────────────┘
```

**Layer Responsibilities**:

| Layer | Language | Responsibility | Components |
|-------|----------|---------------|------------|
| **Presentation** | Swift/Shell | User interaction | CLI, GUI, launchd Agent |
| **Service** | Swift | Business logic coordination | Analyzer, Cleaner, Scheduler |
| **Core** | Swift + Rust | Core functionality implementation | Config, Logger (Swift) / Safety, Scanner, Cleaner, Target (Rust) |
| **Infrastructure** | Rust | System abstraction, performance optimization | FileSystem, Process, Parallel Worker |
| **FFI** | C-ABI | Swift-Rust connection | libosxcore, osxcore.h |

---

### 2.2 Component Diagram

#### SDS-ARCH-002: Component Structure

**Traces to**: SRS Section 2.1, PRD Section 5.2.2

```
┌─────────────────────────────────────────────────────────────────────┐
│                            osxcleaner                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     bin/osxcleaner                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │  │
│  │  │ ArgParser   │  │ Interactive │  │ Dispatcher  │            │  │
│  │  │             │  │    Menu     │  │             │            │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     lib/core/                                  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │  │
│  │  │  safety.sh  │  │ analyzer.sh │  │  cleaner.sh │            │  │
│  │  │             │  │             │  │             │            │  │
│  │  │ - validate  │  │ - scan      │  │ - execute   │            │  │
│  │  │ - classify  │  │ - estimate  │  │ - verify    │            │  │
│  │  │ - protect   │  │ - report    │  │ - rollback  │            │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     lib/targets/                               │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │  │
│  │  │browser.sh│ │developer │ │ system.sh│ │ logs.sh  │         │  │
│  │  │          │ │   .sh    │ │          │ │          │         │  │
│  │  │- Safari  │ │- Xcode   │ │- /tmp    │ │- ~/Logs  │         │  │
│  │  │- Chrome  │ │- Docker  │ │- /var    │ │- Crash   │         │  │
│  │  │- Firefox │ │- npm     │ │- TM snap │ │- Diag    │         │  │
│  │  │- Edge    │ │- IDE     │ │          │ │          │         │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     lib/utils/                                 │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │  │
│  │  │logger.sh │ │notifica- │ │ config.sh│ │ common.sh│         │  │
│  │  │          │ │ tion.sh  │ │          │ │          │         │  │
│  │  │- log()   │ │- alert() │ │- load()  │ │- format()│         │  │
│  │  │- audit() │ │- notify()│ │- save()  │ │- size()  │         │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 2.3 Data Flow Diagram

#### SDS-ARCH-003: Main Cleanup Flow

**Traces to**: SRS-FR-F01-001 ~ SRS-FR-F01-005

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Cleanup Data Flow                               │
└───────────────────────────────────────────────────────────────────────┘

User Input                    Processing                      Output
───────────                   ──────────                      ──────

┌─────────┐
│ osxcleaner               ┌──────────────────┐
│ clean   │────────────────│ 1. Parse Args    │
│ --level │                │    ArgParser     │
│ normal  │                └────────┬─────────┘
└─────────┘                         │
                                    ▼
                           ┌──────────────────┐
                           │ 2. Load Config   │
                           │    ConfigModule  │
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐
                           │ 3. Detect OS     │◀─── sw_vers
                           │    VersionDetect │
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐
                           │ 4. Scan Targets  │◀─── File System
                           │    Analyzer      │
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐
                           │ 5. Classify      │
                           │    Safety Check  │──▶ DANGER → Block
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐      ┌──────────────┐
                           │ 6. User Confirm  │◀────▶│ Interactive  │
                           │    (Level 2+)    │      │ Prompt       │
                           └────────┬─────────┘      └──────────────┘
                                    │
                                    ▼
                           ┌──────────────────┐
                           │ 7. Execute       │──▶ Audit Log
                           │    Cleaner       │
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐      ┌──────────────┐
                           │ 8. Report        │─────▶│ Summary      │
                           │    Generator     │      │ (stdout/JSON)│
                           └──────────────────┘      └──────────────┘
```

---

### 2.4 Directory Structure

#### SDS-ARCH-004: Project Layout

**Traces to**: PRD Section 5.2.2

```
osxcleaner/
├── bin/
│   └── osxcleaner                    # Main entry point (executable)
│
├── lib/
│   ├── core/
│   │   ├── safety.sh                 # SDS-MOD-SAFETY-*
│   │   ├── analyzer.sh               # SDS-MOD-ANALYZER-*
│   │   ├── cleaner.sh                # SDS-MOD-CLEANER-*
│   │   └── scheduler.sh              # SDS-MOD-SCHEDULER-*
│   │
│   ├── targets/
│   │   ├── browser.sh                # SDS-MOD-TARGET-BROWSER-*
│   │   ├── developer.sh              # SDS-MOD-TARGET-DEV-*
│   │   ├── system.sh                 # SDS-MOD-TARGET-SYS-*
│   │   ├── logs.sh                   # SDS-MOD-TARGET-LOG-*
│   │   └── timemachine.sh            # SDS-MOD-TARGET-TM-*
│   │
│   └── utils/
│       ├── logger.sh                 # SDS-MOD-UTIL-LOG-*
│       ├── notification.sh           # SDS-MOD-UTIL-NOTIFY-*
│       ├── config.sh                 # SDS-MOD-UTIL-CONFIG-*
│       ├── common.sh                 # SDS-MOD-UTIL-COMMON-*
│       └── version.sh                # SDS-MOD-UTIL-VERSION-*
│
├── config/
│   ├── default.yaml                  # Default configuration
│   ├── targets.yaml                  # Cleanup target definitions
│   └── protected.yaml                # Protected paths (readonly)
│
├── launchd/
│   ├── com.osxcleaner.daily.plist    # Daily schedule template
│   ├── com.osxcleaner.weekly.plist   # Weekly schedule template
│   └── com.osxcleaner.monthly.plist  # Monthly schedule template
│
├── tests/
│   ├── unit/                         # Unit tests
│   ├── integration/                  # Integration tests
│   └── fixtures/                     # Test data
│
└── docs/
    ├── PRD.md                        # Product Requirements
    ├── SRS.md                        # Software Requirements
    ├── SDS.md                        # Software Design (this file)
    └── reference/                    # Reference documents
```

---

## 3. Module Designs

### 3.1 Safety Module

#### SDS-MOD-SAFETY-001: Safety Validator

**Traces to**: SRS-FR-F01-001, SRS-FR-F01-002

**Purpose**: Perform safety validation for all cleanup targets

**File**: `lib/core/safety.sh`

```bash
#!/bin/bash
# lib/core/safety.sh
# Safety validation module for OSX Cleaner

# Safety Level Constants
readonly SAFETY_SAFE=1
readonly SAFETY_CAUTION=2
readonly SAFETY_WARNING=3
readonly SAFETY_DANGER=4

# Protected paths (hardcoded, never modifiable)
readonly -a PROTECTED_PATHS=(
    "/System/"
    "/usr/bin/"
    "/usr/sbin/"
    "/bin/"
    "/sbin/"
    "/private/var/db/"
    "/private/var/folders/"
    "$HOME/Library/Keychains/"
    "$HOME/Library/Application Support/"
    "$HOME/Library/Mail/"
    "$HOME/Library/Messages/"
    "$HOME/Library/Preferences/"
)

# Warning paths (require user confirmation)
readonly -a WARNING_PATHS=(
    "$HOME/Library/Containers/"
    "$HOME/Library/Group Containers/"
    "/Library/Caches/"
    "com.apple."
)
```

**Interface**:

```bash
# Function: validate_path
# Description: Validate if a path is safe to delete
# Parameters:
#   $1 - path: Absolute path to validate
# Returns:
#   0 - Safe to delete
#   1 - Requires confirmation
#   2 - Blocked (protected path)
# Output:
#   Prints safety level to stdout

validate_path() {
    local path="$1"
    # Implementation...
}

# Function: classify_safety_level
# Description: Classify the safety level of a cleanup target
# Parameters:
#   $1 - path: Path to classify
#   $2 - type: file|directory
#   $3 - age_days: Age in days (optional)
# Returns:
#   Safety level (1-4)

classify_safety_level() {
    local path="$1"
    local type="$2"
    local age_days="${3:-0}"
    # Implementation...
}

# Function: is_protected_path
# Description: Check if path matches protected path list
# Parameters:
#   $1 - path: Path to check
# Returns:
#   0 - Protected
#   1 - Not protected

is_protected_path() {
    local path="$1"
    # Implementation...
}
```

**Algorithm - Safety Classification**:

```
┌─────────────────────────────────────────────────────────────────┐
│                   Safety Classification Algorithm                │
└─────────────────────────────────────────────────────────────────┘

Input: path, type, age_days

1. Check Protected Paths
   │
   ├── Match PROTECTED_PATHS[] → Return DANGER (4)
   │
   └── No match → Continue

2. Check Warning Paths
   │
   ├── Match WARNING_PATHS[] → Set base_level = WARNING (3)
   │
   └── No match → Set base_level = SAFE (1)

3. Apply Age Rules
   │
   ├── age_days < 7 → Increase level by 1 (recent files)
   │
   ├── age_days >= 30 → Keep current level
   │
   └── age_days >= 90 → Decrease level by 1 (old files safer)

4. Apply Type Rules
   │
   ├── type == "directory" AND has_subdirs → Increase level by 1
   │
   └── type == "file" → Keep current level

5. Clamp Result
   │
   └── Return max(1, min(4, final_level))
```

---

#### SDS-MOD-SAFETY-002: Running App Detector

**Traces to**: SRS-FR-F01-003

**Purpose**: Detect running apps and warn before deleting their caches

**File**: `lib/core/safety.sh` (continued)

```bash
# Function: check_running_app
# Description: Check if an app is currently running
# Parameters:
#   $1 - bundle_id: App bundle identifier (e.g., com.apple.Safari)
# Returns:
#   0 - App is running
#   1 - App is not running
# Output:
#   JSON object with process info

check_running_app() {
    local bundle_id="$1"
    # Implementation using pgrep/lsof
}

# Function: get_bundle_id_from_cache_path
# Description: Extract bundle ID from cache path
# Parameters:
#   $1 - cache_path: Path like ~/Library/Caches/com.apple.Safari/
# Returns:
#   Bundle ID string

get_bundle_id_from_cache_path() {
    local cache_path="$1"
    # Extract from path basename
    basename "$cache_path" | grep -oE '^[a-zA-Z0-9.-]+$'
}
```

**Sequence Diagram - Running App Check**:

```
┌─────────┐     ┌──────────┐     ┌─────────┐     ┌──────────┐
│ Cleaner │     │  Safety  │     │ Process │     │  pgrep   │
└────┬────┘     └────┬─────┘     └────┬────┘     └────┬─────┘
     │               │                │               │
     │ check_running │                │               │
     │──────────────▶│                │               │
     │               │                │               │
     │               │ get_bundle_id  │               │
     │               │───────────────▶│               │
     │               │                │               │
     │               │   bundle_id    │               │
     │               │◀───────────────│               │
     │               │                │               │
     │               │         pgrep -l $app_name     │
     │               │───────────────────────────────▶│
     │               │                │               │
     │               │         process_info / empty   │
     │               │◀───────────────────────────────│
     │               │                │               │
     │   result      │                │               │
     │◀──────────────│                │               │
     │               │                │               │
```

---

#### SDS-MOD-SAFETY-003: Cleanup Level Manager

**Traces to**: SRS-FR-F01-004

**Purpose**: Manage 4-level cleanup and determine targets

```bash
# Cleanup Level Definitions
declare -A CLEANUP_LEVELS=(
    [light]="1"
    [normal]="2"
    [deep]="3"
    [system]="4"
)

# Level to Safety Level Mapping
declare -A LEVEL_MAX_SAFETY=(
    [1]="$SAFETY_SAFE"      # Light: SAFE only
    [2]="$SAFETY_CAUTION"   # Normal: SAFE + CAUTION
    [3]="$SAFETY_WARNING"   # Deep: + WARNING
    [4]="$SAFETY_DANGER"    # System: All (not recommended)
)

# Function: get_targets_for_level
# Description: Get cleanup targets appropriate for the specified level
# Parameters:
#   $1 - level: Cleanup level (light|normal|deep|system)
# Returns:
#   Array of target configurations

get_targets_for_level() {
    local level="$1"
    local numeric_level="${CLEANUP_LEVELS[$level]}"
    # Load targets from config and filter by level
}
```

**Level Target Mapping**:

| Level | Numeric | Max Safety | Included Targets |
|-------|---------|------------|------------------|
| light | 1 | SAFE | trash, browser_cache, old_downloads |
| normal | 2 | CAUTION | light + user_caches, old_logs, crash_reports |
| deep | 3 | WARNING | normal + derived_data, simulator, docker, npm |
| system | 4 | DANGER | deep + system_caches (root required) |

---

### 3.2 Analyzer Module

#### SDS-MOD-ANALYZER-001: Disk Analyzer

**Traces to**: SRS-FR-F06-001, SRS-FR-F06-002

**Purpose**: Analyze disk usage and estimate cleanable space

**File**: `lib/core/analyzer.sh`

```bash
#!/bin/bash
# lib/core/analyzer.sh
# Disk analysis module for OSX Cleaner

# Function: analyze_disk_usage
# Description: Analyze overall disk usage
# Parameters:
#   $1 - mount_point: Mount point to analyze (default: /)
# Returns:
#   JSON object with disk usage info

analyze_disk_usage() {
    local mount_point="${1:-/}"

    # Get disk info using df
    local disk_info
    disk_info=$(df -k "$mount_point" | tail -1)

    local total_kb=$(echo "$disk_info" | awk '{print $2}')
    local used_kb=$(echo "$disk_info" | awk '{print $3}')
    local free_kb=$(echo "$disk_info" | awk '{print $4}')
    local usage_percent=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')

    # Output JSON
    cat <<EOF
{
    "mount_point": "$mount_point",
    "total_bytes": $((total_kb * 1024)),
    "used_bytes": $((used_kb * 1024)),
    "free_bytes": $((free_kb * 1024)),
    "usage_percent": $usage_percent
}
EOF
}

# Function: analyze_category
# Description: Analyze a specific cleanup category
# Parameters:
#   $1 - category: Category name (e.g., xcode, browser, docker)
# Returns:
#   JSON object with category analysis

analyze_category() {
    local category="$1"
    # Implementation per category
}

# Function: estimate_cleanup
# Description: Estimate space that can be freed
# Parameters:
#   $1 - level: Cleanup level
# Returns:
#   JSON object with estimation by safety level

estimate_cleanup() {
    local level="$1"
    # Implementation
}
```

**Data Structure - Analysis Result**:

```typescript
// TypeScript representation for documentation
interface DiskAnalysis {
    timestamp: string;           // ISO 8601 format
    mount_point: string;
    total_bytes: number;
    used_bytes: number;
    free_bytes: number;
    usage_percent: number;
    categories: CategoryAnalysis[];
    estimation: CleanupEstimation;
}

interface CategoryAnalysis {
    name: string;                // e.g., "xcode", "browser", "docker"
    display_name: string;        // e.g., "Xcode & Simulators"
    path: string;                // Primary path
    size_bytes: number;
    item_count: number;
    safety_level: 1 | 2 | 3 | 4;
    cleanable: boolean;
    details?: CategoryDetail[];
}

interface CleanupEstimation {
    level: "light" | "normal" | "deep" | "system";
    safe_bytes: number;          // SAFE level items
    caution_bytes: number;       // CAUTION level items
    warning_bytes: number;       // WARNING level items
    total_bytes: number;
}
```

---

#### SDS-MOD-ANALYZER-002: Target Scanner

**Traces to**: SRS-FR-F02-001 ~ SRS-FR-F02-007, SRS-FR-F03-001 ~ SRS-FR-F03-003

**Purpose**: Scan cleanup targets and collect metadata

```bash
# Function: scan_target
# Description: Scan a cleanup target and collect metadata
# Parameters:
#   $1 - target_config: Target configuration (JSON or path to config)
# Returns:
#   Array of CleanupTarget objects (JSON)

scan_target() {
    local target_config="$1"
    # Parse config, scan path, collect metadata
}

# Function: scan_directory
# Description: Recursively scan directory for cleanup candidates
# Parameters:
#   $1 - path: Directory path
#   $2 - max_depth: Maximum depth (default: 1)
#   $3 - pattern: File pattern (optional)
# Returns:
#   JSON array of file/directory info

scan_directory() {
    local path="$1"
    local max_depth="${2:-1}"
    local pattern="${3:-*}"

    find "$path" -maxdepth "$max_depth" -name "$pattern" -exec stat -f \
        '{"path":"%N","size":%z,"mtime":%m,"type":"%HT"}' {} \; 2>/dev/null
}
```

**Scan Algorithm**:

```
┌─────────────────────────────────────────────────────────────────┐
│                      Target Scan Algorithm                       │
└─────────────────────────────────────────────────────────────────┘

Input: target_config (from targets.yaml)

1. Parse Configuration
   │
   ├── path: Target path(s)
   ├── pattern: File pattern (*.cache, etc.)
   ├── depth: Max scan depth
   ├── age_filter: Optional age filter
   └── exclude: Exclusion patterns

2. Validate Path Existence
   │
   ├── Path exists → Continue
   │
   └── Path not exists → Return empty result

3. Check Permissions
   │
   ├── Readable → Continue
   │
   └── Not readable → Return error with E_PERMISSION_DENIED

4. Execute Scan
   │
   ├── For each matching file/directory:
   │   ├── Get metadata (size, mtime, type)
   │   ├── Apply age filter
   │   ├── Check exclusions
   │   └── Classify safety level
   │
   └── Aggregate results

5. Return Results
   │
   └── JSON array of CleanupTarget objects
```

---

### 3.3 Cleaner Module

#### SDS-MOD-CLEANER-001: Cleanup Executor

**Traces to**: SRS-FR-F01-005, SRS-FR-F02-*, SRS-FR-F03-*, SRS-FR-F04-*

**Purpose**: Execute actual file/directory deletion

**File**: `lib/core/cleaner.sh`

```bash
#!/bin/bash
# lib/core/cleaner.sh
# Cleanup execution module for OSX Cleaner

# Function: execute_cleanup
# Description: Execute cleanup for given targets
# Parameters:
#   $1 - targets: JSON array of CleanupTarget objects
#   $2 - options: Cleanup options (dry_run, force, etc.)
# Returns:
#   JSON object with cleanup result

execute_cleanup() {
    local targets="$1"
    local options="$2"

    local dry_run=$(echo "$options" | jq -r '.dry_run // false')
    local force=$(echo "$options" | jq -r '.force // false')

    local processed=0
    local failed=0
    local total_freed=0
    local errors=()

    # Process each target
    while IFS= read -r target; do
        local path=$(echo "$target" | jq -r '.path')
        local size=$(echo "$target" | jq -r '.size')
        local safety=$(echo "$target" | jq -r '.safety_level')

        # Safety check
        if ! validate_for_deletion "$path" "$safety" "$force"; then
            failed=$((failed + 1))
            errors+=("$(json_error "$path" "Safety check failed")")
            continue
        fi

        # Execute or simulate
        if [[ "$dry_run" == "true" ]]; then
            log_info "DRY-RUN: Would delete $path ($size bytes)"
        else
            if delete_path "$path"; then
                total_freed=$((total_freed + size))
                log_audit "DELETE" "$path" "$size"
            else
                failed=$((failed + 1))
                errors+=("$(json_error "$path" "Delete failed")")
            fi
        fi

        processed=$((processed + 1))
    done < <(echo "$targets" | jq -c '.[]')

    # Return result
    generate_cleanup_result "$processed" "$failed" "$total_freed" "${errors[@]}"
}

# Function: delete_path
# Description: Delete a file or directory
# Parameters:
#   $1 - path: Path to delete
# Returns:
#   0 - Success
#   1 - Failure

delete_path() {
    local path="$1"

    if [[ -d "$path" ]]; then
        rm -rf "$path" 2>/dev/null
    else
        rm -f "$path" 2>/dev/null
    fi
}
```

**Cleanup Execution Flow**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Cleanup Execution Flow                           │
└─────────────────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │    Start     │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Load Targets │
                    └──────┬───────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
            ▼                             ▼
     ┌─────────────┐              ┌─────────────┐
     │ dry_run=T   │              │ dry_run=F   │
     └──────┬──────┘              └──────┬──────┘
            │                             │
            ▼                             ▼
     ┌─────────────┐              ┌─────────────┐
     │  Simulate   │              │  Validate   │
     │   Delete    │              │   Safety    │
     └──────┬──────┘              └──────┬──────┘
            │                             │
            │                    ┌────────┴────────┐
            │                    │                 │
            │                    ▼                 ▼
            │             ┌──────────┐      ┌──────────┐
            │             │  Valid   │      │ Invalid  │
            │             └────┬─────┘      └────┬─────┘
            │                  │                 │
            │                  ▼                 ▼
            │             ┌──────────┐      ┌──────────┐
            │             │ Execute  │      │   Log    │
            │             │  Delete  │      │  Error   │
            │             └────┬─────┘      └────┬─────┘
            │                  │                 │
            └────────┬─────────┴─────────────────┘
                     │
                     ▼
              ┌─────────────┐
              │  Audit Log  │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │   Report    │
              │   Result    │
              └─────────────┘
```

---

#### SDS-MOD-CLEANER-002: Target-Specific Cleaners

**Traces to**: SRS-FR-F02-001 ~ SRS-FR-F02-007

**Purpose**: Implement specialized logic for each cleanup target

**Files**: `lib/targets/*.sh`

##### Browser Cleaner (`lib/targets/browser.sh`)

```bash
# Browser-specific cleanup functions

# Browser definitions
declare -A BROWSERS=(
    [safari]="com.apple.Safari:~/Library/Caches/com.apple.Safari/"
    [chrome]="com.google.Chrome:~/Library/Caches/Google/Chrome/"
    [firefox]="org.mozilla.firefox:~/Library/Caches/Firefox/"
    [edge]="com.microsoft.edgemac:~/Library/Caches/Microsoft Edge/"
    [arc]="company.thebrowser.Browser:~/Library/Caches/company.thebrowser.Browser/"
)

# Function: clean_browser_cache
# Description: Clean cache for a specific browser
# Parameters:
#   $1 - browser: Browser name (safari|chrome|firefox|edge|arc)
# Returns:
#   JSON object with cleanup result

clean_browser_cache() {
    local browser="$1"
    local config="${BROWSERS[$browser]}"

    if [[ -z "$config" ]]; then
        return 1
    fi

    local bundle_id="${config%%:*}"
    local cache_path="${config#*:}"
    cache_path="${cache_path/#\~/$HOME}"

    # Check if browser is running
    if check_running_app "$bundle_id"; then
        log_warn "Browser $browser is running"
        return 2
    fi

    # Execute cleanup
    execute_cleanup_for_path "$cache_path"
}
```

##### Developer Tools Cleaner (`lib/targets/developer.sh`)

```bash
# Developer tools cleanup functions

# Function: clean_xcode_derived_data
# Description: Clean Xcode DerivedData
# Parameters:
#   $1 - options: all|old|project:<name>
# Returns:
#   JSON object with cleanup result

clean_xcode_derived_data() {
    local option="${1:-all}"
    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"

    case "$option" in
        all)
            rm -rf "$derived_data"/*
            ;;
        old)
            find "$derived_data" -maxdepth 1 -type d -atime +30 -exec rm -rf {} \;
            ;;
        project:*)
            local project_name="${option#project:}"
            rm -rf "$derived_data/$project_name-"*
            ;;
    esac
}

# Function: clean_ios_simulator
# Description: Clean iOS Simulator devices
# Parameters:
#   $1 - option: unavailable|all
# Returns:
#   Cleanup result

clean_ios_simulator() {
    local option="${1:-unavailable}"

    # Check xcrun availability
    if ! command -v xcrun &>/dev/null; then
        log_error "Xcode Command Line Tools not installed"
        return 1
    fi

    case "$option" in
        unavailable)
            xcrun simctl delete unavailable
            ;;
        all)
            xcrun simctl erase all
            ;;
    esac
}

# Function: clean_package_manager
# Description: Clean package manager caches
# Parameters:
#   $1 - manager: npm|yarn|pnpm|pip|homebrew|cocoapods|spm|carthage
# Returns:
#   Cleanup result

clean_package_manager() {
    local manager="$1"

    case "$manager" in
        npm)
            if command -v npm &>/dev/null; then
                npm cache clean --force
            fi
            ;;
        yarn)
            if command -v yarn &>/dev/null; then
                yarn cache clean
            fi
            ;;
        homebrew)
            if command -v brew &>/dev/null; then
                brew cleanup -s
            fi
            ;;
        # ... other managers
    esac
}

# Function: clean_docker
# Description: Clean Docker resources
# Parameters:
#   $1 - level: basic|images|volumes|full
# Returns:
#   Cleanup result

clean_docker() {
    local level="${1:-basic}"

    # Check Docker availability
    if ! command -v docker &>/dev/null; then
        log_error "Docker not installed"
        return 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker not running"
        return 2
    fi

    case "$level" in
        basic)
            docker system prune -f
            ;;
        images)
            docker image prune -a -f
            ;;
        volumes)
            docker volume prune -f
            ;;
        full)
            docker system prune -a --volumes -f
            ;;
    esac
}
```

---

### 3.4 Scheduler Module

#### SDS-MOD-SCHEDULER-001: launchd Agent Manager

**Traces to**: SRS-FR-F07-001, SRS-FR-F07-002

**Purpose**: Install, manage, and remove launchd agents

**File**: `lib/core/scheduler.sh`

```bash
#!/bin/bash
# lib/core/scheduler.sh
# Scheduling module for OSX Cleaner

readonly LAUNCHD_DIR="$HOME/Library/LaunchAgents"
readonly PLIST_PREFIX="com.osxcleaner"

# Schedule configurations
declare -A SCHEDULES=(
    [daily]='{"Weekday": "*", "Hour": 3, "Minute": 0}'
    [weekly]='{"Weekday": 0, "Hour": 4, "Minute": 0}'
    [monthly]='{"Day": 1, "Hour": 5, "Minute": 0}'
)

# Function: install_schedule
# Description: Install a cleanup schedule
# Parameters:
#   $1 - schedule_name: daily|weekly|monthly|custom
#   $2 - level: Cleanup level for this schedule
#   $3 - custom_config: Custom schedule config (JSON, optional)
# Returns:
#   0 - Success
#   1 - Failure

install_schedule() {
    local schedule_name="$1"
    local level="$2"
    local custom_config="${3:-}"

    local plist_name="${PLIST_PREFIX}.${schedule_name}.plist"
    local plist_path="$LAUNCHD_DIR/$plist_name"

    # Generate plist content
    local schedule_config
    if [[ -n "$custom_config" ]]; then
        schedule_config="$custom_config"
    else
        schedule_config="${SCHEDULES[$schedule_name]}"
    fi

    generate_plist "$plist_path" "$level" "$schedule_config"

    # Load agent
    launchctl load "$plist_path"
}

# Function: generate_plist
# Description: Generate launchd plist file
# Parameters:
#   $1 - plist_path: Output path
#   $2 - level: Cleanup level
#   $3 - schedule_config: Schedule configuration (JSON)

generate_plist() {
    local plist_path="$1"
    local level="$2"
    local schedule_config="$3"

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_PREFIX}.${schedule_name}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/osxcleaner</string>
        <string>clean</string>
        <string>--level</string>
        <string>${level}</string>
        <string>--non-interactive</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
$(json_to_plist_calendar "$schedule_config")
    </dict>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/osxcleaner/${schedule_name}.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/osxcleaner/${schedule_name}.error.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
}

# Function: list_schedules
# Description: List installed schedules
# Returns:
#   JSON array of schedule info

list_schedules() {
    local schedules=()

    for plist in "$LAUNCHD_DIR"/${PLIST_PREFIX}.*.plist; do
        if [[ -f "$plist" ]]; then
            local name=$(basename "$plist" .plist | sed "s/${PLIST_PREFIX}\.//")
            local loaded=$(launchctl list | grep -c "${PLIST_PREFIX}.${name}" || echo "0")
            schedules+=("{\"name\":\"$name\",\"loaded\":$loaded}")
        fi
    done

    echo "[$(IFS=,; echo "${schedules[*]}")]"
}

# Function: remove_schedule
# Description: Remove an installed schedule
# Parameters:
#   $1 - schedule_name: Schedule to remove
# Returns:
#   0 - Success
#   1 - Not found

remove_schedule() {
    local schedule_name="$1"
    local plist_path="$LAUNCHD_DIR/${PLIST_PREFIX}.${schedule_name}.plist"

    if [[ ! -f "$plist_path" ]]; then
        return 1
    fi

    launchctl unload "$plist_path" 2>/dev/null
    rm -f "$plist_path"
}
```

---

#### SDS-MOD-SCHEDULER-002: Disk Usage Monitor

**Traces to**: SRS-FR-F07-003

**Purpose**: Monitor disk usage and send alerts

```bash
# Function: check_disk_threshold
# Description: Check if disk usage exceeds threshold
# Parameters:
#   $1 - threshold: Usage percentage threshold
#   $2 - critical: Critical threshold (optional)
# Returns:
#   0 - Below threshold
#   1 - Above threshold
#   2 - Above critical

check_disk_threshold() {
    local threshold="$1"
    local critical="${2:-95}"

    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    if [[ "$usage" -ge "$critical" ]]; then
        send_notification "critical" "Disk Space Critical" \
            "Disk usage is at ${usage}%. Immediate cleanup required."
        return 2
    elif [[ "$usage" -ge "$threshold" ]]; then
        send_notification "warning" "Disk Space Warning" \
            "Disk usage is at ${usage}%."
        return 1
    fi

    return 0
}
```

---

### 3.5 Logger Module

#### SDS-MOD-UTIL-LOG-001: Logging System

**Traces to**: SRS-NFR-SEC-002

**Purpose**: Log all operations and provide audit trail

**File**: `lib/utils/logger.sh`

```bash
#!/bin/bash
# lib/utils/logger.sh
# Logging module for OSX Cleaner

readonly LOG_DIR="$HOME/Library/Logs/osxcleaner"
readonly LOG_FILE="$LOG_DIR/osxcleaner.log"
readonly AUDIT_FILE="$LOG_DIR/audit.log"

# Log levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# Current log level (configurable)
LOG_LEVEL="${LOG_LEVEL:-$LOG_INFO}"

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE" "$AUDIT_FILE"
}

# Function: log
# Description: Write log entry
# Parameters:
#   $1 - level: Log level
#   $2 - message: Log message

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local level_name

    case "$level" in
        $LOG_DEBUG) level_name="DEBUG" ;;
        $LOG_INFO)  level_name="INFO"  ;;
        $LOG_WARN)  level_name="WARN"  ;;
        $LOG_ERROR) level_name="ERROR" ;;
    esac

    if [[ "$level" -ge "$LOG_LEVEL" ]]; then
        echo "[$timestamp] [$level_name] $message" >> "$LOG_FILE"
    fi
}

# Convenience functions
log_debug() { log $LOG_DEBUG "$1"; }
log_info()  { log $LOG_INFO "$1"; }
log_warn()  { log $LOG_WARN "$1"; }
log_error() { log $LOG_ERROR "$1"; }

# Function: log_audit
# Description: Write audit log entry
# Parameters:
#   $1 - action: Action performed (DELETE, SKIP, ERROR)
#   $2 - path: Target path
#   $3 - size: Size in bytes (optional)

log_audit() {
    local action="$1"
    local path="$2"
    local size="${3:-0}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local size_human=$(format_bytes "$size")

    echo "[$timestamp] [$action] $path ($size_human)" >> "$AUDIT_FILE"
}
```

**Log Format**:

```
# Regular Log (osxcleaner.log)
[2025-01-15T12:00:00Z] [INFO] Starting cleanup with level: normal
[2025-01-15T12:00:01Z] [INFO] Scanning ~/Library/Caches/...
[2025-01-15T12:00:05Z] [WARN] Safari is running, skipping cache
[2025-01-15T12:00:10Z] [INFO] Cleanup completed: 15.2GB freed

# Audit Log (audit.log)
[2025-01-15T12:00:02Z] [DELETE] ~/Library/Caches/com.spotify.client/ (1.2GB)
[2025-01-15T12:00:03Z] [DELETE] ~/Library/Caches/com.google.Chrome/ (890MB)
[2025-01-15T12:00:05Z] [SKIP] ~/Library/Caches/com.apple.Safari/ (running)
[2025-01-15T12:00:08Z] [ERROR] ~/Library/Caches/locked-file.tmp (Permission denied)
```

---

### 3.6 Configuration Module

#### SDS-MOD-UTIL-CONFIG-001: Configuration Manager

**Traces to**: SRS-NFR-MAINT-002

**Purpose**: Load, save, and validate configuration files

**File**: `lib/utils/config.sh`

```bash
#!/bin/bash
# lib/utils/config.sh
# Configuration module for OSX Cleaner

readonly CONFIG_DIR="$HOME/.config/osxcleaner"
readonly CONFIG_FILE="$CONFIG_DIR/config.yaml"
readonly DEFAULT_CONFIG="/usr/local/share/osxcleaner/config/default.yaml"

# Function: load_config
# Description: Load configuration from file
# Parameters:
#   $1 - config_path: Path to config file (optional)
# Returns:
#   Configuration as JSON

load_config() {
    local config_path="${1:-$CONFIG_FILE}"

    # Use default if user config doesn't exist
    if [[ ! -f "$config_path" ]]; then
        config_path="$DEFAULT_CONFIG"
    fi

    # Convert YAML to JSON for easier processing
    if command -v yq &>/dev/null; then
        yq -o json "$config_path"
    else
        # Fallback: basic YAML parsing
        parse_yaml_basic "$config_path"
    fi
}

# Function: save_config
# Description: Save configuration to file
# Parameters:
#   $1 - config_json: Configuration as JSON

save_config() {
    local config_json="$1"

    mkdir -p "$CONFIG_DIR"

    if command -v yq &>/dev/null; then
        echo "$config_json" | yq -P > "$CONFIG_FILE"
    else
        echo "$config_json" > "$CONFIG_FILE"
    fi
}

# Function: get_config_value
# Description: Get a specific configuration value
# Parameters:
#   $1 - key: Dot-notation key (e.g., "cleanup.default_level")
# Returns:
#   Configuration value

get_config_value() {
    local key="$1"
    local config
    config=$(load_config)

    echo "$config" | jq -r ".$key // empty"
}
```

**Configuration Schema**:

```yaml
# config/default.yaml
version: 1

cleanup:
  default_level: normal
  confirm_level: 2           # Level 2+ requires confirmation
  dry_run_default: false

schedule:
  enabled: false
  daily: light
  weekly: normal
  monthly: deep

alerts:
  enabled: true
  threshold: 85              # Warning at 85%
  critical: 95               # Critical at 95%
  auto_cleanup: false        # Auto cleanup on critical

exclusions:
  paths: []                  # User-defined excluded paths
  patterns: []               # Excluded file patterns

output:
  color: true                # Color output in terminal
  verbose: false             # Verbose output
  json: false                # JSON output mode
```

---

## 4. Data Design

### 4.1 Data Entities

#### SDS-DATA-001: CleanupTarget Entity

**Traces to**: SRS-DR-001

```typescript
// CleanupTarget - Represents a file or directory to be cleaned
interface CleanupTarget {
    // Unique identifier (hash of path)
    id: string;

    // Absolute path to target
    path: string;

    // Target type
    type: "file" | "directory";

    // Size in bytes
    size: number;

    // Last modification time (Unix timestamp)
    mtime: number;

    // Last access time (Unix timestamp)
    atime: number;

    // Safety classification (1-4)
    safety_level: 1 | 2 | 3 | 4;

    // Category for grouping
    category: CleanupCategory;

    // Whether this target can be cleaned
    cleanable: boolean;

    // Reason if not cleanable
    reason?: string;

    // App running status (if applicable)
    app_running?: boolean;

    // Bundle ID (if cache target)
    bundle_id?: string;
}

type CleanupCategory =
    | "trash"
    | "browser_cache"
    | "user_cache"
    | "developer_xcode"
    | "developer_simulator"
    | "developer_packages"
    | "developer_docker"
    | "developer_node_modules"
    | "logs"
    | "crash_reports"
    | "timemachine"
    | "system_cache"
    | "downloads";
```

---

#### SDS-DATA-002: CleanupSession Entity

**Traces to**: SRS-DR-002

```typescript
// CleanupSession - Represents a cleanup execution session
interface CleanupSession {
    // Session UUID
    id: string;

    // Session start time
    started_at: string;  // ISO 8601

    // Session completion time
    completed_at?: string;  // ISO 8601

    // Cleanup level used
    level: "light" | "normal" | "deep" | "system";

    // Session status
    status: "running" | "completed" | "failed" | "cancelled";

    // Disk space before cleanup
    space_before: number;

    // Disk space after cleanup
    space_after?: number;

    // Number of items processed
    items_processed: number;

    // Number of items failed
    items_failed: number;

    // Error details
    errors: CleanupError[];

    // Was dry-run mode
    dry_run: boolean;

    // Categories cleaned
    categories: string[];
}

interface CleanupError {
    // Target path
    path: string;

    // Error code
    error_code: string;

    // Error message
    message: string;

    // Timestamp
    timestamp: string;
}
```

---

#### SDS-DATA-003: Configuration Entity

**Traces to**: SRS-DR-003

```typescript
// Configuration - User and system settings
interface Configuration {
    // Config version for migration
    version: number;

    cleanup: {
        // Default cleanup level
        default_level: "light" | "normal" | "deep" | "system";

        // Level requiring confirmation
        confirm_level: number;

        // Default to dry-run mode
        dry_run_default: boolean;
    };

    schedule: {
        // Enable scheduled cleanups
        enabled: boolean;

        // Level for daily cleanup
        daily?: "light" | "normal" | "deep";

        // Level for weekly cleanup
        weekly?: "light" | "normal" | "deep";

        // Level for monthly cleanup
        monthly?: "light" | "normal" | "deep";
    };

    alerts: {
        // Enable disk alerts
        enabled: boolean;

        // Warning threshold percentage
        threshold: number;

        // Critical threshold percentage
        critical: number;

        // Auto cleanup on critical
        auto_cleanup: boolean;
    };

    exclusions: {
        // Paths to exclude from cleanup
        paths: string[];

        // Patterns to exclude
        patterns: string[];
    };

    output: {
        // Enable color output
        color: boolean;

        // Verbose output
        verbose: boolean;

        // JSON output mode
        json: boolean;
    };
}
```

---

### 4.2 Data Storage

#### SDS-DATA-004: Storage Locations

**Traces to**: SRS-DR-004

| Data Type | Location | Format | Retention |
|-----------|----------|--------|-----------|
| Configuration | `~/.config/osxcleaner/config.yaml` | YAML | Permanent |
| Session Logs | `~/Library/Logs/osxcleaner/` | Plain text | 30 days |
| Audit Logs | `~/Library/Logs/osxcleaner/audit.log` | Plain text | 90 days |
| State | `~/.local/state/osxcleaner/state.json` | JSON | Until next run |
| Cache | `~/Library/Caches/osxcleaner/` | Binary | Until next run |

**State File Structure**:

```json
{
    "version": "0.1.0.0",
    "last_cleanup": {
        "timestamp": "2025-01-15T12:00:00Z",
        "level": "normal",
        "space_freed": 15200000000
    },
    "pending_session": null,
    "statistics": {
        "total_cleanups": 42,
        "total_space_freed": 512000000000,
        "last_30_days": {
            "cleanups": 8,
            "space_freed": 120000000000
        }
    }
}
```

---

## 5. Interface Design

### 5.1 CLI Interface

#### SDS-IF-CLI-001: Main Entry Point

**Traces to**: SRS-IR-CLI-001, SRS-IR-CLI-002

**File**: `bin/osxcleaner`

```bash
#!/bin/bash
# bin/osxcleaner
# OSX Cleaner main entry point

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source modules
source "$LIB_DIR/utils/common.sh"
source "$LIB_DIR/utils/logger.sh"
source "$LIB_DIR/utils/config.sh"
source "$LIB_DIR/core/safety.sh"
source "$LIB_DIR/core/analyzer.sh"
source "$LIB_DIR/core/cleaner.sh"
source "$LIB_DIR/core/scheduler.sh"

# Version
readonly VERSION="0.1.0.0"

# Print usage
usage() {
    cat <<EOF
OSX Cleaner v${VERSION} - macOS System Cleanup Tool

Usage:
    osxcleaner [command] [options]

Commands:
    clean       Execute cleanup (default)
    analyze     Analyze disk usage only
    check       Check disk status
    schedule    Manage cleanup schedules
    config      Manage configuration
    version     Show version information
    help        Show this help message

Clean Options:
    -l, --level <level>     Cleanup level (light|normal|deep|system)
    -y, --non-interactive   Run without user confirmation
    -n, --dry-run           Preview without actual deletion
    -v, --verbose           Verbose output
    -q, --quiet             Minimal output
    --json                  JSON format output
    --include <category>    Include specific categories only
    --exclude <category>    Exclude specific categories
    --older-than <days>     Only files older than N days

Categories:
    browser, developer, logs, docker, homebrew, trash, downloads

Examples:
    osxcleaner                          # Interactive cleanup (normal level)
    osxcleaner clean --level deep       # Deep cleanup
    osxcleaner clean -y -l light        # Non-interactive light cleanup
    osxcleaner analyze                  # Analyze only
    osxcleaner schedule list            # List schedules
    osxcleaner check --min-free 20G     # Check for 20GB free space

EOF
}

# Parse arguments
parse_args() {
    local command="${1:-clean}"
    shift || true

    # ... argument parsing logic
}

# Main dispatcher
main() {
    init_logging

    local command="${1:-help}"
    shift || true

    case "$command" in
        clean)
            cmd_clean "$@"
            ;;
        analyze)
            cmd_analyze "$@"
            ;;
        check)
            cmd_check "$@"
            ;;
        schedule)
            cmd_schedule "$@"
            ;;
        config)
            cmd_config "$@"
            ;;
        version)
            echo "OSX Cleaner v${VERSION}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
```

---

#### SDS-IF-CLI-002: Command Implementations

**Clean Command**:

```bash
# Function: cmd_clean
# Description: Execute cleanup command
# Parameters:
#   Command line arguments

cmd_clean() {
    local level="normal"
    local interactive=true
    local dry_run=false
    local verbose=false
    local quiet=false
    local json_output=false
    local include=()
    local exclude=()
    local older_than=0

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--level)
                level="$2"
                shift 2
                ;;
            -y|--non-interactive)
                interactive=false
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            --include)
                include+=("$2")
                shift 2
                ;;
            --exclude)
                exclude+=("$2")
                shift 2
                ;;
            --older-than)
                older_than="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 2
                ;;
        esac
    done

    # Validate level
    if [[ ! "$level" =~ ^(light|normal|deep|system)$ ]]; then
        echo "Invalid level: $level" >&2
        exit 2
    fi

    # Execute cleanup
    log_info "Starting cleanup with level: $level"

    # 1. Detect OS version
    local os_version
    os_version=$(detect_os_version)

    # 2. Scan targets
    local targets
    targets=$(scan_targets_for_level "$level" "$older_than" "${include[@]}" "${exclude[@]}")

    # 3. Estimate cleanup
    local estimation
    estimation=$(estimate_cleanup_size "$targets")

    # 4. Confirm if interactive and level >= 2
    if $interactive && [[ "${CLEANUP_LEVELS[$level]}" -ge 2 ]]; then
        if ! confirm_cleanup "$estimation" "$level"; then
            echo "Cleanup cancelled."
            exit 0
        fi
    fi

    # 5. Execute cleanup
    local result
    result=$(execute_cleanup "$targets" "{\"dry_run\":$dry_run}")

    # 6. Output result
    if $json_output; then
        echo "$result"
    else
        format_cleanup_result "$result" $verbose $quiet
    fi
}
```

---

#### SDS-IF-CLI-003: Interactive Menu

**Purpose**: Provide interactive menu UI

```bash
# Function: show_interactive_menu
# Description: Display interactive cleanup menu

show_interactive_menu() {
    clear
    cat <<EOF
╔════════════════════════════════════════════════════════════╗
║           OSX Cleaner - Interactive Mode                    ║
╠════════════════════════════════════════════════════════════╣
EOF

    # Show disk status
    show_disk_status

    cat <<EOF
╠════════════════════════════════════════════════════════════╣
║  Select cleanup option:                                     ║
║                                                              ║
║  [1] Light Cleanup (Safe)                                   ║
║      - Browser cache, Trash, Old downloads                  ║
║                                                              ║
║  [2] Normal Cleanup (Recommended)                           ║
║      - Light + User caches, Old logs                        ║
║                                                              ║
║  [3] Deep Cleanup (Developer)                               ║
║      - Normal + Xcode, Docker, npm                          ║
║                                                              ║
║  [a] Analyze Only                                           ║
║  [s] Schedule Settings                                      ║
║  [c] Configuration                                          ║
║  [q] Exit                                                    ║
║                                                              ║
╚════════════════════════════════════════════════════════════╝
EOF

    read -p "Select option: " choice

    case "$choice" in
        1) cmd_clean --level light ;;
        2) cmd_clean --level normal ;;
        3) cmd_clean --level deep ;;
        a) cmd_analyze ;;
        s) show_schedule_menu ;;
        c) show_config_menu ;;
        q) exit 0 ;;
        *) show_interactive_menu ;;
    esac
}
```

---

### 5.2 Output Formats

#### SDS-IF-CLI-004: Console Output Format

**Standard Output**:

```
╔════════════════════════════════════════════════════════════╗
║           OSX Cleaner - Normal Cleanup                      ║
╠════════════════════════════════════════════════════════════╣

📊 Current Status
   Disk: 385GB / 512GB (75% used)
   Free Space: 127GB

🔍 Analysis Complete
   Cleanup Targets: 42 items (16.2GB)

   By Category:
   • Browser Cache      2.1GB   ✅
   • User Cache        12.3GB   ⚠️
   • Log Files          1.8GB   ✅

⚠️ Notice
   - Some apps may start slower on first launch
   - Time Machine last backup: 2 hours ago

Continue? [y/N]: y

🧹 Cleaning... [████████████████░░░░] 80%
   Current: ~/Library/Caches/com.spotify.client/

✅ Cleanup Complete
   Space Freed: 15.8GB
   Items Processed: 42
   Failed: 0
   Duration: 1m 23s
```

---

#### SDS-IF-CLI-005: JSON Output Format

**Traces to**: SRS-FR-F08-002

```json
{
    "version": "0.1.0.0",
    "timestamp": "2025-01-15T12:00:00Z",
    "command": "clean",
    "level": "normal",
    "status": "success",
    "exit_code": 0,
    "disk_before": {
        "total_bytes": 549755813888,
        "used_bytes": 412316860416,
        "free_bytes": 137438953472,
        "usage_percent": 75
    },
    "disk_after": {
        "total_bytes": 549755813888,
        "used_bytes": 395406049280,
        "free_bytes": 154349764608,
        "usage_percent": 72
    },
    "summary": {
        "space_freed": 16910811136,
        "space_freed_human": "15.8GB",
        "items_processed": 42,
        "items_failed": 0,
        "duration_seconds": 83
    },
    "categories": [
        {
            "name": "browser_cache",
            "display_name": "Browser Cache",
            "size_freed": 2254857830,
            "items": 8
        },
        {
            "name": "user_cache",
            "display_name": "User Caches",
            "size_freed": 13207891558,
            "items": 31
        },
        {
            "name": "logs",
            "display_name": "Log Files",
            "size_freed": 1448061748,
            "items": 3
        }
    ],
    "errors": []
}
```

---

### 5.3 Notification Interface

#### SDS-IF-NOTIFY-001: macOS Notification

**Traces to**: SRS-IR-SYS-003

```bash
# Function: send_notification
# Description: Send macOS notification
# Parameters:
#   $1 - type: info|warning|critical
#   $2 - title: Notification title
#   $3 - message: Notification message
#   $4 - action: Optional action (cleanup|dismiss)

send_notification() {
    local type="$1"
    local title="$2"
    local message="$3"
    local action="${4:-}"

    local sound=""
    case "$type" in
        warning)  sound='sound name "Basso"' ;;
        critical) sound='sound name "Sosumi"' ;;
    esac

    osascript -e "display notification \"$message\" with title \"$title\" $sound"
}

# Alternative: Use terminal-notifier if available
send_notification_advanced() {
    local type="$1"
    local title="$2"
    local message="$3"

    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier \
            -title "$title" \
            -message "$message" \
            -group "osxcleaner" \
            -activate "com.apple.Terminal"
    else
        send_notification "$type" "$title" "$message"
    fi
}
```

---

## 6. Security Design

### 6.1 Security Controls

#### SDS-SEC-001: Path Validation

**Traces to**: SRS-NFR-SEC-003

```bash
# Function: validate_path_security
# Description: Validate path for security issues
# Parameters:
#   $1 - path: Path to validate
# Returns:
#   0 - Safe
#   1 - Security violation

validate_path_security() {
    local path="$1"

    # 1. Check for path traversal
    if [[ "$path" == *".."* ]]; then
        log_error "Path traversal detected: $path"
        return 1
    fi

    # 2. Resolve symlinks and validate real path
    local real_path
    real_path=$(realpath "$path" 2>/dev/null) || return 1

    # 3. Check if real path is in protected list
    if is_protected_path "$real_path"; then
        log_error "Protected path access attempt: $path -> $real_path"
        return 1
    fi

    # 4. Validate path is under allowed directories
    local allowed_prefixes=("$HOME" "/tmp" "/private/tmp")
    local is_allowed=false

    for prefix in "${allowed_prefixes[@]}"; do
        if [[ "$real_path" == "$prefix"* ]]; then
            is_allowed=true
            break
        fi
    done

    if ! $is_allowed; then
        log_error "Path outside allowed directories: $real_path"
        return 1
    fi

    return 0
}
```

---

#### SDS-SEC-002: Privilege Management

**Traces to**: SRS-NFR-SEC-001

```bash
# Function: require_privilege
# Description: Request elevated privileges if needed
# Parameters:
#   $1 - operation: Description of operation requiring privilege
# Returns:
#   0 - Privilege granted
#   1 - Privilege denied

require_privilege() {
    local operation="$1"

    # Check if already root
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Explain why privilege is needed
    cat <<EOF
⚠️ Administrator privileges required

Operation: $operation
Reason: System cache cleanup requires administrator privileges.

EOF

    # Request sudo
    if sudo -v; then
        return 0
    else
        log_error "Privilege escalation denied for: $operation"
        return 1
    fi
}

# Function: drop_privilege
# Description: Drop elevated privileges after operation

drop_privilege() {
    # Invalidate sudo timestamp
    sudo -k
}
```

---

#### SDS-SEC-003: Audit Trail

**Traces to**: SRS-NFR-SEC-002

```bash
# Audit log format
# [TIMESTAMP] [ACTION] [USER] [PATH] [SIZE] [RESULT]

# Function: audit_log
# Description: Write audit log entry
# Parameters:
#   $1 - action: Action performed
#   $2 - path: Target path
#   $3 - size: Size in bytes
#   $4 - result: success|failure

audit_log() {
    local action="$1"
    local path="$2"
    local size="${3:-0}"
    local result="${4:-success}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=$(whoami)

    local entry="[$timestamp] [$action] [$user] $path ($size bytes) [$result]"

    echo "$entry" >> "$AUDIT_FILE"

    # Also log to syslog for system-level auditing
    logger -t osxcleaner "$entry"
}
```

---

## 7. Error Handling Design

### 7.1 Error Codes

#### SDS-ERR-001: Error Code Definitions

**Traces to**: SRS Appendix A

```bash
# Error code definitions
declare -A ERROR_CODES=(
    [E_SUCCESS]="0:Success"
    [E_PARTIAL]="1:Partial success - some items failed"
    [E_INVALID_ARGS]="2:Invalid arguments"
    [E_PERMISSION_DENIED]="3:Permission denied"
    [E_DISK_FULL]="4:Disk full"
    [E_PROTECTED_PATH]="5:Attempted to access protected path"
    [E_APP_RUNNING]="6:Application is running"
    [E_NOT_FOUND]="7:File or directory not found"
    [E_IO_ERROR]="8:I/O error"
    [E_XCODE_NOT_FOUND]="10:Xcode Command Line Tools not installed"
    [E_SIMCTL_FAILED]="11:simctl command failed"
    [E_DOCKER_NOT_RUNNING]="12:Docker is not running"
    [E_CONFIG_INVALID]="13:Configuration file is invalid"
    [E_TIMEOUT]="14:Operation timed out"
    [E_CANCELLED]="15:Operation cancelled by user"
    [E_UNKNOWN]="99:Unknown error"
)

# Function: get_error_code
# Description: Get numeric error code
# Parameters:
#   $1 - error_name: Error name (e.g., E_PERMISSION_DENIED)
# Returns:
#   Numeric error code

get_error_code() {
    local error_name="$1"
    echo "${ERROR_CODES[$error_name]%%:*}"
}

# Function: get_error_message
# Description: Get error message
# Parameters:
#   $1 - error_name: Error name
# Returns:
#   Error message

get_error_message() {
    local error_name="$1"
    echo "${ERROR_CODES[$error_name]#*:}"
}
```

---

#### SDS-ERR-002: Error Handling Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Error Handling Strategy                       │
└─────────────────────────────────────────────────────────────────┘

1. Classification
   │
   ├── Recoverable Errors (continue with next item)
   │   ├── E_NOT_FOUND     - File already deleted
   │   ├── E_APP_RUNNING   - Skip and warn
   │   └── E_IO_ERROR      - Log and skip
   │
   └── Fatal Errors (stop execution)
       ├── E_PERMISSION_DENIED - Request privilege or exit
       ├── E_DISK_FULL         - Cannot continue
       └── E_PROTECTED_PATH    - Security violation

2. Error Response Flow

   ┌─────────────┐     ┌──────────────┐     ┌─────────────┐
   │   Error     │────▶│  Classify    │────▶│ Recoverable │
   │   Occurs    │     │   Error      │     └──────┬──────┘
   └─────────────┘     └──────────────┘            │
                              │                    ▼
                              │              ┌─────────────┐
                              │              │  Log Error  │
                              │              │  Add to     │
                              │              │  Failed List│
                              │              │  Continue   │
                              │              └─────────────┘
                              │
                              ▼
                        ┌───────────┐
                        │   Fatal   │
                        └─────┬─────┘
                              │
                              ▼
                        ┌─────────────┐
                        │  Log Error  │
                        │  Save State │
                        │  Exit       │
                        └─────────────┘

3. User Notification
   │
   ├── Console: Immediate feedback
   ├── Log File: Detailed error info
   ├── JSON Output: Machine-readable errors
   └── Notification: For scheduled cleanups
```

---

#### SDS-ERR-003: Error Recovery

```bash
# Function: handle_error
# Description: Handle error based on type
# Parameters:
#   $1 - error_code: Error code
#   $2 - context: Error context (path, operation, etc.)
# Returns:
#   0 - Recovered, continue
#   1 - Fatal, should exit

handle_error() {
    local error_code="$1"
    local context="$2"

    case "$error_code" in
        E_NOT_FOUND)
            log_info "File already deleted: $context"
            return 0  # Recoverable
            ;;
        E_APP_RUNNING)
            log_warn "Application running, skipping: $context"
            add_to_skipped "$context" "Application running"
            return 0  # Recoverable
            ;;
        E_IO_ERROR)
            log_error "I/O error on: $context"
            add_to_failed "$context" "I/O error"
            return 0  # Recoverable
            ;;
        E_PERMISSION_DENIED)
            log_error "Permission denied: $context"
            if prompt_privilege_escalation; then
                return 0  # Retry with privilege
            fi
            return 1  # Fatal
            ;;
        E_PROTECTED_PATH)
            log_error "SECURITY: Protected path access: $context"
            return 1  # Fatal - security violation
            ;;
        E_DISK_FULL)
            log_error "Disk full - cannot continue"
            save_session_state
            return 1  # Fatal
            ;;
        *)
            log_error "Unknown error ($error_code): $context"
            return 1  # Treat unknown as fatal
            ;;
    esac
}
```

---

## 8. Traceability Matrix

### 8.1 SRS → SDS Mapping

| SRS Requirement | SDS Design Element | Status |
|-----------------|-------------------|--------|
| **Functional Requirements** | | |
| SRS-FR-F01-001 (Safety Classification) | SDS-MOD-SAFETY-001 | Designed |
| SRS-FR-F01-002 (Protected Paths) | SDS-MOD-SAFETY-001 | Designed |
| SRS-FR-F01-003 (Running App Detection) | SDS-MOD-SAFETY-002 | Designed |
| SRS-FR-F01-004 (Cleanup Levels) | SDS-MOD-SAFETY-003 | Designed |
| SRS-FR-F01-005 (Pre-Cleanup Confirmation) | SDS-IF-CLI-002 | Designed |
| SRS-FR-F02-001 (Xcode DerivedData) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-002 (iOS Simulator) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-003 (Device Support) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-004 (Package Managers) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-005 (Docker) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-006 (node_modules) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F02-007 (IDE Cache) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F03-001 (Browser Cache) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F03-002 (App Cache) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F03-003 (Cloud Cache) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F04-001 (User Logs) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F04-002 (Crash Reports) | SDS-MOD-CLEANER-002 | Designed |
| SRS-FR-F05-001 (Snapshot Listing) | SDS-MOD-TARGET-TM | Planned |
| SRS-FR-F05-002 (Snapshot Deletion) | SDS-MOD-TARGET-TM | Planned |
| SRS-FR-F06-001 (Disk Analysis) | SDS-MOD-ANALYZER-001 | Designed |
| SRS-FR-F06-002 (Cleanup Estimation) | SDS-MOD-ANALYZER-001 | Designed |
| SRS-FR-F06-003 (Progress Visualization) | SDS-IF-CLI-004 | Designed |
| SRS-FR-F07-001 (launchd Agent) | SDS-MOD-SCHEDULER-001 | Designed |
| SRS-FR-F07-002 (Schedule Options) | SDS-MOD-SCHEDULER-001 | Designed |
| SRS-FR-F07-003 (Disk Alert) | SDS-MOD-SCHEDULER-002 | Designed |
| SRS-FR-F08-001 (Non-Interactive) | SDS-IF-CLI-002 | Designed |
| SRS-FR-F08-002 (JSON Output) | SDS-IF-CLI-005 | Designed |
| SRS-FR-F08-003 (Disk Check Mode) | SDS-IF-CLI-002 | Designed |
| SRS-FR-F09-001 (Multi-User) | - | Phase 3 |
| SRS-FR-F10-001 (Version Detection) | SDS-MOD-UTIL-VERSION | Planned |
| SRS-FR-F10-002 (Sequoia Fixes) | SDS-MOD-UTIL-VERSION | Planned |
| SRS-FR-F10-003 (Architecture) | SDS-MOD-UTIL-VERSION | Planned |
| **Non-Functional Requirements** | | |
| SRS-NFR-PERF-001 (Execution Time) | Performance consideration | - |
| SRS-NFR-PERF-002 (Memory Usage) | Implementation consideration | - |
| SRS-NFR-PERF-003 (Disk I/O) | SDS-MOD-CLEANER-001 | Designed |
| SRS-NFR-SEC-001 (Privilege) | SDS-SEC-002 | Designed |
| SRS-NFR-SEC-002 (Audit Logging) | SDS-MOD-UTIL-LOG-001, SDS-SEC-003 | Designed |
| SRS-NFR-SEC-003 (Input Validation) | SDS-SEC-001 | Designed |
| SRS-NFR-REL-001 (Error Recovery) | SDS-ERR-003 | Designed |
| SRS-NFR-REL-002 (False Positive) | SDS-MOD-SAFETY-001 | Designed |
| SRS-NFR-USE-001 (CLI Usability) | SDS-IF-CLI-001 ~ SDS-IF-CLI-004 | Designed |
| SRS-NFR-USE-002 (Error Messages) | SDS-ERR-001, SDS-ERR-002 | Designed |
| SRS-NFR-COMP-001 (macOS Versions) | SDS-MOD-UTIL-VERSION | Planned |
| SRS-NFR-COMP-002 (Shell Compat) | Implementation consideration | - |
| SRS-NFR-MAINT-001 (Modularity) | SDS-ARCH-001, SDS-ARCH-002 | Designed |
| SRS-NFR-MAINT-002 (Configuration) | SDS-MOD-UTIL-CONFIG-001 | Designed |
| **Interface Requirements** | | |
| SRS-IR-CLI-001 (Main Command) | SDS-IF-CLI-001 | Designed |
| SRS-IR-CLI-002 (Clean Options) | SDS-IF-CLI-002 | Designed |
| SRS-IR-CLI-003 (Analyze Command) | SDS-IF-CLI-002 | Designed |
| SRS-IR-CLI-004 (Schedule Command) | SDS-IF-CLI-002 | Designed |
| SRS-IR-GUI-001 (Main Window) | - | Phase 3 |
| SRS-IR-SYS-001 (File System) | SDS-MOD-CLEANER-001 | Designed |
| SRS-IR-SYS-002 (Process) | SDS-MOD-SAFETY-002 | Designed |
| SRS-IR-SYS-003 (Notification) | SDS-IF-NOTIFY-001 | Designed |
| **Data Requirements** | | |
| SRS-DR-001 (CleanupTarget) | SDS-DATA-001 | Designed |
| SRS-DR-002 (CleanupSession) | SDS-DATA-002 | Designed |
| SRS-DR-003 (Configuration) | SDS-DATA-003 | Designed |
| SRS-DR-004 (Local Storage) | SDS-DATA-004 | Designed |

---

### 8.2 Design Coverage Summary

| Category | Total Requirements | Designed | Planned | Phase 3+ |
|----------|-------------------|----------|---------|----------|
| Functional (FR) | 28 | 24 | 3 | 1 |
| Non-Functional (NFR) | 14 | 10 | 2 | 2 |
| Interface (IR) | 10 | 8 | 0 | 2 |
| Data (DR) | 4 | 4 | 0 | 0 |
| **Total** | **56** | **46** | **5** | **5** |

**Coverage Rate**: 82% (Designed), 91% (Designed + Planned)

---

## 9. Implementation Notes

### 9.1 Phase 1 Implementation Priority

| Priority | Module | SDS Reference | Effort |
|----------|--------|---------------|--------|
| 1 | Safety Module | SDS-MOD-SAFETY-* | High |
| 2 | Core Cleaner | SDS-MOD-CLEANER-001 | High |
| 3 | CLI Interface | SDS-IF-CLI-* | Medium |
| 4 | Analyzer Module | SDS-MOD-ANALYZER-* | Medium |
| 5 | Logger Module | SDS-MOD-UTIL-LOG-* | Low |
| 6 | Config Module | SDS-MOD-UTIL-CONFIG-* | Low |

### 9.2 Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                     Module Dependencies                          │
└─────────────────────────────────────────────────────────────────┘

bin/osxcleaner
    ├── lib/utils/common.sh    (Required)
    ├── lib/utils/logger.sh    (Required)
    ├── lib/utils/config.sh    (Required)
    ├── lib/core/safety.sh     (Required)
    ├── lib/core/analyzer.sh   (Required)
    └── lib/core/cleaner.sh    (Required)
        └── lib/targets/*.sh   (Lazy loaded)

lib/core/cleaner.sh
    ├── lib/core/safety.sh     (Required)
    └── lib/utils/logger.sh    (Required)

lib/core/analyzer.sh
    └── lib/utils/common.sh    (Required)

lib/core/scheduler.sh
    ├── lib/utils/config.sh    (Required)
    └── lib/utils/notification.sh (Required)
```

### 9.3 Testing Strategy

| Test Level | Scope | Tools |
|------------|-------|-------|
| Unit | Individual functions | bats-core |
| Integration | Module interactions | bats-core + mock |
| System | End-to-end cleanup | Manual + VM |
| Security | Path validation, privileges | Custom scripts |

---

## Document Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Tech Lead | | | |
| Architect | | | |
| QA Lead | | | |

---

*This document is based on SRS v0.1.0.0 and must be updated when SRS changes.*

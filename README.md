# OSX Cleaner

> **macOS System Cleaning Tool** - Safely clean unnecessary files to free up disk space.

[![macOS](https://img.shields.io/badge/macOS-10.15--15.x-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Development-orange.svg)]()

---

## Overview

**OSX Cleaner** is a tool that **safely** cleans unnecessary files (temporary files, caches, logs, etc.) on macOS systems to free up disk space and optimize system performance.

### Key Value Propositions

| Value | Description |
|-------|-------------|
| **Safety First** | 4-level safety classification system prevents system damage |
| **Developer-Focused** | Specialized management of development tool caches including Xcode, Docker, npm, Homebrew (can save 50-150GB) |
| **Version Compatibility** | Full support from macOS Catalina (10.15) to Sequoia (15.x) |
| **Automation Support** | launchd-based scheduling and CI/CD pipeline integration |

---

## Potential Space Savings

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Mac (512GB SSD)                     │
├─────────────────────────────────────────────────────────────────┤
│ Xcode + Simulators          ██████████████░░░░░░  80GB (16%)     │
│ Docker                      ██████░░░░░░░░░░░░░░  30GB (6%)      │
│ Various Caches              ████████░░░░░░░░░░░░  50GB (10%)     │
│ node_modules (scattered)    ████░░░░░░░░░░░░░░░░  20GB (4%)      │
│ System Data (opaque)        ██████░░░░░░░░░░░░░░  35GB (7%)      │
└─────────────────────────────────────────────────────────────────┘
  → Cache/temporary data alone occupies 200GB+ (40%)
```

---

## Safety Classification System

OSX Cleaner uses a 4-level safety classification system:

| Level | Indicator | Description | Examples |
|-------|-----------|-------------|----------|
| **Safe** | ✅ | Can delete immediately, auto-regenerates | Browser cache, Trash |
| **Caution** | ⚠️ | Can delete but requires rebuild time | User caches, old logs |
| **Warning** | ⚠️⚠️ | Can delete but requires data re-download | iOS Device Support, Docker images |
| **Danger** | ❌ | Do not delete, can damage system | `/System/*`, Keychains |

---

## Cleanup Levels

### Level 1: Light (✅ Safe)
- Empty Trash
- Browser caches (Safari, Chrome, Firefox, Edge)
- Old downloads (90+ days)
- Old screenshots (30+ days)

### Level 2: Normal (⚠️ Caution)
- Level 1 included
- All user caches (`~/Library/Caches/*`)
- Old logs (30+ days)
- Crash reports (30+ days)

### Level 3: Deep (⚠️⚠️ Warning)
- Level 2 included
- Xcode DerivedData
- iOS Simulator (unavailable versions)
- CocoaPods/SPM cache
- npm/yarn/pnpm cache
- Docker (unused images, build cache)
- Homebrew old versions

### Level 4: System (❌ Not Recommended)
- `/Library/Caches` (requires root privileges)
- Safe Mode boot or periodic scripts recommended instead

---

## Target Users

### iOS/macOS Developer
- **Environment**: Xcode, multiple Simulators, CocoaPods/SPM
- **Cleanup Potential**: 50-150GB

### Full-Stack Developer
- **Environment**: Node.js, Docker, Python, multiple IDEs
- **Cleanup Potential**: 30-80GB

### DevOps Engineer
- **Environment**: CI/CD build machines, multi-user setups
- **Cleanup Potential**: Real-time monitoring and automated cleanup needed

### General Power User
- **Environment**: Browsers, office apps, cloud sync
- **Cleanup Potential**: 5-30GB

---

## Key Features

| Feature ID | Feature Name | Priority | Target Users |
|------------|--------------|:--------:|--------------|
| F01 | Safety-Based Cleanup System | P0 | All |
| F02 | Developer Tool Cache Management | P0 | Developer |
| F03 | Browser/App Cache Cleanup | P0 | All |
| F04 | Log and Crash Report Management | P1 | All |
| F05 | Time Machine Snapshot Management | P1 | All |
| F06 | Disk Usage Analysis/Visualization | P1 | All |
| F07 | Automation Scheduling | P1 | Developer/DevOps |
| F08 | CI/CD Pipeline Integration | P2 | DevOps |
| F09 | Team Environment Management | P2 | DevOps |
| F10 | macOS Version Optimization | P1 | All |

---

## Technology Stack

OSX Cleaner adopts a **Swift + Rust hybrid** architecture.

```
┌─────────────────────────────────────────────────────────────────┐
│                   Swift + Rust Hybrid                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   Swift Layer                                                     │
│   ├── Presentation: CLI (ArgumentParser), GUI (SwiftUI)          │
│   ├── Service: Business logic orchestration                      │
│   └── Core: Configuration management, logging                    │
│                         │ FFI (C-ABI)                             │
│   Rust Layer            ▼                                         │
│   ├── Core Engine: File scanning, cleanup execution, safety      │
│   └── Infrastructure: Filesystem abstraction, parallel processing│
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

| Layer | Language | Primary Role |
|-------|----------|--------------|
| **Presentation** | Swift | CLI, GUI (SwiftUI) |
| **Service** | Swift | Business logic |
| **Core** | Swift + Rust | Config/Logger (Swift), Engine/Safety (Rust) |
| **Infrastructure** | Rust | Filesystem, parallel processing |
| **Scripts** | Shell | launchd, install scripts |

> See [SDS.md](docs/SDS.md) Section 1.5 for details

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/kcenon/osx_cleaner.git
cd osx_cleaner

# Build and install
./scripts/install.sh
```

### Basic Usage

```bash
# Analyze disk usage
osxcleaner analyze

# Analyze with details
osxcleaner analyze --verbose

# Analyze specific category with top items
osxcleaner analyze --category xcode --top 10

# Analyze with JSON output (for CI/CD)
osxcleaner analyze --format json

# Clean with default cleanup level (normal)
osxcleaner clean --dry-run

# Clean with light level (safe items only)
osxcleaner clean --level light --dry-run

# Clean developer caches with deep level
osxcleaner clean --level deep --target developer

# Clean for CI/CD (non-interactive with JSON output)
osxcleaner clean --level normal --non-interactive --format json

# Show configuration
osxcleaner config show

# Schedule automated daily cleanup
osxcleaner schedule add --frequency daily --level light --hour 3

# List configured schedules
osxcleaner schedule list

# Enable a schedule
osxcleaner schedule enable daily
```

### CLI Commands Reference

| Command | Description |
|---------|-------------|
| `analyze` | Analyze disk usage and find cleanup opportunities |
| `clean` | Clean specified targets with safety checks |
| `config` | Manage osxcleaner configuration |
| `schedule` | Manage automated cleanup schedules |

### Common Options

| Option | Commands | Description |
|--------|----------|-------------|
| `--level` | clean | Cleanup level (light, normal, deep, system) |
| `--target` | clean | Cleanup target (browser, developer, logs, all) |
| `--category` | analyze | Filter by category (all, xcode, docker, browser, caches, logs) |
| `--format` | clean, analyze, schedule | Output format (text, json) |
| `--dry-run` | clean | Preview without actual deletion |
| `--non-interactive` | clean | Skip confirmation prompts (for CI/CD) |
| `--verbose` | clean, analyze | Show detailed output |
| `--quiet` | clean, analyze | Minimal output |

### Manual Build

```bash
# Build everything
make all

# Run tests
make test

# Build for development
make debug
```

---

## CI/CD Integration

OSX Cleaner can be integrated into CI/CD pipelines to prevent disk space issues during builds.

### GitHub Actions

```yaml
- name: Pre-build cleanup
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
  with:
    level: 'normal'
    min-space: '20'  # Only cleanup if less than 20GB available

- name: Build
  run: xcodebuild -scheme MyApp

- name: Post-build cleanup
  uses: kcenon/osx_cleaner/.github/actions/osxcleaner@v1
  with:
    level: 'deep'
    target: 'developer'
```

### CLI Usage for CI/CD

```bash
# Non-interactive cleanup with JSON output
osxcleaner clean --level normal --non-interactive --format json

# Cleanup only if available space is below 20GB
osxcleaner clean --level deep --non-interactive --min-space 20 --format json

# Preview cleanup in CI logs
osxcleaner clean --level deep --dry-run --format json
```

### JSON Output

The `--format json` flag outputs machine-readable results for CI/CD integration:

```json
{
  "status": "success",
  "freed_bytes": 50000000000,
  "freed_formatted": "50 GB",
  "files_removed": 12345,
  "before": {
    "total": 512000000000,
    "used": 450000000000,
    "available": 62000000000
  },
  "after": {
    "total": 512000000000,
    "used": 400000000000,
    "available": 112000000000
  },
  "duration_ms": 45000
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (or cleanup skipped when space sufficient) |
| 1 | General error |
| 2 | Insufficient space (cleanup needed but failed) |
| 3 | Permission denied |
| 4 | Configuration error |

See [GitHub Action README](.github/actions/osxcleaner/README.md) for detailed usage.

---

## System Requirements

### Supported Platforms
- **macOS Version**: 10.15 (Catalina) ~ 15.x (Sequoia)
- **Architecture**: Intel x64, Apple Silicon (arm64)

### Recommended Specifications
- **Disk Space**: 100MB (application)
- **Memory**: 4GB RAM or more
- **Privileges**: Administrator privileges (optional, required for Level 4 cleanup)

### Build Requirements
- **Swift**: 5.9+
- **Rust**: 1.75+
- **Xcode**: 15+

---

## Project Structure

```
osxcleaner/
├── Package.swift               # Swift Package definition
├── Makefile                    # Unified build script
├── Sources/                    # Swift sources
│   ├── osxcleaner/             # CLI application
│   │   ├── OSXCleaner.swift    # Entry point
│   │   ├── Commands/           # CLI commands
│   │   └── UI/                 # Progress display
│   ├── OSXCleanerKit/          # Swift library
│   │   ├── Bridge/             # Rust FFI bridge
│   │   │   ├── RustBridge.swift   # FFI wrapper
│   │   │   └── FFITypes.swift     # FFI type definitions
│   │   ├── Services/           # Business logic
│   │   ├── Config/             # Configuration
│   │   └── Logger/             # Logging
│   └── COSXCore/               # C module for Rust FFI
│       └── module.modulemap    # Module definition
├── rust-core/                  # Rust sources
│   ├── Cargo.toml
│   ├── cbindgen.toml           # FFI header generation
│   └── src/
│       ├── lib.rs              # FFI entry point
│       ├── safety/             # Safety validation
│       ├── scanner/            # Directory scanning
│       ├── cleaner/            # Cleanup execution
│       ├── developer/          # Developer tool cleanup (F02)
│       │   ├── mod.rs          # Module entry & common types
│       │   ├── xcode.rs        # Xcode cache cleanup
│       │   ├── simulator.rs    # iOS Simulator management
│       │   ├── packages.rs     # Package manager caches
│       │   └── docker.rs       # Docker cleanup
│       ├── targets/            # User-facing app cleanup (F03)
│       │   ├── mod.rs          # Module entry & types
│       │   ├── browser.rs      # Browser cache cleanup
│       │   └── app_cache.rs    # General app cache cleanup
│       ├── system/             # macOS system detection (F10)
│       │   ├── mod.rs          # Module entry & SystemInfo
│       │   ├── version.rs      # macOS version detection
│       │   ├── architecture.rs # CPU architecture detection
│       │   └── paths.rs        # Version-specific path resolution
│       └── fs/                 # Filesystem utilities
├── include/                    # Generated C headers
├── scripts/                    # Shell scripts
│   ├── install.sh
│   ├── uninstall.sh
│   └── launchd/                # launchd agent
├── Tests/                      # Test files
└── docs/                       # Documentation
```

---

## Documentation

### User Guides

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/INSTALLATION.md) | System requirements, installation methods, troubleshooting |
| [Usage Guide](docs/USAGE.md) | CLI commands, examples, CI/CD integration |
| [Safety Guide](docs/SAFETY.md) | Safety classification, protected paths, FAQ |
| [Contributing Guide](docs/CONTRIBUTING.md) | How to contribute, coding standards |
| [Changelog](docs/CHANGELOG.md) | Version history and release notes |

### Project Documents

| Document | Description | 한글 | English |
|----------|-------------|:----:|:-------:|
| **PRD** | Product Requirements Document | [PRD.kr.md](docs/PRD.kr.md) | [PRD.md](docs/PRD.md) |
| **SRS** | Software Requirements Specification | [SRS.kr.md](docs/SRS.kr.md) | [SRS.md](docs/SRS.md) |
| **SDS** | Software Design Specification | [SDS.kr.md](docs/SDS.kr.md) | [SDS.md](docs/SDS.md) |

### Reference Documents

| Document | Description |
|----------|-------------|
| [01-temporary-files](docs/reference/01-temporary-files.md) | Temporary Files Guide |
| [02-cache-system](docs/reference/02-cache-system.md) | Cache System Analysis |
| [03-system-logs](docs/reference/03-system-logs.md) | System Log Management |
| [04-version-differences](docs/reference/04-version-differences.md) | macOS Version Differences |
| [05-developer-caches](docs/reference/05-developer-caches.md) | Developer Cache Management |
| [06-safe-cleanup-guide](docs/reference/06-safe-cleanup-guide.md) | Safe Cleanup Guide |
| [07-developer-guide](docs/reference/07-developer-guide.md) | Developer Guide |
| [08-automation-scripts](docs/reference/08-automation-scripts.md) | Automation Scripts |
| [09-ci-cd-team-guide](docs/reference/09-ci-cd-team-guide.md) | CI/CD Team Guide |

---

## Roadmap

### Phase 1: MVP (v0.1) - Core Features
- [x] CLI-based cleanup tool
- [x] Safety classification system implementation (F01)
- [x] macOS version optimization (F10)
  - Version detection (10.15 ~ 15.x)
  - Architecture detection (Intel/Apple Silicon)
  - Rosetta 2 status detection
  - Version-specific path resolution
- [ ] Basic cleanup levels (Level 1-2)

### Phase 2: Developer Features (v0.5)
- [x] Developer tool cache management (F02) ✅
  - Xcode (DerivedData, Archives, Device Support)
  - iOS Simulators (via xcrun simctl)
  - Package managers (npm, yarn, pip, brew, cargo, gradle, etc.)
  - Docker (images, containers, volumes, build cache)
- [x] Browser/App cache cleanup (F03) ✅
  - Browser caches (Safari, Chrome, Firefox, Edge, Brave, Opera, Arc)
  - Cloud service caches (iCloud, Dropbox, OneDrive, Google Drive)
  - General application cache cleanup
- [ ] Level 3 cleanup support
- [ ] Automation scheduling (F07)

### Phase 3: Complete (v1.0)
- [ ] GUI interface
- [x] CI/CD integration (F08) ✅
  - CLI non-interactive mode with JSON output
  - `--min-space` option for conditional cleanup
  - GitHub Action for automated workflows
- [ ] Team environment management (F09)

---

## Contributing

Contributions are welcome! Please see the [Contributing Guide](docs/CONTRIBUTING.md) for details on how to get started.

---

## License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Contact

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

*Last updated: 2025-12-27*

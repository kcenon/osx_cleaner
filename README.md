# OSX Cleaner

> **macOS System Cleaning Tool** - Safely clean unnecessary files to free up disk space.

[![macOS](https://img.shields.io/badge/macOS-10.15--15.x-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
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

# Clean with default cleanup level (normal)
osxcleaner clean --dry-run

# Clean with light level (safe items only)
osxcleaner clean --level 1 --dry-run

# Clean developer caches with deep level
osxcleaner clean --developer-caches --level 3

# Show configuration
osxcleaner config show
```

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
- [ ] Basic cleanup levels (Level 1-2)

### Phase 2: Developer Features (v0.5)
- [ ] Developer tool cache management (F02)
- [ ] Level 3 cleanup support
- [ ] Automation scheduling (F07)

### Phase 3: Complete (v1.0)
- [ ] GUI interface
- [ ] CI/CD integration (F08)
- [ ] Team environment management (F09)

---

## Contributing

Contributions are welcome! Please see the [Developer Guide](docs/reference/07-developer-guide.md) for details.

---

## License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Contact

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

*Last updated: 2025-12-25*

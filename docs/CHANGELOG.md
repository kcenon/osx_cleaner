# Changelog

All notable changes to OSX Cleaner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- User documentation (INSTALLATION.md, USAGE.md, SAFETY.md, CONTRIBUTING.md)
- Comprehensive user guide with CLI examples
- Safety classification documentation
- **F06: Disk Usage Analysis** (#10)
  - DiskSpace query with total/used/available information
  - Home directory analysis with Top N by size
  - Application cache analysis (~/Library/Caches)
  - Developer component analysis (~/Library/Developer)
  - Cleanable space estimation by safety level
  - FFI bindings for Swift integration

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

### v0.2.0 (Planned)
- Level 1-2 cleanup execution
- Disk usage analysis visualization (F06)
- Improved error handling

### v0.5.0 (Planned)
- Level 3 cleanup support
- Automation scheduling (F07)
- GUI interface preview

### v1.0.0 (Planned)
- Full GUI interface
- CI/CD integration (F08)
- Team environment management (F09)

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

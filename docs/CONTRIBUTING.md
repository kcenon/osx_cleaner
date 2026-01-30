# Contributing Guide

> How to contribute to OSX Cleaner development.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Issue Guidelines](#issue-guidelines)
- [Pull Request Process](#pull-request-process)

---

## Getting Started

Thank you for your interest in contributing to OSX Cleaner! This guide will help you get started.

### Prerequisites

Before contributing, make sure you have:

- macOS 11.0+ (Big Sur or later)
- Xcode 15+ with Command Line Tools
- Rust 1.75+ (install via rustup)
- Git

### Quick Start

```bash
# Fork the repository on GitHub

# Clone your fork
git clone https://github.com/YOUR_USERNAME/osx_cleaner.git
cd osx_cleaner

# Add upstream remote
git remote add upstream https://github.com/kcenon/osx_cleaner.git

# Install dependencies and build
make all

# Run tests
make test
```

---

## Development Setup

### 1. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install additional components
rustup component add clippy rustfmt
```

### 2. Install Xcode and Swift

```bash
# Install Xcode from App Store, then:
xcode-select --install
```

### 3. Clone and Build

```bash
git clone https://github.com/kcenon/osx_cleaner.git
cd osx_cleaner

# Build everything
make all

# Or build incrementally
make rust    # Build Rust core first
make swift   # Build Swift CLI
```

### 4. IDE Setup

#### VS Code (Recommended)

Install these extensions:
- rust-analyzer
- Swift (from Swift Server Work Group)
- CodeLLDB (for debugging)

#### Xcode

Open `Package.swift` directly in Xcode for Swift development.

### 5. Local Development Directories

The project root may contain local development directories that are not part of the OSX Cleaner codebase. These are excluded from version control via `.gitignore`.

#### `unified_system/`

This directory is used for **local development and experimentation** with separate projects. It contains independent Git repositories (e.g., `claude_code_agent`) that are not related to OSX Cleaner.

**Important Notes:**
- **Not part of OSX Cleaner**: This directory and its contents are completely independent projects
- **Already ignored**: Listed in `.gitignore` under "Local Development Directories"
- **Do not commit**: These directories should never be committed to the OSX Cleaner repository
- **Safe to delete**: You can safely remove this directory if not needed for your local development

**If you see this directory:**
- It's a local development artifact on someone's machine
- It's automatically excluded from git tracking
- You don't need to worry about it for OSX Cleaner development

---

## Project Structure

```
osx_cleaner/
├── rust-core/              # Rust core engine
│   ├── Cargo.toml
│   ├── cbindgen.toml       # FFI header generation
│   └── src/
│       ├── lib.rs          # FFI exports
│       ├── safety/         # Safety validation (F01)
│       ├── developer/      # Developer tools (F02)
│       ├── targets/        # Browser/App cleanup (F03)
│       ├── system/         # macOS system info (F10)
│       ├── scanner/        # File scanning
│       ├── cleaner/        # Cleanup execution
│       └── fs/             # Filesystem utilities
├── Sources/                # Swift sources
│   ├── osxcleaner/         # CLI application
│   ├── OSXCleanerKit/      # Swift library
│   └── COSXCore/           # C module for FFI
├── Tests/                  # Test files
├── docs/                   # Documentation
├── scripts/                # Shell scripts
└── Makefile                # Build automation
```

### Module Responsibilities

| Module | Language | Purpose |
|--------|----------|---------|
| `safety` | Rust | Path classification, validation |
| `developer` | Rust | Xcode, Docker, npm cleanup |
| `targets` | Rust | Browser, app cache cleanup |
| `system` | Rust | macOS version/arch detection |
| `OSXCleanerKit` | Swift | Business logic, FFI bridge |
| `osxcleaner` | Swift | CLI interface |

---

## Coding Standards

### Rust Code

Follow the [Rust Style Guide](https://doc.rust-lang.org/style-guide/):

```rust
// Use rustfmt for formatting
cargo fmt

// Use clippy for linting
cargo clippy -- -D warnings

// Documentation comments for public items
/// Validates a path for safe deletion.
///
/// # Arguments
/// * `path` - The path to validate
///
/// # Returns
/// * `SafetyLevel` - The classified safety level
pub fn validate_path(path: &Path) -> SafetyLevel {
    // Implementation
}
```

### Swift Code

Follow Apple's [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/):

```swift
// Use SwiftFormat for formatting
swiftformat .

// Clear function names
func cleanupTargets(at level: CleanupLevel) -> CleanupResult {
    // Implementation
}

// Documentation
/// Performs cleanup at the specified level.
/// - Parameter level: The cleanup level to use
/// - Returns: A result containing cleanup statistics
```

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(safety): add cloud sync detection

- Implement iCloud Drive sync status check
- Add Dropbox and OneDrive detection
- Include tests for all cloud services

Fixes #26
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build, CI, maintenance

---

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run Rust tests only
cd rust-core && cargo test

# Run Swift tests only
swift test

# Run specific test
cargo test test_safety_level

# Run with verbose output
cargo test -- --nocapture
```

### Writing Tests

#### Rust Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_protected_path_detection() {
        let validator = SafetyValidator::new();
        let level = validator.classify(Path::new("/System/Library"));
        assert_eq!(level, SafetyLevel::Danger);
    }

    #[test]
    fn test_browser_cache_is_safe() {
        let path = Path::new("/Users/test/Library/Caches/Google/Chrome");
        assert_eq!(classify_path(path), SafetyLevel::Safe);
    }
}
```

#### Swift Tests

```swift
import XCTest
@testable import OSXCleanerKit

final class SafetyTests: XCTestCase {
    func testProtectedPathDetection() {
        let bridge = RustBridge()
        let level = bridge.classifyPath("/System/Library")
        XCTAssertEqual(level, .danger)
    }
}
```

### Test Coverage Requirements

All code changes must maintain or improve test coverage. Coverage is automatically measured and enforced in CI/CD.

#### Overall Coverage Thresholds

| Scope | Minimum Coverage | Enforcement |
|-------|------------------|-------------|
| **Project (Overall)** | 80% | CI fails if below target |
| **PR Patch (New Code)** | 85% | CI fails if new code not tested |

#### Module-Specific Coverage

| Module | Minimum Coverage | Rationale |
|--------|------------------|-----------|
| safety | 90% | Critical for system protection |
| developer | 80% | Core feature |
| targets | 80% | Core feature |
| system | 85% | System-level operations |
| CleanerService | 80% | Critical service |
| AnalyzerService | 80% | Critical service |
| RustBridge (FFI) | 80% | Interface layer |
| MDMService | 80% | Enterprise feature |

#### Measuring Coverage Locally

**Swift Coverage:**
```bash
# Run tests with coverage
swift test --enable-code-coverage

# Generate coverage report (lcov format)
xcrun llvm-cov export --format=lcov \
  --instr-profile=.build/debug/codecov/default.profdata \
  .build/debug/osxcleanerPackageTests.xctest/Contents/MacOS/osxcleanerPackageTests \
  > coverage-swift.lcov

# View coverage summary
xcrun llvm-cov report \
  --instr-profile=.build/debug/codecov/default.profdata \
  .build/debug/osxcleanerPackageTests.xctest/Contents/MacOS/osxcleanerPackageTests
```

**Rust Coverage:**
```bash
# Install cargo-llvm-cov (first time only)
cargo install cargo-llvm-cov

# Generate coverage report
cd rust-core
cargo llvm-cov --all-features --lcov --output-path ../coverage-rust.lcov

# View HTML coverage report
cargo llvm-cov --all-features --html
open target/llvm-cov/html/index.html
```

#### CI Coverage Workflow

Coverage is automatically measured and reported:
- **Codecov Integration**: Coverage reports uploaded to [Codecov](https://codecov.io/gh/kcenon/osx_cleaner)
- **PR Comments**: Coverage changes displayed in PR comments
- **Status Checks**: CI fails if coverage drops below threshold
- **Badge**: ![codecov](https://codecov.io/gh/kcenon/osx_cleaner/branch/main/graph/badge.svg)

#### Coverage Enforcement

The `codecov.yml` configuration enforces:
- **80% minimum** for overall project coverage
- **85% minimum** for new code (PR patches)
- **2% threshold** for project-level changes
- **5% threshold** for patch-level changes

**When CI Fails Due to Coverage:**

1. Review Codecov report in PR comment
2. Identify untested code paths
3. Add tests for uncovered lines
4. Focus on critical paths first (error handling, edge cases)
5. Push updated tests

---

## Submitting Changes

### Before Submitting

1. **Sync with upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**
   ```bash
   make test
   cargo clippy -- -D warnings
   cargo fmt --check
   ```

3. **Update documentation** if needed

4. **Add tests** for new functionality

### Creating a Pull Request

1. Push to your fork
   ```bash
   git push origin feature/my-feature
   ```

2. Open a PR on GitHub

3. Fill out the PR template

4. Wait for review

---

## Issue Guidelines

### Reporting Bugs

Use the bug report template:

```markdown
**Describe the bug**
A clear description of the bug.

**To Reproduce**
1. Run `osxcleaner ...`
2. See error

**Expected behavior**
What you expected to happen.

**Environment**
- macOS version:
- Architecture (Intel/Apple Silicon):
- OSX Cleaner version:

**Additional context**
Any other information.
```

### Requesting Features

Use the feature request template:

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Other solutions you've thought about.

**Additional context**
Any other information.
```

### Good First Issues

Look for issues labeled `good first issue` for beginner-friendly tasks.

---

## Pull Request Process

### 1. Create Branch

```bash
git checkout -b feature/issue-number-description
# Example: feature/42-add-docker-cleanup
```

### 2. Make Changes

- Keep commits focused and atomic
- Write meaningful commit messages
- Add tests for new code

### 3. Submit PR

PR title format:
```
feat(module): Brief description (#issue)
```

### 4. Code Review

- Respond to feedback promptly
- Make requested changes
- Keep the conversation constructive

### 5. Merge

After approval:
- Squash and merge for features
- Rebase and merge for fixes

---

## Getting Help

- **GitHub Discussions**: For questions and ideas
- **GitHub Issues**: For bugs and feature requests
- **Code Review**: Ask in PR comments

---

## Recognition

Contributors are recognized in:
- CHANGELOG.md (for each release)
- GitHub Contributors page
- Release notes

Thank you for contributing to OSX Cleaner!

---

*Last updated: 2025-12-26*

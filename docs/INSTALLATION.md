# Installation Guide

> Complete guide for installing OSX Cleaner on your macOS system.

---

## Table of Contents

- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
  - [Quick Install (Recommended)](#quick-install-recommended)
  - [Homebrew](#homebrew)
  - [Build from Source](#build-from-source)
- [Permission Setup](#permission-setup)
- [Verification](#verification)
- [Updating](#updating)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)

---

## System Requirements

### Supported Platforms

| macOS Version | Code Name | Architecture | Support Status |
|--------------|-----------|--------------|----------------|
| 15.x | Sequoia | Apple Silicon, Intel | Full Support |
| 14.x | Sonoma | Apple Silicon, Intel | Full Support |
| 13.x | Ventura | Apple Silicon, Intel | Full Support |
| 12.x | Monterey | Apple Silicon, Intel | Full Support |
| 11.x | Big Sur | Apple Silicon, Intel | Full Support |
| 10.15 | Catalina | Intel | Full Support |

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **Disk Space** | 100 MB | 500 MB |
| **RAM** | 2 GB | 4 GB or more |
| **CPU** | Intel x64 or Apple Silicon | Apple Silicon (M1/M2/M3/M4) |

### Build Requirements (for source builds)

| Tool | Minimum Version | Check Command |
|------|-----------------|---------------|
| **Xcode** | 15.0 | `xcode-select --version` |
| **Swift** | 5.9 | `swift --version` |
| **Rust** | 1.75 | `rustc --version` |
| **Cargo** | 1.75 | `cargo --version` |

---

## Installation Methods

### Quick Install (Recommended)

The fastest way to install OSX Cleaner:

```bash
# Clone the repository
git clone https://github.com/kcenon/osx_cleaner.git
cd osx_cleaner

# Run the installer
./scripts/install.sh
```

The install script will:
1. Check system requirements
2. Install Rust toolchain if needed
3. Build the Rust core library
4. Build the Swift CLI application
5. Install the binary to `/usr/local/bin`
6. Set up shell completions (optional)

### Homebrew

> **Note**: Homebrew installation will be available in a future release.

```bash
# Coming soon
brew tap kcenon/tap
brew install osxcleaner
```

### Build from Source

For developers or those who want to customize the build:

#### Step 1: Install Prerequisites

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

#### Step 2: Clone and Build

```bash
# Clone the repository
git clone https://github.com/kcenon/osx_cleaner.git
cd osx_cleaner

# Build everything (Rust + Swift)
make all

# Or build step by step
make rust      # Build Rust core library
make swift     # Build Swift CLI
```

#### Step 3: Install

```bash
# Install to /usr/local/bin (requires sudo)
make install

# Or install to a custom location
make install PREFIX=~/.local
```

#### Build Options

| Command | Description |
|---------|-------------|
| `make all` | Build everything (release mode) |
| `make debug` | Build in debug mode |
| `make test` | Run all tests |
| `make clean` | Clean build artifacts |
| `make rust` | Build Rust core only |
| `make swift` | Build Swift CLI only |

---

## Permission Setup

OSX Cleaner requires certain permissions to function properly.

### Full Disk Access (Required for Deep Cleanup)

To clean system caches and protected directories, grant Full Disk Access:

1. Open **System Settings** (or System Preferences on older macOS)
2. Navigate to **Privacy & Security** > **Full Disk Access**
3. Click the **+** button
4. Add `/usr/local/bin/osxcleaner` (or your install location)
5. Enable the toggle for osxcleaner

```bash
# Verify Full Disk Access
osxcleaner analyze --verbose
```

### Administrator Privileges (Optional)

Level 4 (System) cleanup requires administrator privileges:

```bash
# Run with sudo for system-level cleanup
sudo osxcleaner clean --level system
```

---

## Verification

After installation, verify everything works correctly:

```bash
# Check version
osxcleaner --version

# Check help
osxcleaner --help

# Run a quick analysis
osxcleaner analyze

# Test with dry-run
osxcleaner clean --level light --dry-run
```

Expected output:

```
OSX Cleaner v0.1.0
macOS 14.2 (Sonoma) on Apple Silicon

Analyzing disk usage...
----------------------------------------
Category         Size      Items  Safety
----------------------------------------
Browser Cache    2.5 GB    1,234  Safe
User Caches      5.2 GB    3,456  Caution
Developer        25.0 GB   789    Warning
----------------------------------------
Total Cleanable: 32.7 GB
```

---

## Updating

### Update from Source

```bash
cd osx_cleaner
git pull origin main
make clean
make all
make install
```

### Check for Updates

```bash
# Compare versions
osxcleaner --version
git fetch --tags
git describe --tags --abbrev=0
```

---

## Uninstallation

### Quick Uninstall

```bash
# Run the uninstaller
./scripts/uninstall.sh
```

### Manual Uninstall

```bash
# Remove the binary
sudo rm /usr/local/bin/osxcleaner

# Remove configuration (optional)
rm -rf ~/.config/osxcleaner

# Remove launchd agents (if scheduled)
launchctl unload ~/Library/LaunchAgents/com.osxcleaner.*.plist
rm ~/Library/LaunchAgents/com.osxcleaner.*.plist

# Remove shell completions (if installed)
rm /usr/local/share/zsh/site-functions/_osxcleaner
rm /usr/local/etc/bash_completion.d/osxcleaner
```

---

## Troubleshooting

### Common Issues

#### "Command not found: osxcleaner"

The binary is not in your PATH.

```bash
# Check installation location
which osxcleaner

# Add to PATH (if using custom location)
export PATH="$PATH:/path/to/osxcleaner"
```

#### "Permission denied" during installation

```bash
# Use sudo for system-wide installation
sudo make install

# Or install to user directory
make install PREFIX=~/.local
export PATH="$PATH:~/.local/bin"
```

#### Rust build fails

```bash
# Update Rust
rustup update stable

# Clean and rebuild
cd rust-core
cargo clean
cargo build --release
```

#### Swift build fails

```bash
# Clean Swift build
swift package clean

# Resolve dependencies
swift package resolve

# Rebuild
swift build -c release
```

#### "Library not loaded" error

The Rust dynamic library is not found.

```bash
# Check library location
ls -la .build/release/libosxcore.dylib

# Set library path
export DYLD_LIBRARY_PATH="$(pwd)/.build/release:$DYLD_LIBRARY_PATH"
```

#### Full Disk Access issues

```bash
# Check if TCC database needs reset
tccutil reset SystemPolicyAllFiles

# Then re-add Full Disk Access permission
```

### Getting Help

If you encounter issues not covered here:

1. Check [GitHub Issues](https://github.com/kcenon/osx_cleaner/issues)
2. Search existing issues for your problem
3. Create a new issue with:
   - macOS version (`sw_vers`)
   - Architecture (`uname -m`)
   - Error message
   - Steps to reproduce

---

*Last updated: 2025-12-26*
